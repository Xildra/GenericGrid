//
//  GridCanvasConfig+ZoneMutations.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Add / update / remove helpers for zones. Zones are owned by the
//  compartment containing their `rowStart`; these helpers keep that
//  invariant so callers never touch nested arrays directly.
//

import Foundation

extension GridCanvasConfig {

    /// Inserts a zone into the compartment containing its `rowStart`.
    /// Promotes the config to explicit compartments first so the zone
    /// always lands in a real band.
    public mutating func addZone(_ zone: GridZoneDefinition) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands, !bands.isEmpty else { return }
        let idx = bandIndex(forRow: Int(zone.rowStart.rounded(.down)))
        bands[idx].zones.append(zone)
        columnBands = bands
    }

    /// Replaces an existing zone by id. If the new `rowStart` has
    /// moved the zone into a different compartment, the zone is
    /// migrated across.
    public mutating func updateZone(_ zone: GridZoneDefinition) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands else { return }
        let targetIndex = bandIndex(forRow: Int(zone.rowStart.rounded(.down)))
        for b in bands.indices {
            if let localIdx = bands[b].zones.firstIndex(where: { $0.id == zone.id }) {
                if b == targetIndex {
                    bands[b].zones[localIdx] = zone
                } else {
                    bands[b].zones.remove(at: localIdx)
                    bands[targetIndex].zones.append(zone)
                }
                columnBands = bands
                return
            }
        }
        // Not found → treat as insert to stay idempotent.
        bands[targetIndex].zones.append(zone)
        columnBands = bands
    }

    /// Removes the zone with the given id, wherever it lives.
    public mutating func removeZone(id: UUID) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands else { return }
        for b in bands.indices {
            if let localIdx = bands[b].zones.firstIndex(where: { $0.id == id }) {
                bands[b].zones.remove(at: localIdx)
                columnBands = bands
                return
            }
        }
    }

    /// `true` when a zone with the given id is already stored in
    /// any compartment. Used by editors to distinguish new vs. edit.
    public func containsZone(id: UUID) -> Bool {
        effectiveBands.contains { band in
            band.zones.contains(where: { $0.id == id })
        }
    }
}
