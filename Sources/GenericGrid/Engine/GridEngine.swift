//
//  GridEngine.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Observable state machine and logic engine for the grid.
//  Manages occupancy map, placement validation, drag & drop,
//  and exposes statistics / preview state.
//

import SwiftUI
import Observation

@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class GridEngine<Item: GridPlaceable> {

    // MARK: - Configuration

    /// Grid configuration (zones, dimensions). Updating it resets rows/cols.
    public var config: GridCanvasConfig {
        didSet { rows = config.rows; cols = config.cols }
    }

    public var rows: Int
    public var cols: Int

    // MARK: - Selection

    /// The item type currently selected for placement (nil = no selection).
    public var selectedType: Item.ItemType?
    /// Whether the selected type should be rotated before placement.
    public var rotated: Bool = false

    // MARK: - Interaction state

    public var interaction: GridInteraction<Item> = .idle

    // MARK: - Occupancy map (O(1) lookup)

    public private(set) var map: [GridCell: Item] = [:]

    // MARK: - Init

    public init(config: GridCanvasConfig = .default) {
        self.config = config
        self.rows = config.rows
        self.cols = config.cols
    }

    // MARK: - Sync

    /// Rebuilds the occupancy map from an external item array (e.g. SwiftData query).
    public func sync(_ items: [Item]) {
        var m = [GridCell: Item]()
        for item in items { for c in item.cells { m[c] = item } }
        map = m
    }

    /// Immediately registers an item in the map (before the next SwiftData sync)
    /// to prevent double-placements on rapid taps.
    public func registerImmediate(_ item: Item) {
        for c in item.cells { map[c] = item }
    }

    /// Immediately removes an item from the map.
    public func unregisterImmediate(_ item: Item) {
        for c in item.cells {
            if map[c] === item { map[c] = nil }
        }
    }

    // MARK: - Footprint

    /// Computes the set of cells that an item type would occupy at the given anchor.
    public func footprint(anchor: GridCell, type: Item.ItemType, rotated: Bool) -> [GridCell] {
        let w = rotated ? type.height : type.width
        let h = rotated ? type.width  : type.height
        return (anchor.r ..< anchor.r + h).flatMap { r in
            (anchor.c ..< anchor.c + w).map { GridCell(r, c: $0) }
        }
    }

    // MARK: - Validation

    /// Returns `true` if an item of the given type can be placed at the anchor,
    /// respecting bounds, occupancy, and zone rules.
    public func canPlace(anchor: GridCell, type: Item.ItemType, rotated: Bool,
                         excluding: Item? = nil) -> Bool {
        let cells = footprint(anchor: anchor, type: type, rotated: rotated)
        return cells.allSatisfy { cell in
            cell.r >= 0 && cell.r < rows &&
            cell.c >= 0 && cell.c < cols &&
            (map[cell] == nil || map[cell] === excluding) &&
            config.canAccept(cell: cell, typeName: type.name)
        }
    }

    /// Returns `true` if the cell is inside a locked zone.
    public func isLocked(at cell: GridCell) -> Bool {
        guard let z = config.zone(at: cell) else { return false }
        return z.rule == .locked
    }

    // MARK: - Placement (delegated via callbacks, SwiftData-agnostic)

    public typealias InsertHandler = (Item.ItemType, Int, Int, Bool) -> Void
    public typealias ConflictHandler = (GridCell, Item) -> Void

    /// Attempts to place the currently selected type at the given anchor.
    /// Calls `insert` on success, or `onConflict` when the target cells are occupied.
    public func place(at anchor: GridCell, insert: InsertHandler,
                      onConflict: ConflictHandler? = nil) {
        guard let t = selectedType else { return }
        let cells = footprint(anchor: anchor, type: t, rotated: rotated)

        // Bounds check
        let inBounds = cells.allSatisfy { $0.r >= 0 && $0.r < rows && $0.c >= 0 && $0.c < cols }
        guard inBounds else { return }

        // Zone rules check
        let zoneOk = cells.allSatisfy { config.canAccept(cell: $0, typeName: t.name) }
        guard zoneOk else { return }

        // Check for existing occupant
        let occupant = cells.compactMap({ map[$0] }).first

        if occupant == nil {
            insert(t, anchor.r, anchor.c, rotated)
        } else if let onConflict, let existing = occupant {
            onConflict(anchor, existing)
        }
        // If occupied and no onConflict handler → silent no-op
    }

    // MARK: - Move (drag & drop)

    /// Begins dragging an existing item from the given cell.
    public func beginMove(item: Item, at cell: GridCell) {
        guard !isLocked(at: cell) else { return }
        let offset = GridCell(cell.r - item.anchorRow, c: cell.c - item.anchorCol)
        interaction = .moving(item: item, anchor: cell, grabOffset: offset)
    }

    /// Updates the dragged item's anchor as the finger moves.
    public func updateMove(to cell: GridCell) {
        guard case .moving(let item, _, let grab) = interaction else { return }
        let anchor = GridCell(cell.r - grab.r, c: cell.c - grab.c)
        interaction = .moving(item: item, anchor: anchor, grabOffset: grab)
    }

    /// Commits the move if the target position is valid; otherwise reverts.
    public func commitMove() {
        guard case .moving(let item, let anchor, _) = interaction,
              let t = item.itemType else { interaction = .idle; return }
        if canPlace(anchor: anchor, type: t, rotated: item.rotated, excluding: item) {
            item.anchorRow = anchor.r
            item.anchorCol = anchor.c
        }
        interaction = .idle
    }

    /// Cancels any ongoing interaction (preview or move).
    public func cancelInteraction() { interaction = .idle }

    // MARK: - Statistics

    public var usedCells:  Int    { map.count }
    public var totalCells: Int    { rows * cols }
    public var freeCells:  Int    { totalCells - usedCells }
    public var fillPct:    Double { totalCells > 0 ? Double(usedCells) / Double(totalCells) : 0 }

    // MARK: - Preview

    /// The cells that should be highlighted for the current preview / move.
    public var previewCells: Set<GridCell> {
        switch interaction {
        case .idle: return []
        case .previewing(let anchor):
            guard let t = selectedType else { return [] }
            return Set(footprint(anchor: anchor, type: t, rotated: rotated))
        case .moving(let item, let anchor, _):
            guard let t = item.itemType else { return [] }
            return Set(footprint(anchor: anchor, type: t, rotated: item.rotated))
        }
    }

    /// Whether the current preview position is a valid placement.
    public var isPreviewValid: Bool {
        switch interaction {
        case .idle: return false
        case .previewing(let anchor):
            guard let t = selectedType else { return false }
            return canPlace(anchor: anchor, type: t, rotated: rotated)
        case .moving(let item, let anchor, _):
            guard let t = item.itemType else { return false }
            return canPlace(anchor: anchor, type: t, rotated: item.rotated, excluding: item)
        }
    }

    /// The item currently being moved, if any.
    public var movingItem: Item? {
        if case .moving(let item, _, _) = interaction { return item }
        return nil
    }
}
