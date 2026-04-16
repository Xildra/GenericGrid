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
            RoundedRectangle(cornerRadius: 4)
                .fill(isValid ? Color.green.opacity(0.22) : Color.red.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isValid ? Color.green.opacity(0.7) : Color.red.opacity(0.6),
                                lineWidth: 1.2)
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
        let minR = rs.min()!, maxR = rs.max()! + 0.5   // each sub-cell spans 0.5
        let minC = cs.min()!, maxC = cs.max()! + 0.5
        return CGRect(x: minC * cellSize + 1,
                      y: minR * cellSize + 1,
                      width:  (maxC - minC) * cellSize - 2,
                      height: (maxR - minR) * cellSize - 2)
    }
}
