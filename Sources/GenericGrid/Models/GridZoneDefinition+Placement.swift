//
//  GridZoneDefinition+Placement.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Capacity and placement queries for a single zone: its maximum cell
//  count, whether a given footprint fits inside the zone box (with optional
//  90° rotation), and whether the zone's rule accepts a given item type.
//

import Foundation

public extension GridZoneDefinition {

    /// Maximum number of whole cells this zone can hold (`rowCount × colCount`).
    var capacity: Int { rowCount * colCount }

    /// Returns `true` if a `width`×`height` (whole-cell) footprint fits inside
    /// this zone's box, optionally allowing a 90° rotation.
    func fits(width: Int, height: Int, allowRotation: Bool = true) -> Bool {
        let direct = width  <= colCount && height <= rowCount
        let turned = allowRotation && height <= colCount && width <= rowCount
        return direct || turned
    }

    /// Returns `true` if this zone's rule accepts an item of the given type
    /// name. Geometry and occupancy are checked separately (`fits`,
    /// `GridEngine.isZoneEmpty`). Mirrors `GridCanvasConfig.canAccept`.
    func accepts(typeName: String?) -> Bool {
        switch rule {
        case .free:       return true
        case .locked:     return false
        case .forbidden:  return false
        case .restricted:
            guard let allowed = allowedTypeNames, let name = typeName else { return false }
            return allowed.contains(name)
        }
    }
}
