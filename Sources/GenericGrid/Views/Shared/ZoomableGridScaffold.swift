//
//  ZoomableGridScaffold.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Shared layout + zoom container reused by both the main grid
//  (`GenericGridView`) and the config preview (`ConfigGridPreviewView`).
//  The grid is laid out ONCE at a base cell size; zoom is a GPU
//  `scaleEffect` (no re-layout, so compartment borders stay crisp and
//  stable while zooming) and pan is a manual offset. Pinch zooms around
//  the focal point. The caller's grid gestures (tap / long-press move)
//  live on the inner content and keep priority — pan/pinch only handle
//  touches the content doesn't consume.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ZoomableGridScaffold<Content: View>: View {

    let config: GridCanvasConfig
    @Binding var zoom: CGFloat
    /// Kept for source compatibility; with content-priority gestures the pan
    /// no longer fights item manipulation, but callers may still suppress it.
    var scrollDisabled: Bool = false
    @ViewBuilder let content: (_ cellSize: CGFloat) -> Content

    /// Current pan offset (screen points).
    @State private var pan: CGSize = .zero
    /// Pan snapshot captured at the start of a drag.
    @State private var panStart: CGSize?
    /// Zoom/pan/focal snapshot captured at the start of a pinch.
    @State private var pinchStart: PinchSnapshot?
    /// Live (transient) pinch scale applied on top of the laid-out zoom while a
    /// pinch is in progress; committed into `zoom` on release so text/shapes
    /// re-render crisp instead of staying a stretched bitmap.
    @State private var liveScale: CGFloat = 1

    private struct PinchSnapshot { let zoom: CGFloat; let pan: CGSize; let focal: CGPoint }

    private var hasLabels: Bool {
        config.rowLabels != nil || config.colLabels != nil || config.columnBands != nil
    }

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = hasLabels ? GridLayout.labelMargin : 0
            // Lay out at the *actual* zoomed cell size so text/shapes stay
            // crisp; an in-progress pinch adds a transient scaleEffect on top.
            let cs = config.baseCellSize(in: geo.size, margin: margin) * zoom
            let W  = CGFloat(config.cols) * cs
            let H  = config.totalContentHeight(cellSize: cs)
            let bands = config.effectiveBands
            let strips = config.rowStrips

            gridBody(cellSize: cs, margin: margin, width: W, height: H, bands: bands, strips: strips)
                .frame(width: W + margin, height: H + margin, alignment: .topLeading)
                .scaleEffect(liveScale, anchor: .topLeading)
                .offset(pan)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(panGesture)
                .simultaneousGesture(magnifyGesture)
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    ZoomControls(zoom: $zoom, onReset: { pan = .zero; liveScale = 1 })
                        .padding(GridLayout.zoomControlsPadding)
                }
        }
        .background(.background.secondary)
    }

    /// The grid + labels, laid out at the base cell size (pre-zoom).
    @ViewBuilder
    private func gridBody(cellSize cs: CGFloat, margin: CGFloat,
                          width W: CGFloat, height H: CGFloat,
                          bands: [ColumnBand],
                          strips: [(rowStart: Int, rowEnd: Int)]) -> some View {
        ZStack(alignment: .topLeading) {
            if hasLabels, let topStrip = strips.first {
                topStripLabels(bands: bands.filter { $0.rowStart == topStrip.rowStart },
                               cellSize: cs, margin: margin)
                    .offset(x: margin, y: 0)
                rowLabels(cellSize: cs, margin: margin)
                    .offset(x: 0, y: margin)
            }
            content(cs)
                .frame(width: W, height: H)
                .offset(x: margin, y: margin)
            if hasLabels, strips.count > 1 {
                intermediateStripHeaders(bands: bands, strips: strips,
                                         cellSize: cs, width: W)
                    .offset(x: margin, y: margin)
            }
        }
    }

    // MARK: - Pan / zoom gestures

    /// One-finger pan. Attached on the container, so the inner grid gestures
    /// (tap to place, long-press to move) take priority on touches that hit a
    /// cell; only the leftover drags pan the canvas.
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: GridLayout.panMinDistance)
            .onChanged { value in
                guard !scrollDisabled else { return }
                let start = panStart ?? pan
                if panStart == nil { panStart = pan }
                pan = CGSize(width: start.width + value.translation.width,
                             height: start.height + value.translation.height)
            }
            .onEnded { _ in panStart = nil }
    }

    /// Pinch zoom anchored on the focal point: the content point under the
    /// fingers stays fixed while the scale changes.
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let snap = pinchStart ?? PinchSnapshot(zoom: zoom, pan: pan, focal: value.startLocation)
                if pinchStart == nil { pinchStart = snap }
                // Clamp the effective zoom, then express it as a live scale on
                // top of the (fixed) laid-out zoom for the duration of the pinch.
                let target = min(max(snap.zoom * value.magnification, GridZoom.min), GridZoom.max)
                let scale = target / snap.zoom
                liveScale = scale
                // Keep the focal point fixed (scale from top-left, then pan):
                //   screen = content * scale + pan
                let cx = snap.focal.x - snap.pan.width
                let cy = snap.focal.y - snap.pan.height
                pan = CGSize(width: snap.focal.x - cx * scale,
                             height: snap.focal.y - cy * scale)
            }
            .onEnded { _ in
                // Commit the live scale into the layout zoom → crisp re-render.
                // Top-left anchor keeps the origin fixed, so pan is unchanged.
                if let snap = pinchStart {
                    zoom = min(max(snap.zoom * liveScale, GridZoom.min), GridZoom.max)
                }
                liveScale = 1
                pinchStart = nil
            }
    }

    // MARK: - Labels

    /// Column labels for every band that starts in the top row strip.
    /// Each band is positioned at its own X offset and divided into its
    /// effective subdivision count.
    private func topStripLabels(bands: [ColumnBand], cellSize cs: CGFloat,
                                margin: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(bands, id: \.id) { band in
                bandColumnLabels(band: band, cellSize: cs, height: margin)
                    .offset(x: config.xForBand(band, baseCellSize: cs), y: 0)
            }
        }
    }

    /// Strip header rows inserted between consecutive row strips. Each
    /// header strip sits above the strip's first data row and is filled
    /// per-band so vertical splits remain visually distinct.
    @ViewBuilder
    private func intermediateStripHeaders(bands: [ColumnBand],
                                          strips: [(rowStart: Int, rowEnd: Int)],
                                          cellSize cs: CGFloat,
                                          width W: CGFloat) -> some View {
        ForEach(Array(strips.enumerated()), id: \.element.rowStart) { idx, strip in
            if idx > 0 {
                let y = (CGFloat(strip.rowStart) + CGFloat(idx) - 1) * cs
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(GridOpacity.bandHeaderFill))
                        .frame(width: W, height: cs)
                    ForEach(bands.filter { $0.rowStart == strip.rowStart }, id: \.id) { band in
                        bandColumnLabels(band: band, cellSize: cs, height: cs)
                            .offset(x: config.xForBand(band, baseCellSize: cs), y: 0)
                    }
                }
                .frame(width: W, height: cs)
                .overlay(alignment: .top) { Divider() }
                .overlay(alignment: .bottom) { Divider() }
                .offset(x: 0, y: y)
            }
        }
    }

    /// One row of labels for a band, sized to its column extent and
    /// divided into its effective subdivision count.
    private func bandColumnLabels(band: ColumnBand, cellSize cs: CGFloat,
                                  height: CGFloat) -> some View {
        let bandSubdivisions = config.cols(for: band)
        let bandCellW = config.bandCellWidth(band, baseCellSize: cs)
        return HStack(spacing: 0) {
            ForEach(0..<bandSubdivisions, id: \.self) { c in
                Text(band.colLabel(at: c))
                    .font(.system(size: min(cs * GridFont.colLabelScale, GridFont.colLabelMax),
                                  weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: bandCellW, height: height)
            }
        }
    }

    private func rowLabels(cellSize cs: CGFloat, margin: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<config.rows, id: \.self) { r in
                Text(config.rowLabel(at: r))
                    .font(.system(size: min(cs * GridFont.colLabelScale, GridFont.colLabelMax),
                                  weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: margin, height: cs)
                    .offset(x: 0, y: config.yForRow(Double(r), cellSize: cs))
            }
        }
    }
}

// MARK: - Zoom controls

@available(iOS 17.0, macOS 14.0, *)
struct ZoomControls: View {
    @Binding var zoom: CGFloat
    /// Called by the "fit" button so the container can also reset the pan.
    var onReset: (() -> Void)?

    var body: some View {
        VStack(spacing: GridLayout.statsSpacing) {
            Button {
                withAnimation(.easeInOut(duration: GridAnimation.zoomDuration)) {
                    zoom = min(zoom * GridZoom.step, GridZoom.max)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: GridFont.zoomIcon, weight: .semibold))
                    .frame(width: GridLayout.zoomButtonSize, height: GridLayout.zoomButtonSize)
            }

            Text("\(Int(zoom * 100))%")
                .font(.system(size: GridFont.zoomPercent, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.easeInOut(duration: GridAnimation.zoomDuration)) {
                    zoom = max(zoom / GridZoom.step, GridZoom.min)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: GridFont.zoomIcon, weight: .semibold))
                    .frame(width: GridLayout.zoomButtonSize, height: GridLayout.zoomButtonSize)
            }

            Divider().frame(width: GridLayout.zoomDividerWidth)

            Button {
                withAnimation(.easeInOut(duration: GridAnimation.zoomDuration)) {
                    zoom = GridZoom.default
                    onReset?()
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: GridFont.zoomResetIcon, weight: .semibold))
                    .frame(width: GridLayout.zoomButtonSize, height: GridLayout.zoomButtonSize)
            }
        }
        .buttonStyle(.bordered)
        .background(.ultraThinMaterial)
        .clipShape(.buttonBorder)
    }
}
