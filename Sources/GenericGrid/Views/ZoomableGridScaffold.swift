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
        config.rowLabels != nil || config.colLabels != nil
    }

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = hasLabels ? GridLayout.labelMargin : 0
            let baseCS = config.baseCellSize(in: geo.size, margin: margin)
            let cs = baseCS * zoom
            let W  = CGFloat(config.cols) * cs
            let H  = CGFloat(config.rows) * cs

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    if hasLabels {
                        columnLabels(cellSize: cs, margin: margin)
                            .offset(x: margin, y: 0)
                        rowLabels(cellSize: cs, margin: margin)
                            .offset(x: 0, y: margin)
                    }
                    content(cs)
                        .frame(width: W, height: H)
                        .offset(x: margin, y: margin)
                }
                .frame(width: W + margin, height: H + margin)
                .frame(
                    minWidth: geo.size.width,
                    minHeight: geo.size.height,
                    alignment: .center
                )
				.padding(.bottom, 30)
            }
            .scrollDisabled(scrollDisabled)
            .overlay(alignment: .bottomTrailing) {
                ZoomControls(zoom: $zoom).padding(GridLayout.zoomControlsPadding)
            }
        }
        .background(.background.secondary)
    }

    // MARK: - Labels

    private func columnLabels(cellSize cs: CGFloat, margin: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<config.cols, id: \.self) { c in
                Text(config.colLabel(at: c))
                    .font(.system(size: min(cs * GridFont.colLabelScale, GridFont.colLabelMax),
                                  weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: cs, height: margin)
            }
        }
    }

    private func rowLabels(cellSize cs: CGFloat, margin: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<config.rows, id: \.self) { r in
                Text(config.rowLabel(at: r))
                    .font(.system(size: min(cs * GridFont.colLabelScale, GridFont.colLabelMax),
                                  weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: margin, height: cs)
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
