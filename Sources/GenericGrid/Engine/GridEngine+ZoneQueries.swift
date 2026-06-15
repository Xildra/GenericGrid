//
//  GridEngine+ZoneQueries.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Zone-level queries layered on top of the occupancy map: total zone
//  count, emptiness / used-cell counts within a single zone, and the set of
//  zones that can host an item of a given size and type — used to highlight
//  valid drop targets during drag & drop.
//

import Foundation

@available(iOS 17.0, macOS 14.0, *)
public extension GridEngine {

    /// Total number of zones across all compartments.
    var zoneCount: Int { config.zones.count }

    /// `true` when no placed item occupies any cell of the given zone.
    /// Short-circuits on the first occupied sub-cell.
    func isZoneEmpty(_ zone: GridZoneDefinition) -> Bool {
        !map.keys.contains { zone.contains($0) }
    }

    /// Whole cells occupied by placed items inside the given zone
    /// (4 half-cell sub-cells of 0.5×0.5 = 1 whole cell).
    func usedCells(in zone: GridZoneDefinition) -> Int {
        var subCells = 0
        for cell in map.keys where zone.contains(cell) { subCells += 1 }
        return subCells / 4
    }

    /// Zones that can host a `width`×`height` item of the given type: the zone
    /// rule accepts the type, the zone is large enough (optionally after a 90°
    /// rotation), and it is still empty (1 palette = 1 zone).
    func zonesAccepting(width: Int, height: Int,
                        typeName: String? = nil,
                        allowRotation: Bool = true) -> [GridZoneDefinition] {
        config.zones.filter { zone in
            zone.accepts(typeName: typeName) &&
            zone.fits(width: width, height: height, allowRotation: allowRotation) &&
            isZoneEmpty(zone)
        }
    }
}
