//
//  GridCompartmentBordersLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Draws per-compartment custom borders on top of the grid. One
//  rounded stroke is rendered around each band that carries a
//  `borderColor` and a non-zero `borderWidth`. The layer sits above
//  zone overlays so the border stays visible even when the
//  compartment is entirely covered by zone fills.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridCompartmentBordersLayer: View {
    let config: GridCanvasConfig
    let cellSize: CGFloat

    private var W: CGFloat { CGFloat(config.cols) * cellSize }
    private var H: CGFloat { config.totalContentHeight(cellSize: cellSize) }

    var body: some View {
        Canvas { ctx, _ in
            for band in config.effectiveBands where band.hasCustomBorder {
                guard let color = band.borderColor,
                      let width = band.borderWidth, width > 0 else { continue }
                // The configured width is defined at the nominal cell
                // size and scales with it, so the border keeps the same
                // proportions at every zoom level instead of staying a
                // fixed-pt stroke that dwarfs zoomed-out cells.
                let lineWidth = max(GridLineWidth.gridLine,
                                    CGFloat(width) * cellSize / GridCellSize.default)
                let x = config.xForBand(band, baseCellSize: cellSize)
                let y = config.yForRow(Double(band.rowStart), cellSize: cellSize)
                let w = CGFloat(band.colCount) * cellSize
                let h = CGFloat(band.rowCount) * cellSize
                // Inset by half the stroke width so the visible rect
                // matches the band's cell boundaries (strokes are
                // centred on the path by default).
                let inset = lineWidth / 2
                let rect = CGRect(x: x + inset, y: y + inset,
                                  width: max(0, w - inset * 2),
                                  height: max(0, h - inset * 2))
                ctx.stroke(Path(rect),
                           with: .color(color),
                           lineWidth: lineWidth)
            }
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }
}
