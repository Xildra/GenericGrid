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

    /// Computes the set of half-cell sub-cells that an item type would occupy at the
    /// given anchor. An item of size W×H produces (2W)×(2H) sub-cells of 0.5×0.5 each.
    public func footprint(anchor: GridCell, type: Item.ItemType, rotated: Bool) -> [GridCell] {
        let w = Double(rotated ? type.height : type.width)
        let h = Double(rotated ? type.width  : type.height)
        let endR = anchor.r + h
        let endC = anchor.c + w
        var result: [GridCell] = []
        var r = anchor.r
        while r < endR {
            var c = anchor.c
            while c < endC {
                result.append(GridCell(r, c: c))
                c += GridGesture.halfCell
            }
            r += GridGesture.halfCell
        }
        return result
    }

    // MARK: - Validation

    /// Returns `true` if an item of the given type can be placed at the anchor,
    /// respecting bounds, occupancy, and zone rules.
    public func canPlace(anchor: GridCell, type: Item.ItemType, rotated: Bool,
                         excluding: Item? = nil) -> Bool {
        let cells = footprint(anchor: anchor, type: type, rotated: rotated)
        let rowsD = Double(rows), colsD = Double(cols)
        return cells.allSatisfy { cell in
            cell.r >= 0 && cell.r + GridGesture.halfCell <= rowsD &&
            cell.c >= 0 && cell.c + GridGesture.halfCell <= colsD &&
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

    public typealias InsertHandler = (Item.ItemType, Double, Double, Bool) -> Void
    public typealias ConflictHandler = (GridCell, Item) -> Void

    /// When `true`, placing a type that already has an item on the grid
    /// **moves** that item to the new anchor instead of calling `insert`.
    /// Suited to "one model = one slot" apps (e.g. one passenger = one
    /// seat). Default `false` for backward compatibility — multi-instance
    /// types stay supported.
    public var uniqueTypes: Bool = false

    /// Attempts to place the currently selected type at the given anchor.
    /// Calls `insert` on success, or `onConflict` when the target cells are occupied.
    /// When `uniqueTypes` is true and the type is already placed, the
    /// existing item is moved instead of inserting a duplicate.
    public func place(at anchor: GridCell, insert: InsertHandler,
                      onConflict: ConflictHandler? = nil) {
        guard let t = selectedType else { return }

        // Unique-types fast path: relocate the existing item.
        if uniqueTypes, let existing = firstItem(matching: t) {
            guard canPlace(anchor: anchor, type: t,
                           rotated: existing.rotated, excluding: existing) else {
                if let onConflict,
                   let occupant = footprint(anchor: anchor, type: t, rotated: existing.rotated)
                       .compactMap({ map[$0] }).first(where: { $0 !== existing }) {
                    onConflict(anchor, occupant)
                }
                return
            }
            unregisterImmediate(existing)
            existing.anchorRow = anchor.r
            existing.anchorCol = anchor.c
            existing.rotated = rotated
            registerImmediate(existing)
            return
        }

        let cells = footprint(anchor: anchor, type: t, rotated: rotated)
        let rowsD = Double(rows), colsD = Double(cols)

        // Bounds check
        let inBounds = cells.allSatisfy {
            $0.r >= 0 && $0.r + GridGesture.halfCell <= rowsD && $0.c >= 0 && $0.c + GridGesture.halfCell <= colsD
        }
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

    /// First placed item whose type matches the given one (by `id`).
    /// Used by `uniqueTypes` placement to find an item to move.
    private func firstItem(matching type: Item.ItemType) -> Item? {
        for item in map.values where item.itemType?.id == type.id {
            return item
        }
        return nil
    }

    /// Replaces the given item at `cell` with the currently selected type.
    /// Removes `replacing` via the supplied delete callback, syncs the
    /// engine map, then runs the regular placement flow at the same
    /// anchor — so `uniqueTypes` is honoured (a previously-seated
    /// occurrence of the new type is **moved** rather than duplicated).
    /// Use from a confirmation alert handler triggered by `onConflict`.
    /// No-op (and no delete) when no type is selected.
    public func replace(_ replacing: Item, at cell: GridCell,
                        onDelete: (Item) -> Void,
                        insert: InsertHandler) {
        guard selectedType != nil else { return }
        onDelete(replacing)
        unregisterImmediate(replacing)
        place(at: cell, insert: insert)
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

    /// Whole-cell area occupied by placed items. Each item contributes
    /// `effectiveWidth × effectiveHeight`. Computed from distinct items
    /// because `map` keeps one entry per half-cell sub-cell.
    public var usedCells: Int {
        var seen = Set<ObjectIdentifier>()
        var total = 0
        for item in map.values where seen.insert(ObjectIdentifier(item)).inserted {
            total += max(1, item.effectiveWidth * item.effectiveHeight)
        }
        return total
    }

    /// Total **placeable** whole cells across every compartment.
    /// - Honours per-band column overrides.
    /// - Excludes cells that fall fully inside a `.locked` or
    ///   `.forbidden` zone (overlapping blocking zones are counted
    ///   once thanks to the de-dup loop).
    /// `.restricted` zones still count as placeable since they only
    /// filter which types can be placed there.
    public var totalCells: Int {
        config.effectiveBands.reduce(0) { sum, band in
            let bandCols = band.effectiveCols(default: config.cols)
            return sum + band.rowCount * bandCols - blockedWholeCells(in: band)
        }
    }

    public var freeCells: Int { max(0, totalCells - usedCells) }
    public var fillPct: Double {
        totalCells > 0 ? Double(usedCells) / Double(totalCells) : 0
    }

    /// Number of whole cells in the band that fall inside a `.locked`
    /// or `.forbidden` zone — i.e. cannot accept any placement.
    /// Overlapping blocking zones are counted once.
    private func blockedWholeCells(in band: ColumnBand) -> Int {
        let blockers = band.zones.filter { $0.rule == .locked || $0.rule == .forbidden }
        guard !blockers.isEmpty else { return 0 }
        let bandCols = band.effectiveCols(default: config.cols)
        var count = 0
        for r in band.rowStart...band.rowEnd {
            let rd = Double(r)
            for c in 0..<bandCols {
                let cd = Double(c)
                if blockers.contains(where: {
                    rd >= $0.rowStart && rd + 1 <= $0.rowEnd &&
                    cd >= $0.colStart && cd + 1 <= $0.colEnd
                }) {
                    count += 1
                }
            }
        }
        return count
    }

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

    /// `true` while the user is previewing a placement or moving an item.
    /// Used by the view layer to disable scrolling during direct manipulation.
    public var isInteracting: Bool {
        if case .idle = interaction { return false }
        return true
    }
}
