//
//  GridEngine+Slots.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Placement for grids built on fixed slots (`GridSlot`): assigning and
//  freeing an occupant, in place of the insert / delete cycle a plain
//  `GridPlaceable` goes through. Nothing is created or destroyed here —
//  the caller's storage only ever sees a change of occupant — so these
//  two operations replace both the `onInsert` and the deletion paths.
//

import Foundation

@available(iOS 17.0, macOS 14.0, *)
public extension GridEngine where Item: GridSlot {

    /// The slot currently occupied by `type`, if any.
    ///
    /// Resolved from the occupancy map, so it only sees slots the engine
    /// has been synced with. A caller holding a more authoritative link
    /// (an inverse relationship in its own store, say) can pass the
    /// previous slot to `free` itself before assigning.
    func slot(occupiedBy type: Item.ItemType) -> Item? {
        for slot in map.values where slot.itemType?.id == type.id { return slot }
        return nil
    }

    /// Fills `slot` with `type`, emptying the slot it occupied before.
    ///
    /// This is the slot equivalent of a placement: one item can only sit
    /// in one slot, so assigning it elsewhere frees the previous one —
    /// which is why `uniqueTypes` should stay off on a slot grid. The
    /// engine's map is updated immediately, so a rapid second tap can't
    /// double-place before the next `sync`.
    func assign(_ type: Item.ItemType, to slot: Item, rotated: Bool = false) {
        if let previous = self.slot(occupiedBy: type), previous !== slot {
            unregisterImmediate(previous)
            previous.occupant = nil
        }
        slot.rotated = rotated
        slot.occupant = type
        registerImmediate(slot)
    }

    /// Empties `slot`. The slot itself stays on the grid — it belongs to
    /// the configuration, not to whoever occupied it.
    func free(_ slot: Item) {
        unregisterImmediate(slot)
        slot.occupant = nil
    }
}
