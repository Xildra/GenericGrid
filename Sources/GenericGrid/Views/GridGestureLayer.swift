//
//  GridGestureLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Invisible hit-testing rectangle that handles tap and drag
//  gestures for item placement and movement.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridGestureLayer<Item: GridPlaceable>: View {
    let engine: GridEngine<Item>
    let cellSize: CGFloat
    let onInsert: (Item.ItemType, Double, Double, Bool) -> Void
    var onConflict: ((GridCell, Item) -> Void)?

    private var W: CGFloat { CGFloat(engine.cols) * cellSize }
    private var H: CGFloat { CGFloat(engine.rows) * cellSize }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: W, height: H)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard let cell = toCell(v.location) else { return }
                        switch engine.interaction {
                        case .moving:
                            engine.updateMove(to: cell)
                        case .idle, .previewing:
                            let startCell = toCell(v.startLocation) ?? cell
                            let cellOccupied = engine.map[startCell] != nil
                            let hasSelection = engine.selectedType != nil

                            if hasSelection {
                                engine.interaction = .previewing(anchor: cell)
                            } else if cellOccupied, let item = engine.map[startCell] {
                                engine.beginMove(item: item, at: startCell)
                                engine.updateMove(to: cell)
                            }
                        }
                    }
                    .onEnded { v in
                        guard let cell = toCell(v.location) else {
                            engine.cancelInteraction(); return
                        }
                        switch engine.interaction {
                        case .moving:
                            engine.commitMove()
                        case .previewing:
                            engine.place(at: cell, insert: onInsert, onConflict: onConflict)
                            engine.interaction = .idle
                        case .idle:
                            break
                        }
                    }
            )
    }

    // MARK: - Helpers

    /// Converts a touch point to the half-cell sub-cell it falls into.
    /// Uses floor at 0.5 resolution so the pointer always picks the
    /// sub-cell directly under the finger.
    private func toCell(_ pt: CGPoint) -> GridCell? {
        let r = (pt.y / cellSize * 2).rounded(.down) / 2
        let c = (pt.x / cellSize * 2).rounded(.down) / 2
        let rowsD = Double(engine.rows), colsD = Double(engine.cols)
        guard r >= 0, r + GridGesture.halfCell <= rowsD, c >= 0, c + GridGesture.halfCell <= colsD else { return nil }
        return GridCell(r, c: c)
    }
}
