//
//  GridGestureLayer.swift
//  GenericGrid Module
//
//  Invisible hit-testing rectangle that handles tap and drag
//  gestures for item placement and movement.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridGestureLayer<Item: GridPlaceable>: View {
    let engine: GridEngine<Item>
    let cellSize: CGFloat
    let onInsert: (Item.ItemType, Int, Int, Bool) -> Void
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

    private func toCell(_ pt: CGPoint) -> GridCell? {
        let c = Int(pt.x / cellSize), r = Int(pt.y / cellSize)
        guard c >= 0, c < engine.cols, r >= 0, r < engine.rows else { return nil }
        return GridCell(r, c: c)
    }
}
