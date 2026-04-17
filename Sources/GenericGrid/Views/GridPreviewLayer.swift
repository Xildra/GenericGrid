//
//  GridPreviewLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Displays a green (valid) or red (invalid) overlay
//  showing where the item would be placed. The bounding box
//  of all preview sub-cells is rendered as a single rounded shape
//  so half-cell positions still tile cleanly.
//

import SwiftUI

struct GridPreviewLayer: View {
    let cells: Set<GridCell>
    let isValid: Bool
    let cellSize: CGFloat

    var body: some View {
        if let rect = boundingRect {
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

    /// Bounding rectangle (in points) covering every sub-cell in the preview.
    private var boundingRect: CGRect? {
        guard !cells.isEmpty else { return nil }
        let rs = cells.map(\.r), cs = cells.map(\.c)
        let minR = rs.min()!, maxR = rs.max()! + GridGesture.halfCell
        let minC = cs.min()!, maxC = cs.max()! + GridGesture.halfCell
        let inset = GridLayout.previewInset
        return CGRect(x: minC * cellSize + inset,
                      y: minR * cellSize + inset,
                      width:  (maxC - minC) * cellSize - inset * 2,
                      height: (maxR - minR) * cellSize - inset * 2)
    }
}
