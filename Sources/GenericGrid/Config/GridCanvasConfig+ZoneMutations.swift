//
//  GridCanvasConfig+ZoneMutations.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Add / update / remove helpers for zones. Zones are owned by the
//  compartment that the editor (or last update) placed them in; the
//  helpers preserve that ownership across updates. Use the
//  `toBandID:` overload of `addZone` when several compartments share
//  a row range (vertical splits) so the new zone lands in the band
//  the user actually picked.
//

import Foundation

extension GridCanvasConfig {

    /// Inserts a zone into the compartment containing its `rowStart`.
    /// With vertical splits several bands may share that row range —
    /// in which case the first matching band wins. Use the
    /// `toBandID:` overload when the target band is known.
    ///
    /// Pass `prepend: true` to insert the zone at the front of its band's
    /// zone list. Used when a zone must win the first-match lookup of
    /// `zone(at:)` against an existing overlapping zone (e.g. a runtime
    /// lock dropped on top of a `.free` zone).
    public mutating func addZone(_ zone: GridZoneDefinition, prepend: Bool = false) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands, !bands.isEmpty else { return }
        let idx = bandIndex(forRow: Int(zone.rowStart.rounded(.down)))
        if prepend {
            bands[idx].zones.insert(zone, at: 0)
        } else {
            bands[idx].zones.append(zone)
        }
        columnBands = bands
    }

    /// Inserts a zone into the band with the given identifier. Use this
    /// when the target band is known (e.g. the user picked "Add zone"
    /// on a specific compartment in the sidebar) so vertical splits
    /// land the zone in the right column range.
    public mutating func addZone(_ zone: GridZoneDefinition,
                                 toBandID id: UUID,
                                 prepend: Bool = false) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }) else {
            addZone(zone, prepend: prepend)
            return
        }
        if prepend {
            bands[idx].zones.insert(zone, at: 0)
        } else {
            bands[idx].zones.append(zone)
        }
        columnBands = bands
    }

    /// Replaces an existing zone by id, keeping it in its current
    /// owning compartment. Used by editors that load a zone from a
    /// band and save changes back into the same band.
    public mutating func updateZone(_ zone: GridZoneDefinition) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands else { return }
        for b in bands.indices {
            if let localIdx = bands[b].zones.firstIndex(where: { $0.id == zone.id }) {
                bands[b].zones[localIdx] = zone
                columnBands = bands
                return
            }
        }
        // Not found → treat as insert to stay idempotent.
        let idx = bandIndex(forRow: Int(zone.rowStart.rounded(.down)))
        bands[idx].zones.append(zone)
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
