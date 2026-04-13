//
//  GridPreviewLayer.swift
//  GenericGrid Module
//
//  Displays a green (valid) or red (invalid) overlay
//  showing where the item would be placed.
//

import SwiftUI

struct GridPreviewLayer: View {
    let cells: Set<GridCell>
    let isValid: Bool
    let cellSize: CGFloat

    var body: some View {
        ForEach(Array(cells), id: \.self) { cell in
            RoundedRectangle(cornerRadius: 4)
                .fill(isValid ? Color.green.opacity(0.22) : Color.red.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isValid ? Color.green.opacity(0.7) : Color.red.opacity(0.6), lineWidth: 1.2)
                )
                .frame(width: cellSize - 2, height: cellSize - 2)
                .offset(x: CGFloat(cell.c) * cellSize + 1, y: CGFloat(cell.r) * cellSize + 1)
                .allowsHitTesting(false)
        }
    }
}
