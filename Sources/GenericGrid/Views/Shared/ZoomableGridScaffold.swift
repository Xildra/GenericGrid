//
//  ZoomableGridScaffold.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Shared layout + zoom container reused by both the main grid
//  (`GenericGridView`) and the config preview (`ConfigGridPreviewView`).
//  Callers supply the inner grid content; the scaffold handles:
//   - row / column labels and margin reservation,
//   - scroll behaviour and centring of small grids,
//   - base cell sizing and pinch-style zoom controls.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ZoomableGridScaffold<Content: View>: View {

    let config: GridCanvasConfig
    @Binding var zoom: CGFloat
    /// Disables scrolling while the caller is doing direct manipulation
    /// (drag-to-place, drag-to-move…) to avoid scroll/drag conflicts.
    var scrollDisabled: Bool = false
    @ViewBuilder let content: (_ cellSize: CGFloat) -> Content

    private var hasLabels: Bool {
        config.rowLabels != nil || config.colLabels != nil || config.columnBands != nil
    }

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = hasLabels ? GridLayout.labelMargin : 0
            let baseCS = config.baseCellSize(in: geo.size, margin: margin)
            let cs = baseCS * zoom
            let W  = CGFloat(config.cols) * cs
            let H  = config.totalContentHeight(cellSize: cs)
            let bands = config.effectiveBands
            let strips = config.rowStrips

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
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
                .frame(width: W + margin, height: H + margin)
                .frame(
                    minWidth: geo.size.width,
                    minHeight: geo.size.height,
                    alignment: .center
                )
                .padding(GridLayout.gridPadding)
            }
            .scrollDisabled(scrollDisabled)
            .overlay(alignment: .bottomTrailing) {
                ZoomControls(zoom: $zoom).padding(GridLayout.zoomControlsPadding)
            }
        }
        .background(.background.secondary)
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
