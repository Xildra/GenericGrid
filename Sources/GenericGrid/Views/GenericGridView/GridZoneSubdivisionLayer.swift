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
//  Drawn as a `Shape` (not a `Canvas`) so the internal lines animate in sync
//  with the frame while zooming, instead of snapping to the target.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridZoneSubdivisionLayer: View {
    let config: GridCanvasConfig
    let zones: [GridZoneDefinition]
    let cellSize: CGFloat

    var body: some View {
        ForEach(zones) { zone in
            let band = config.band(forZoneID: zone.id)
                ?? config.band(forRow: Int(zone.rowStart.rounded(.down)), atCol: zone.colStart)
            let bandCellW = config.bandCellWidth(band, baseCellSize: cellSize)
            ZoneInternalGridView(zone: zone,
                                 xOrigin: config.xForBand(band, baseCellSize: cellSize)
                                     + CGFloat(zone.colStart - Double(band.colStart)) * bandCellW,
                                 bandCellWidth: bandCellW,
                                 cellHeight: cellSize,
                                 yOrigin: config.yForRow(zone.rowStart, cellSize: cellSize))
                .allowsHitTesting(false)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ZoneInternalGridView: View {
    let zone: GridZoneDefinition
    /// Pixel x of the zone's left edge (band offset already applied).
    let xOrigin: CGFloat
    let bandCellWidth: CGFloat
    let cellHeight: CGFloat
    let yOrigin: CGFloat

    var body: some View {
        let w = CGFloat(zone.colSize) * bandCellWidth
        let h = CGFloat(zone.rowSize) * cellHeight

        ZStack {
            // Mask the global guide lines that run under this zone so the
            // zone's internal lines are the only ones visible inside.
            Rectangle().fill(.background)

            ZoneGridShape(rowCount: zone.rowCount, colCount: zone.colCount)
                .stroke(.secondary.opacity(GridOpacity.subdivisionLine),
                        lineWidth: GridLineWidth.gridLine)
        }
        .frame(width: w, height: h)
        .offset(x: xOrigin, y: yOrigin)
    }
}

/// A `rowCount × colCount` grid of lines, positioned relative to the drawing
/// `rect` so it animates with the frame while zooming.
@available(iOS 17.0, macOS 14.0, *)
private struct ZoneGridShape: Shape {
    let rowCount: Int
    let colCount: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if rowCount > 0 {
            for i in 0...rowCount {
                let y = CGFloat(i) * rect.height / CGFloat(rowCount)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y))
            }
        }
        if colCount > 0 {
            for i in 0...colCount {
                let x = CGFloat(i) * rect.width / CGFloat(colCount)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: rect.height))
            }
        }
        return path
    }
}
