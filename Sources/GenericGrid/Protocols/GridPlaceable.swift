//
//  GridPlaceable.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Protocol for items that have been placed on the grid.
//  Provides anchor position, rotation, and computed cell footprint.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public protocol GridPlaceable: AnyObject, Identifiable, Observable {
    associatedtype ItemType: GridItemType
    var itemType: ItemType? { get }
    var anchorRow: Int { get set }
    var anchorCol: Int { get set }
    var rotated: Bool { get set }
}

@available(iOS 17.0, macOS 14.0, *)
public extension GridPlaceable {
    /// Width after applying rotation.
    var effectiveWidth: Int { rotated ? (itemType?.height ?? 1) : (itemType?.width ?? 1) }
    /// Height after applying rotation.
    var effectiveHeight: Int { rotated ? (itemType?.width ?? 1) : (itemType?.height ?? 1) }

    /// All grid cells currently occupied by this item.
    var cells: [GridCell] {
        (anchorRow ..< anchorRow + effectiveHeight).flatMap { r in
            (anchorCol ..< anchorCol + effectiveWidth).map { GridCell(r, c: $0) }
        }
    }
}
