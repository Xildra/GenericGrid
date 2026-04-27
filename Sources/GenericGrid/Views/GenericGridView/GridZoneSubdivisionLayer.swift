//
//  GridZoneSubdivisionLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Draws each zone's own internal grid. Every zone shows
//  `rowCount × colCount` unit cells, aligned on the zone's own
//  origin — decoupled from the global guide, which is why the
//  guide can be hidden while zone grids stay visible.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridZoneSubdivisionLayer: View {
    let config: GridCanvasConfig
    let zones: [GridZoneDefinition]
    let cellSize: CGFloat

    var body: some View {
        ForEach(zones) { zone in
            let band = config.band(forRow: Int(zone.rowStart.rounded(.down)))
            ZoneInternalGridView(zone: zone,
                                 bandCellWidth: config.bandCellWidth(band, baseCellSize: cellSize),
                                 cellHeight: cellSize,
                                 yOrigin: config.yForRow(zone.rowStart, cellSize: cellSize))
                .allowsHitTesting(false)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ZoneInternalGridView: View {
    let zone: GridZoneDefinition
    let bandCellWidth: CGFloat
    let cellHeight: CGFloat
    let yOrigin: CGFloat

    var body: some View {
        let x = CGFloat(zone.colStart) * bandCellWidth
        let y = yOrigin
        let w = CGFloat(zone.colSize) * bandCellWidth
        let h = CGFloat(zone.rowSize) * cellHeight
        let rowCount = zone.rowCount
        let colCount = zone.colCount

        ZStack {
            // Mask the global guide lines that run under this zone so
            // the zone's internal lines are the only ones visible inside.
            Rectangle().fill(.background)

            Canvas { ctx, size in
                let shading = GraphicsContext.Shading.color(.secondary.opacity(GridOpacity.subdivisionLine))
                for i in 0...rowCount {
                    var p = Path()
                    let ly = CGFloat(i) * size.height / CGFloat(rowCount)
                    p.move(to: CGPoint(x: 0, y: ly))
                    p.addLine(to: CGPoint(x: size.width, y: ly))
                    ctx.stroke(p, with: shading, lineWidth: GridLineWidth.gridLine)
                }
                for i in 0...colCount {
                    var p = Path()
                    let lx = CGFloat(i) * size.width / CGFloat(colCount)
                    p.move(to: CGPoint(x: lx, y: 0))
                    p.addLine(to: CGPoint(x: lx, y: size.height))
                    ctx.stroke(p, with: shading, lineWidth: GridLineWidth.gridLine)
                }
            }
        }
        .frame(width: w, height: h)
        .offset(x: x, y: y)
    }
}
