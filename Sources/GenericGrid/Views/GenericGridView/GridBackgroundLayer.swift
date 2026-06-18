//
//  GridBackgroundLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Grid lines with rounded border. Horizontal lines run edge-to-edge for
//  every visual row slot. Vertical lines are drawn per compartment so a band
//  with its own column count produces its own column subdivision while keeping
//  the overall grid width fixed.
//
//  Drawn as a `Shape` (not a `Canvas`): its path is computed relative to the
//  rect it is given, so when the grid frame animates (zoom) the lines scale in
//  sync with the cells, zones and labels instead of snapping to the target.
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
        Rectangle().fill(.background)
            .overlay {
                if showLines {
                    GridLinesShape(config: config, cellSize: cellSize)
                        .stroke(.secondary.opacity(GridOpacity.gridLine),
                                lineWidth: GridLineWidth.gridLine)
                }
            }
            .frame(width: W, height: H)
            .clipShape(RoundedRectangle(cornerRadius: GridCornerRadius.grid))
            .overlay(RoundedRectangle(cornerRadius: GridCornerRadius.grid)
                .stroke(.separator, lineWidth: GridLineWidth.gridLine))
    }
}

/// Grid lines whose positions are expressed relative to the drawing `rect`, so
/// they animate together with the frame (and thus with every other layer).
@available(iOS 17.0, macOS 14.0, *)
private struct GridLinesShape: Shape {
    let config: GridCanvasConfig
    let cellSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let fullW = CGFloat(config.cols) * cellSize
        let fullH = config.totalContentHeight(cellSize: cellSize)
        guard fullW > 0, fullH > 0 else { return path }
        let sx = rect.width / fullW
        let sy = rect.height / fullH

        // Horizontal lines: one per visual row slot (data + headers).
        for slot in 0...config.totalVerticalCells {
            let y = CGFloat(slot) * cellSize * sy
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }

        // Vertical lines: per compartment, spanning its data rows and its
        // intermediate strip header when one sits above it.
        for band in config.effectiveBands {
            let bandSubdivisions = config.cols(for: band)
            let bandCellW = config.bandCellWidth(band, baseCellSize: cellSize)
            let xOff = config.xForBand(band, baseCellSize: cellSize)
            var yStart = config.yForRow(Double(band.rowStart), cellSize: cellSize)
            let yEnd = yStart + CGFloat(band.rowCount) * cellSize
            if config.rowStripIndex(forRow: band.rowStart) > 0 {
                yStart -= cellSize   // include strip header above the band
            }
            for c in 0...bandSubdivisions {
                let x = (xOff + CGFloat(c) * bandCellW) * sx
                path.move(to: CGPoint(x: x, y: yStart * sy))
                path.addLine(to: CGPoint(x: x, y: yEnd * sy))
            }
        }
        return path
    }
}
