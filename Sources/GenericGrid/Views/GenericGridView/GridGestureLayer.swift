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
import UniformTypeIdentifiers

@available(iOS 17.0, macOS 14.0, *)
struct GridGestureLayer<Item: GridPlaceable>: View {
    let engine: GridEngine<Item>
    let cellSize: CGFloat
    let onInsert: (Item.ItemType, Double, Double, Bool) -> Void
    var onConflict: ((GridCell, Item) -> Void)?
    var onLock: ((GridCell) -> Void)?
    var onUnlock: ((GridCell) -> Void)?

    private var W: CGFloat { CGFloat(engine.cols) * cellSize }
    private var H: CGFloat { engine.config.totalContentHeight(cellSize: cellSize) }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: W, height: H)
            .onTapGesture(coordinateSpace: .local) { location in
                guard let cell = toCell(location) else { return }
                if engine.selectedType != nil {
                    engine.place(at: cell, insert: onInsert, onConflict: onConflict)
                } else {
                    switch engine.toggleLocked(at: cell) {
                    case .locked(let c):   onLock?(c)
                    case .unlocked(let c): onUnlock?(c)
                    case .noChange:        break
                    }
                }
            }
            // `simultaneousGesture` lets the enclosing ScrollView keep handling
            // quick swipes — our long-press only takes over when the finger
            // stays still, so plain scrolls still pass through.
            .simultaneousGesture(longPressDragGesture)
            // Drag-and-drop placement: the app makes its list rows draggable
            // and sets `engine.selectedType` on drag start; the grid drives a
            // live preview during the hover and places on drop. Generic — the
            // module never inspects the dragged payload.
            .onDrop(of: [.text], delegate: GridDropDelegate(
                engine: engine, cellSize: cellSize,
                onInsert: onInsert, onConflict: onConflict))
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
                    // Long-press + drag is reserved for moving an existing
                    // item. Placement is done by tap or drag-and-drop, so a
                    // selected type no longer starts a drag-preview here.
                    let startCell = toCell(drag.startLocation) ?? cell
                    if let item = engine.map[startCell] {
                        engine.beginMove(item: item, at: startCell)
                        engine.updateMove(to: cell)
                    }
                }
            }
            .onEnded { _ in
                // Only moves are driven by this gesture now; commit on release,
                // otherwise make sure any stray interaction is cleared.
                if case .moving = engine.interaction {
                    engine.commitMove()
                } else {
                    engine.cancelInteraction()
                }
            }
    }

    // MARK: - Helpers

    /// Converts a touch point to the anchor cell it falls into.
    /// Delegates to `GridCanvasConfig.cell(at:cellSize:)`, which
    /// resolves the owning compartment from both axes (so side-by-side
    /// compartments hit-test correctly), rejects intermediate header
    /// strips, and snaps to the owning zone's unit grid or the
    /// half-cell guide.
    private func toCell(_ pt: CGPoint) -> GridCell? {
        engine.config.cell(at: pt, cellSize: cellSize)
    }
}

// MARK: - Drag & drop placement

/// `DropDelegate` that turns a drag-and-drop session into a grid placement.
/// During the hover it drives `engine.interaction = .previewing` (so the
/// existing preview layer reacts, honouring `placementRule`); on drop it runs
/// the standard `engine.place`. The dragged payload is ignored — the app sets
/// `engine.selectedType` when the drag starts, keeping the module agnostic of
/// the item being dragged.
@available(iOS 17.0, macOS 14.0, *)
struct GridDropDelegate<Item: GridPlaceable>: DropDelegate {
    let engine: GridEngine<Item>
    let cellSize: CGFloat
    let onInsert: (Item.ItemType, Double, Double, Bool) -> Void
    var onConflict: ((GridCell, Item) -> Void)?

    func validateDrop(info: DropInfo) -> Bool {
        engine.selectedType != nil
    }

    func dropEntered(info: DropInfo) { preview(at: info) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        preview(at: info)
        return DropProposal(operation: engine.selectedType == nil ? .forbidden : .copy)
    }

    func dropExited(info: DropInfo) { engine.cancelInteraction() }

    func performDrop(info: DropInfo) -> Bool {
        defer { engine.interaction = .idle }
        guard engine.selectedType != nil,
              let cell = engine.config.cell(at: info.location, cellSize: cellSize)
        else { return false }
        engine.place(at: cell, insert: onInsert, onConflict: onConflict)
        return true
    }

    private func preview(at info: DropInfo) {
        guard engine.selectedType != nil,
              let cell = engine.config.cell(at: info.location, cellSize: cellSize) else {
            engine.interaction = .idle
            return
        }
        engine.interaction = .previewing(anchor: cell)
    }
}
