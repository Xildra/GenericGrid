//
//  GridGestureLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Invisible hit-testing rectangle that handles tap and drag
//  gestures for item placement and movement.
//
//  Gestures are structured so the enclosing ScrollView keeps working:
//  - a plain Tap places the selected type at the tapped cell,
//  - a LongPress-then-Drag shows a preview (when a type is selected)
//    or moves an existing item (when tapping on one).
//  A quick swipe with no long-press falls through to the ScrollView.
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
            .onTapGesture(coordinateSpace: .local) { location in
                guard engine.selectedType != nil,
                      let cell = toCell(location) else { return }
                engine.place(at: cell, insert: onInsert, onConflict: onConflict)
            }
            // `simultaneousGesture` lets the enclosing ScrollView keep handling
            // quick swipes — our long-press only takes over when the finger
            // stays still, so plain scrolls still pass through.
            .simultaneousGesture(longPressDragGesture)
    }

    // MARK: - Long-press + drag gesture

    private var longPressDragGesture: some Gesture {
        LongPressGesture(minimumDuration: GridGesture.longPressDuration)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                guard case .second(_, let drag?) = value,
                      let cell = toCell(drag.location) else { return }
                switch engine.interaction {
                case .moving:
                    engine.updateMove(to: cell)
                case .idle, .previewing:
                    let startCell = toCell(drag.startLocation) ?? cell
                    if engine.selectedType != nil {
                        engine.interaction = .previewing(anchor: cell)
                    } else if let item = engine.map[startCell] {
                        engine.beginMove(item: item, at: startCell)
                        engine.updateMove(to: cell)
                    }
                }
            }
            .onEnded { value in
                guard case .second(_, let drag?) = value,
                      let cell = toCell(drag.location) else {
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
    }

    // MARK: - Helpers

    /// Converts a touch point to the anchor cell it falls into.
    /// Delegates to `GridCanvasConfig.snap` which snaps to the owning
    /// zone's local step when inside a subdivision zone, or to the
    /// global half-cell guide otherwise.
    private func toCell(_ pt: CGPoint) -> GridCell? {
        let rowsD = Double(engine.rows), colsD = Double(engine.cols)
        let r = Double(pt.y / cellSize)
        let c = Double(pt.x / cellSize)
        guard r >= 0, r <= rowsD, c >= 0, c <= colsD else { return nil }
        let snapped = engine.config.snap(GridCell(r, c: c))
        guard snapped.r + GridGesture.halfCell <= rowsD,
              snapped.c + GridGesture.halfCell <= colsD else { return nil }
        return snapped
    }
}
