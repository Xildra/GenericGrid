//
//  GridBackgroundLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Canvas-drawn grid lines with rounded border. Horizontal lines run
//  edge-to-edge for every visual row slot. Vertical lines are drawn
//  per compartment so a band with its own column count produces its
//  own column subdivision while keeping the overall grid width fixed.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridBackgroundLayer: View {
    let config: GridCanvasConfig
    let cellSize: CGFloat
    var showLines: Bool = true

    private var W: CGFloat { CGFloat(config.cols) * cellSize }
    private var H: CGFloat { config.totalContentHeight(cellSize: cellSize) }

    var body: some View {
        Canvas { ctx, size in
            guard showLines else { return }
            let sep = GraphicsContext.Shading.color(.secondary.opacity(GridOpacity.gridLine))

            // Horizontal lines: one per visual row slot (data + headers).
            for slot in 0...config.totalVerticalCells {
                var p = Path()
                let y = CGFloat(slot) * cellSize
                p.move(to: .init(x: 0, y: y))
                p.addLine(to: .init(x: size.width, y: y))
                ctx.stroke(p, with: sep, lineWidth: GridLineWidth.gridLine)
            }

            // Vertical lines: per compartment, spanning its data rows
            // and its intermediate header strip when present.
            for (idx, band) in config.effectiveBands.enumerated() {
                let bandCols = config.cols(for: band)
                let bandCellW = config.bandCellWidth(band, baseCellSize: cellSize)
                var yStart = config.yForRow(Double(band.rowStart), cellSize: cellSize)
                let yEnd = yStart + CGFloat(band.rowCount) * cellSize
                if idx > 0 { yStart -= cellSize }   // include header strip
                for c in 0...bandCols {
                    var p = Path()
                    let x = CGFloat(c) * bandCellW
                    p.move(to: .init(x: x, y: yStart))
                    p.addLine(to: .init(x: x, y: yEnd))
                    ctx.stroke(p, with: sep, lineWidth: GridLineWidth.gridLine)
                }
            }
        }
        .frame(width: W, height: H)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: GridCornerRadius.grid))
        .overlay(RoundedRectangle(cornerRadius: GridCornerRadius.grid).stroke(.separator, lineWidth: GridLineWidth.gridLine))
    }
}
