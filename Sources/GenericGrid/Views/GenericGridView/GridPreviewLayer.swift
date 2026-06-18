//
//  GridPreviewLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Displays a green (valid) or red (invalid) overlay showing where the item
//  would be placed. By default it is the bounding box of the preview sub-cells
//  (the footprint); when `fillZone` is on and the anchor sits in a zone, the
//  whole zone is highlighted so the preview matches the placed item.
//

import SwiftUI

struct GridPreviewLayer: View {
    let config: GridCanvasConfig
    let cells: Set<GridCell>
    let isValid: Bool
    let cellSize: CGFloat
    var fillZone: Bool = false

    var body: some View {
        if let rect = previewRect {
            RoundedRectangle(cornerRadius: GridCornerRadius.zone)
                .fill(isValid ? Color.green.opacity(GridOpacity.previewValidFill) : Color.red.opacity(GridOpacity.previewInvalidFill))
                .overlay(
                    RoundedRectangle(cornerRadius: GridCornerRadius.zone)
                        .stroke(isValid ? Color.green.opacity(GridOpacity.previewValidStroke) : Color.red.opacity(GridOpacity.previewInvalidStroke),
                                lineWidth: GridLineWidth.preview)
                )
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)
        }
    }

    /// Rect highlighted by the preview. In `fillZone` mode the containing zone's
    /// box is used (shared `config.zoneRect`, so it lines up exactly with the
    /// placed item); otherwise the footprint bounding box.
    private var previewRect: CGRect? {
        guard !cells.isEmpty else { return nil }
        let inset = GridLayout.previewInset
        if fillZone {
            let minR = cells.map(\.r).min()!
            let minC = cells.map(\.c).min()!
            if let zone = config.zone(at: GridCell(minR, c: minC)) {
                return config.zoneRect(zone, cellSize: cellSize).insetBy(dx: inset, dy: inset)
            }
        }
        return boundingRect(inset: inset)
    }

    /// Bounding rectangle (in points) covering every sub-cell in the preview.
    /// Cell coordinates are absolute; the owning compartment (resolved from
    /// both axes) supplies the cell width so the preview tiles correctly inside
    /// bands with a custom column count.
    private func boundingRect(inset: CGFloat) -> CGRect {
        let rs = cells.map(\.r), cs = cells.map(\.c)
        let minR = rs.min()!, maxR = rs.max()! + GridGesture.halfCell
        let minC = cs.min()!, maxC = cs.max()! + GridGesture.halfCell
        let band = config.band(forRow: Int(minR.rounded(.down)), atCol: minC)
        let bandCellW = config.bandCellWidth(band, baseCellSize: cellSize)
        let xOff = config.xForBand(band, baseCellSize: cellSize)
        let yTop = config.yForRow(minR, cellSize: cellSize)
        return CGRect(x: xOff + CGFloat(minC - Double(band.colStart)) * bandCellW + inset,
                      y: yTop + inset,
                      width:  CGFloat(maxC - minC) * bandCellW - inset * 2,
                      height: CGFloat(maxR - minR) * cellSize - inset * 2)
    }
}
