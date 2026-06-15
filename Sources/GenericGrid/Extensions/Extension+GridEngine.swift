//
//
//  Extension+GridEngine.swift
//  GenericGrid
//
//  Copyright 2026 - All rights reserved
//  ESIOC 62.430 - Armée de l'Air et de l'Espace
//
    
import Foundation

// MARK: - Validation
extension GridEngine {
	/// Returns `true` if an item of the given type can be placed at the anchor,
	/// respecting bounds, occupancy, and zone rules.
	public func canPlace(anchor: GridCell, type: Item.ItemType, rotated: Bool,
						 excluding: Item? = nil) -> Bool {
		let cells = footprint(anchor: anchor, type: type, rotated: rotated)
		return fitsBoundsAndZones(cells: cells, typeName: type.name) &&
		cells.allSatisfy { map[$0] == nil || map[$0] === excluding }
	}
	
	/// `true` when every sub-cell is inside the grid and accepted by
	/// the zone rules — everything `canPlace` checks except occupancy.
	private func fitsBoundsAndZones(cells: [GridCell], typeName: String?) -> Bool {
		let rowsD = Double(rows), colsD = Double(cols)
		return cells.allSatisfy { cell in
			cell.r >= 0 && cell.r + GridGesture.halfCell <= rowsD &&
			cell.c >= 0 && cell.c + GridGesture.halfCell <= colsD &&
			config.canAccept(cell: cell, typeName: typeName)
		}
	}
	
	/// Returns `true` if the cell is inside a locked zone.
	public func isLocked(at cell: GridCell) -> Bool {
		guard let z = config.zone(at: cell) else { return false }
		return z.rule == .locked
	}
}

// MARK: - Placement (delegated via callbacks, SwiftData-agnostic)
extension GridEngine {
	public typealias InsertHandler = (Item.ItemType, Double, Double, Bool) -> Void
	public typealias ConflictHandler = (GridCell, Item) -> Void
	

	
	/// Attempts to place the currently selected type at the given anchor.
	/// Calls `insert` on success, or `onConflict` when the target cells are occupied.
	/// When `uniqueTypes` is true and the type is already placed, the
	/// existing item is moved instead of inserting a duplicate.
	public func place(at anchor: GridCell, insert: InsertHandler,
					  onConflict: ConflictHandler? = nil) {
		guard let t = selectedType else { return }
		
		// Unique-types fast path: relocate the existing item. The
		// engine's current `rotated` flag drives both the validation
		// and the assignment, so the footprint that lands is exactly
		// the one that was checked.
		if uniqueTypes, let existing = firstItem(matching: t) {
			guard canPlace(anchor: anchor, type: t,
						   rotated: rotated, excluding: existing) else {
				if let onConflict,
				   let occupant = footprint(anchor: anchor, type: t, rotated: rotated)
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
		guard fitsBoundsAndZones(cells: cells, typeName: t.name) else { return }
		
		if let occupant = cells.compactMap({ map[$0] }).first {
			onConflict?(anchor, occupant)
			// Occupied and no onConflict handler → silent no-op.
		} else {
			insert(t, anchor.r, anchor.c, rotated)
		}
	}
	
	/// First placed item whose type matches the given one (by `id`).
	/// Used by `uniqueTypes` placement to find an item to move.
	private func firstItem(matching type: Item.ItemType) -> Item? {
		for item in map.values where item.itemType?.id == type.id {
			return item
		}
		return nil
	}
}

// MARK: - Cell locking (runtime toggle)
extension GridEngine {
	/// Outcome of a `toggleLocked` call. Returned so the caller can
	/// persist the change to its own storage (SwiftData, file…).
	/// The cell carries whole-cell coordinates (anchorRow / anchorCol).
	public enum LockToggleResult: Sendable, Equatable {
		case noChange
		case locked(GridCell)
		case unlocked(GridCell)
	}
	
	/// Toggles a 1×1 `.locked` zone on the whole cell containing `cell`.
	/// Used by the operational grid to let the end-user mark individual
	/// cells as unavailable with a simple tap when no type is selected.
	///
	/// The toggle only activates on cells covered by a `.free` zone —
	/// cells outside any zone, or inside a `.locked` / `.forbidden` /
	/// `.restricted` zone, are left untouched. Toggling on a previously
	/// tap-locked cell removes the lock and restores the underlying
	/// `.free` zone.
	///
	/// Returns `.locked` / `.unlocked` with the whole-cell anchor when
	/// the config was mutated, `.noChange` otherwise.
	@discardableResult
	public func toggleLocked(at cell: GridCell) -> LockToggleResult {
		let row = Int(cell.r.rounded(.down))
		let col = Int(cell.c.rounded(.down))
		guard row >= 0, row < rows, col >= 0 else { return .noChange }
		let band = config.band(forRow: row, atCol: Double(col))
		guard col < band.colStart + config.cols(for: band) else { return .noChange }
		
		let subCells: [GridCell] = [
			GridCell(Double(row), c: Double(col)),
			GridCell(Double(row), c: Double(col) + GridGesture.halfCell),
			GridCell(Double(row) + GridGesture.halfCell, c: Double(col)),
			GridCell(Double(row) + GridGesture.halfCell, c: Double(col) + GridGesture.halfCell),
		]
		guard !subCells.contains(where: { map[$0] != nil }) else { return .noChange }
		
		let anchor = GridCell(Double(row), c: Double(col))
		
		if let existing = config.zones.first(where: {
			$0.rule == .locked &&
			$0.rowStart == Double(row) && $0.rowEnd == Double(row + 1) &&
			$0.colStart == Double(col) && $0.colEnd == Double(col + 1)
		}) {
			config.removeZone(id: existing.id)
			return .unlocked(anchor)
		}
		
		guard let z = config.zone(at: anchor), z.rule == .free else { return .noChange }
		
		let zone = GridZoneDefinition(
			label: lockLabel,
			rule: .locked,
			rowStart: Double(row),
			rowEnd: Double(row + 1),
			colStart: Double(col),
			colEnd: Double(col + 1),
			color: .gray
		)
		config.addZone(zone, prepend: true)
		return .locked(anchor)
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
	
}

// MARK: - Move (drag & drop)
extension GridEngine {
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
}

// MARK: - Statistics
extension GridEngine {
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
	/// Overlapping blocking zones are counted once. Cells and zones
	/// share the absolute coordinate space, offset by the band's
	/// `colStart` for subdivision columns.
	private func blockedWholeCells(in band: ColumnBand) -> Int {
		let blockers = band.zones.filter { $0.rule == .locked || $0.rule == .forbidden }
		guard !blockers.isEmpty else { return 0 }
		let bandCols = band.effectiveCols(default: config.cols)
		var count = 0
		for r in band.rowStart...band.rowEnd {
			let rd = Double(r)
			for c in 0..<bandCols {
				let cd = Double(band.colStart + c)
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
	
	public var totalZones: Int {
		config.zones.count
	}

	public var freeZones: Int {
		zoneCountByRule(.free)
	}
	
	public func zoneCountByRule(_ rule: ZoneRule) -> Int {
		config.zones.count(where: { $0.rule == rule })
	}
}

// MARK: - Preview
extension GridEngine {
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
