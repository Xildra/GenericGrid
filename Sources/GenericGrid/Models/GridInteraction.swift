//
//  GridInteraction.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  State machine representing the current user interaction
//  with the grid: idle, previewing a placement, or moving an item.
//

import Foundation

@available(iOS 17.0, macOS 14.0, *)
public enum GridInteraction<Item: GridPlaceable> {
    /// No interaction in progress.
    case idle
    /// The user is hovering / previewing a new placement at the given anchor.
    case previewing(anchor: GridCell)
    /// The user is dragging an existing item to a new position.
    case moving(item: Item, anchor: GridCell, grabOffset: GridCell)
}
