//
//  GridCompartmentBordersLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Draws per-compartment custom borders on top of the grid. One stroked
//  rectangle is rendered around each band that carries a `borderColor` and a
//  non-zero `borderWidth`. Built from SwiftUI shapes (not a Canvas) so the
//  borders re-layout in perfect sync with the cells/zones while zooming or
//  when the viewport resizes. Sits above zone overlays so the border stays
//  visible even when the compartment is fully covered by zone fills.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridCompartmentBordersLayer: View {
    let config: GridCanvasConfig
    let cellSize: CGFloat

    private var W: CGFloat { CGFloat(config.cols) * cellSize }
    private var H: CGFloat { config.totalContentHeight(cellSize: cellSize) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(config.effectiveBands.filter { $0.hasCustomBorder }, id: \.id) { band in
                if let color = band.borderColor,
                   let width = band.borderWidth, width > 0 {
                    // The configured width is defined at the nominal cell size
                    // and scales with it, so the border keeps the same
                    // proportions at every zoom level.
                    let lineWidth = max(GridLineWidth.gridLine,
                                        CGFloat(width) * cellSize / GridCellSize.default)
                    // `strokeBorder` draws the stroke inside the frame, so it
                    // aligns to the band's cell boundaries without manual insets.
                    Rectangle()
                        .strokeBorder(color, lineWidth: lineWidth)
                        .frame(width: CGFloat(band.colCount) * cellSize,
                               height: CGFloat(band.rowCount) * cellSize)
                        .offset(x: config.xForBand(band, baseCellSize: cellSize),
                                y: config.yForRow(Double(band.rowStart), cellSize: cellSize))
                }
            }
        }
        .frame(width: W, height: H, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
