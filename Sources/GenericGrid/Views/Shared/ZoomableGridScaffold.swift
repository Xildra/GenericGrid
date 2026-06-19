//
//  ZoomableGridScaffold.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Shared layout + zoom container reused by both the main grid
//  (`GenericGridView`) and the config preview (`ConfigGridPreviewView`).
//  The grid is laid out at the live zoomed cell size (so text and
//  compartment borders re-render crisp as you zoom) and pan is a manual
//  offset. Pinch updates the zoom continuously around the focal point.
//  The caller's grid gestures (tap / long-press move) live on the inner
//  content and keep priority — pan/pinch only handle touches the content
//  doesn't consume.
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
    private struct PinchSnapshot { let zoom: CGFloat; let pan: CGSize; let focal: CGPoint }

    private var hasLabels: Bool {
        config.rowLabels != nil || config.colLabels != nil || config.columnBands != nil
    }

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = hasLabels ? GridLayout.labelMargin : 0
            // Lay out at the actual zoomed cell size so text and borders stay
            // crisp at every zoom level (the grid re-renders as zoom changes).
            let baseCS = config.baseCellSize(in: geo.size, margin: margin)
            let cs = baseCS * zoom
            let W  = CGFloat(config.cols) * cs
            let H  = config.totalContentHeight(cellSize: cs)
            let bands = config.effectiveBands
            let strips = config.rowStrips

            gridBody(cellSize: cs, margin: margin, width: W, height: H, bands: bands, strips: strips)
                .frame(width: W + margin, height: H + margin, alignment: .topLeading)
                // Flatten the grid into one GPU layer so the live (crisp) zoom
                // re-renders smoothly each frame instead of re-laying out every
                // SwiftUI view (which juddered) — and with no scaleEffect there's
                // no blur and no commit "pop".
                .drawingGroup()
                .offset(pan)
                // Pin the viewport (and the zoom controls overlay) to the
                // container size, not the grid's frame which grows with zoom.
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(panGesture(viewport: geo.size, baseCS: baseCS, margin: margin))
                .simultaneousGesture(magnifyGesture(viewport: geo.size, baseCS: baseCS, margin: margin))
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    ZoomControls(zoom: $zoom, onReset: { pan = .zero })
                        .padding(GridLayout.zoomControlsPadding)
                }
                // Re-clamp after a button zoom so the grid can't sit off-screen.
                .onChange(of: zoom) {
                    pan = clampedPan(pan, zoom: zoom, viewport: geo.size, baseCS: baseCS, margin: margin)
                }
                // Re-centre on first layout and whenever the viewport changes
                // (e.g. the side lists are collapsed), so the grid follows the
                // new centre instead of staying pinned left.
                .onChange(of: geo.size, initial: true) {
                    pan = settledPan(pan, zoom: zoom, viewport: geo.size, baseCS: baseCS, margin: margin)
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
    private func panGesture(viewport: CGSize, baseCS: CGFloat, margin: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: GridLayout.panMinDistance)
            .onChanged { value in
                guard !scrollDisabled else { return }
                let start = panStart ?? pan
                if panStart == nil { panStart = pan }
                let raw = CGSize(width: start.width + value.translation.width,
                                 height: start.height + value.translation.height)
                pan = clampedPan(raw, zoom: zoom, viewport: viewport, baseCS: baseCS, margin: margin)
            }
            .onEnded { value in
                panStart = nil
                // Kinetic scroll: fling the pan to a velocity-projected target
                // (clamped), decelerating — instead of stopping dead at the finger.
                let projected = CGSize(
                    width: pan.width + value.velocity.width * GridLayout.momentumFactor,
                    height: pan.height + value.velocity.height * GridLayout.momentumFactor)
                let target = settledPan(projected, zoom: zoom, viewport: viewport, baseCS: baseCS, margin: margin)
                withAnimation(.easeOut(duration: GridAnimation.momentumDuration)) {
                    pan = target
                }
            }
    }

    /// Pinch zoom anchored on the viewport centre: the centre point stays put
    /// while the scale changes (pan separately to position the grid).
    private func magnifyGesture(viewport: CGSize, baseCS: CGFloat, margin: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // Central pinch: zoom about the viewport centre. The real layout
                // zoom is updated live (crisp — no blur, no commit "pop"); the
                // grid's drawingGroup keeps it smooth.
                let center = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
                let snap = pinchStart ?? PinchSnapshot(zoom: zoom, pan: pan, focal: center)
                if pinchStart == nil { pinchStart = snap }
                let mag = 1 + (value.magnification - 1) * GridZoom.pinchSensitivity
                let newZoom = min(max(snap.zoom * mag, GridZoom.min), GridZoom.max)
                let scale = newZoom / snap.zoom
                // Centre-preserving pan for the new zoom, clamped.
                let raw = CGSize(width: snap.focal.x - (snap.focal.x - snap.pan.width) * scale,
                                 height: snap.focal.y - (snap.focal.y - snap.pan.height) * scale)
                zoom = newZoom
                pan = clampedPan(raw, zoom: newZoom, viewport: viewport, baseCS: baseCS, margin: margin)
            }
            .onEnded { _ in pinchStart = nil }
    }

    // MARK: - Pan clamping

    /// Keeps the grid from being panned/zoomed off-screen: when the content is
    /// larger than the viewport it stays edge-to-edge (no empty gutter); when
    /// smaller it stays fully inside.
    /// Clamp used while dragging/pinching: allows overscroll past the resting
    /// bounds, so the grid can be nudged even at 100% (where it exactly fits).
    private func clampedPan(_ p: CGSize, zoom: CGFloat, viewport: CGSize,
                            baseCS: CGFloat, margin: CGFloat) -> CGSize {
        let (cw, ch) = contentSize(zoom: zoom, baseCS: baseCS, margin: margin)
        return CGSize(width:  clampAxis(p.width,  content: cw, viewport: viewport.width),
                      height: clampAxis(p.height, content: ch, viewport: viewport.height))
    }

    /// Resting clamp (no overscroll): where the grid settles after a fling and
    /// on appear/resize — centred when it fits, edge-aligned when larger.
    private func settledPan(_ p: CGSize, zoom: CGFloat, viewport: CGSize,
                            baseCS: CGFloat, margin: CGFloat) -> CGSize {
        let (cw, ch) = contentSize(zoom: zoom, baseCS: baseCS, margin: margin)
        return CGSize(width:  settleAxis(p.width,  content: cw, viewport: viewport.width),
                      height: settleAxis(p.height, content: ch, viewport: viewport.height))
    }

    private func contentSize(zoom: CGFloat, baseCS: CGFloat, margin: CGFloat) -> (CGFloat, CGFloat) {
        let cs = baseCS * zoom
        return (CGFloat(config.cols) * cs + margin, config.totalContentHeight(cellSize: cs) + margin)
    }

    private func clampAxis(_ v: CGFloat, content: CGFloat, viewport: CGFloat) -> CGFloat {
        let over = viewport * GridLayout.overscrollFraction
        if content > viewport {
            return min(max(v, viewport - content - over), over)
        }
        // Fits: allow nudging around the centre (so panning works at 100% too).
        let center = (viewport - content) / 2
        return min(max(v, center - over), center + over)
    }

    private func settleAxis(_ v: CGFloat, content: CGFloat, viewport: CGFloat) -> CGFloat {
        content <= viewport ? (viewport - content) / 2 : min(max(v, viewport - content), 0)
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
                zoom = min(zoom * GridZoom.step, GridZoom.max)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: GridFont.zoomIcon, weight: .semibold))
                    .frame(width: GridLayout.zoomButtonSize, height: GridLayout.zoomButtonSize)
            }

            Text("\(Int(zoom * 100))%")
                .font(.system(size: GridFont.zoomPercent, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                zoom = max(zoom / GridZoom.step, GridZoom.min)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: GridFont.zoomIcon, weight: .semibold))
                    .frame(width: GridLayout.zoomButtonSize, height: GridLayout.zoomButtonSize)
            }

            Divider().frame(width: GridLayout.zoomDividerWidth)

            Button {
                zoom = GridZoom.default
                onReset?()
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
