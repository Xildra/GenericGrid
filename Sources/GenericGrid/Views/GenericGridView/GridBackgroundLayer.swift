//
//  GridBackgroundLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Canvas-drawn grid lines with rounded border.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridBackgroundLayer: View {
    let config: GridCanvasConfig
    let cellSize: CGFloat
    var showLines: Bool = true

    private var cols: Int { config.cols }
    private var totalRows: Int { config.totalVerticalCells }
    private var W: CGFloat { CGFloat(cols) * cellSize }
    private var H: CGFloat { CGFloat(totalRows) * cellSize }

    var body: some View {
        Canvas { ctx, size in
            guard showLines else { return }
            let sep = GraphicsContext.Shading.color(.secondary.opacity(GridOpacity.gridLine))
            for r in 0...totalRows {
                var p = Path(); let y = CGFloat(r) * cellSize
                p.move(to: .init(x: 0, y: y))
                p.addLine(to: .init(x: size.width, y: y))
                ctx.stroke(p, with: sep, lineWidth: GridLineWidth.gridLine)
            }
            for c in 0...cols {
                var p = Path(); let x = CGFloat(c) * cellSize
                p.move(to: .init(x: x, y: 0))
                p.addLine(to: .init(x: x, y: size.height))
                ctx.stroke(p, with: sep, lineWidth: GridLineWidth.gridLine)
            }
        }
        .frame(width: W, height: H)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: GridCornerRadius.grid))
        .overlay(RoundedRectangle(cornerRadius: GridCornerRadius.grid).stroke(.separator, lineWidth: GridLineWidth.gridLine))
    }
}
