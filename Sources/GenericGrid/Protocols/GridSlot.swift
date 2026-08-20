//
//  GridSlot.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  A placeable whose position is fixed and whose *occupant* changes.
//
//  A plain `GridPlaceable` is created for its item and carries it for
//  life: placing means inserting an object, removing means deleting it.
//  A slot works the other way round — it pre-exists its occupant. It is
//  derived from the configuration (a seat, a hold position…), sits at a
//  fixed anchor, and is filled or emptied by assigning `occupant`.
//
//  Slots therefore ignore anchor writes: `GridEngine.commitMove` and the
//  `uniqueTypes` relocation path both reposition an item by writing its
//  anchor, which a slot cannot honour. Conformers usually back
//  `anchorRow` / `anchorCol` with stored coordinates and no-op setters,
//  and rely on `assign(_:to:)` for every change of occupant.
//

import Foundation

@available(iOS 17.0, macOS 14.0, *)
public protocol GridSlot: GridPlaceable {
    /// The item currently occupying the slot, `nil` when free.
    ///
    /// Prefer `GridEngine.assign(_:to:)` and `GridEngine.free(_:)` over
    /// writing this directly: they keep the occupancy map in step, so a
    /// rapid second placement can't land on a slot the engine still
    /// believes is empty.
    var occupant: ItemType? { get set }
}

@available(iOS 17.0, macOS 14.0, *)
public extension GridSlot {
    /// A slot's type is its occupant's — an empty slot has none, and so
    /// occupies no cell. Only occupied slots should be handed to
    /// `GridEngine.sync`; passing the free ones would fill the occupancy
    /// map and reject every placement.
    var itemType: ItemType? { occupant }
}
