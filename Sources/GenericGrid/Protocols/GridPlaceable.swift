//
//  GridPlaceable.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Protocol for items that have been placed on the grid.
//  Provides anchor position (half-cell precision), rotation,
//  and computed sub-cell footprint used by the engine.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public protocol GridPlaceable: AnyObject, Identifiable, Observable {
    associatedtype ItemType: GridItemType
    var itemType: ItemType? { get }
    var anchorRow: Double { get set }
    var anchorCol: Double { get set }
    var rotated: Bool { get set }
}

@available(iOS 17.0, macOS 14.0, *)
public extension GridPlaceable {
    /// Width after applying rotation.
    var effectiveWidth: Int { rotated ? (itemType?.height ?? 1) : (itemType?.width ?? 1) }
    /// Height after applying rotation.
    var effectiveHeight: Int { rotated ? (itemType?.width ?? 1) : (itemType?.height ?? 1) }

    /// All half-cell sub-cells currently occupied by this item.
    /// An item of size W×H spans (2W)×(2H) sub-cells of 0.5×0.5 each.
    var cells: [GridCell] {
        let endR = anchorRow + Double(effectiveHeight)
        let endC = anchorCol + Double(effectiveWidth)
        var result: [GridCell] = []
        var r = anchorRow
        while r < endR {
            var c = anchorCol
            while c < endC {
                result.append(GridCell(r, c: c))
                c += GridGesture.halfCell
            }
            r += GridGesture.halfCell
        }
        return result
    }
}
