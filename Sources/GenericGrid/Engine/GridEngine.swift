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
	
	// MARK: - Computed properties
	
	/// When `true`, placing a type that already has an item on the grid
	/// **moves** that item to the new anchor instead of calling `insert`.
	/// Suited to "one model = one slot" apps (e.g. one passenger = one
	/// seat). Default `false` for backward compatibility — multi-instance
	/// types stay supported.
	public var uniqueTypes: Bool = false

	/// When `true`, a placement cell that falls inside a zone is snapped to
	/// that zone's origin (top-left). An item can then be tapped or dropped
	/// anywhere in the zone and still land on it. Generic — pairs naturally
	/// with one-item-per-zone setups. Default `false`.
	public var snapsToZoneOrigin: Bool = false


	/// Label given to the 1×1 zones created by `toggleLocked`.
	/// Override to localise or rename runtime locks.
	public var lockLabel: String = "Locked"

	/// Optional app-supplied placement rule, consulted by `canPlace` on top
	/// of the built-in bounds / zone-acceptance / occupancy checks. The
	/// engine stays domain-agnostic — it has no idea what the rule means;
	/// the app decides. Return `true` to allow, `false` to reject.
	/// `nil` (default) means no extra constraint.
	///
	/// - Parameters:
	///   - anchor: candidate (snapped) anchor for the placement.
	///   - cells: half-cell footprint the item would occupy.
	///   - excluding: item to ignore — set when relocating an existing item.
	public var placementRule: ((_ anchor: GridCell, _ cells: [GridCell], _ excluding: Item?) -> Bool)?
	
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

    /// Resolves a raw placement cell to the anchor actually used: the
    /// containing zone's origin when `snapsToZoneOrigin` is on, otherwise the
    /// cell unchanged.
    public func zoneAnchor(for cell: GridCell) -> GridCell {
        guard snapsToZoneOrigin, let zone = config.zone(at: cell) else { return cell }
        return GridCell(zone.rowStart, c: zone.colStart)
    }
}
