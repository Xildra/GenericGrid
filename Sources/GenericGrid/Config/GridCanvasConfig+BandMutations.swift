//
//  GridCanvasConfig+BandMutations.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Mutating helpers for editing compartments (splitting, merging,
//  relabelling, resizing). Kept on the model so every editor shares
//  the same rules and the view layer stays thin. Each helper keeps
//  zones attached to the compartment that owns their starting row.
//

import Foundation

extension GridCanvasConfig {

    /// Ensure `columnBands` is populated so edits persist. If nil, seeds
    /// with a single band wrapping the current `colLabels`. The seed
    /// reuses `fallbackBandID` so any identifier captured from the
    /// synthetic fallback (e.g. `editingBandID`) keeps matching.
    public mutating func promoteToColumnBandsIfNeeded() {
        guard columnBands == nil else { return }
        columnBands = [ColumnBand(id: Self.fallbackBandID,
                                  rowStart: 0,
                                  rowEnd: max(0, rows - 1),
                                  labels: colLabels,
                                  zones: [])]
    }

    /// Splits the band containing `row` in two, with the new compartment
    /// starting at `row`. Zones in the target band are redistributed to
    /// the side containing their `rowStart`. No-op if `row` is out of
    /// range or already lies on a band boundary.
    public mutating func splitBand(at row: Int) {
        guard row > 0, row < rows else { return }
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.contains(row: row) }) else { return }
        let target = bands[idx]
        guard row > target.rowStart else { return }

        let upperZones = target.zones.filter { Int($0.rowStart.rounded(.down)) < row }
        let lowerZones = target.zones.filter { Int($0.rowStart.rounded(.down)) >= row }

        let upper = ColumnBand(id: target.id,
                               rowStart: target.rowStart,
                               rowEnd: row - 1,
                               labels: target.labels,
                               zones: upperZones)
        let lower = ColumnBand(rowStart: row,
                               rowEnd: target.rowEnd,
                               labels: nil,
                               zones: lowerZones)
        bands.replaceSubrange(idx...idx, with: [upper, lower])
        columnBands = bands
    }

    /// Merges the bands at the given offsets into their neighbour, keeping
    /// the grid fully covered. Zones are preserved and appended to the
    /// surviving neighbour. No-op if only one band remains.
    public mutating func mergeBands(at offsets: IndexSet) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands, bands.count > 1 else { return }
        for i in offsets.sorted(by: >) {
            guard bands.indices.contains(i), bands.count > 1 else { continue }
            if i == 0 {
                let removed = bands.remove(at: 0)
                bands[0].rowStart = removed.rowStart
                bands[0].zones.insert(contentsOf: removed.zones, at: 0)
            } else {
                let removed = bands.remove(at: i)
                bands[i - 1].rowEnd = removed.rowEnd
                bands[i - 1].zones.append(contentsOf: removed.zones)
            }
        }
        columnBands = bands
    }

    /// Moves the boundary shared with the previous band so that the
    /// band at `index` now starts at `newStart`. The predecessor is
    /// shrunk/grown accordingly to keep the grid contiguous. Zones
    /// whose `rowStart` now falls in a different band are migrated
    /// across. No-op for the first band or when the value would leave
    /// either side with no rows.
    public mutating func setBandStart(at index: Int, rowStart newStart: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              index > 0, index < bands.count else { return }
        let prevStart = bands[index - 1].rowStart
        let thisEnd = bands[index].rowEnd
        guard newStart > prevStart, newStart <= thisEnd else { return }
        bands[index - 1].rowEnd = newStart - 1
        bands[index].rowStart = newStart
        rebalanceZones(between: index - 1, and: index, in: &bands)
        columnBands = bands
    }

    /// Moves the boundary shared with the next band so that the band
    /// at `index` now ends at `newEnd`. The successor is shrunk/grown
    /// accordingly. Zones whose `rowStart` now falls in a different
    /// band are migrated across. No-op for the last band or when the
    /// value would leave either side with no rows.
    public mutating func setBandEnd(at index: Int, rowEnd newEnd: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              index >= 0, index < bands.count - 1 else { return }
        let thisStart = bands[index].rowStart
        let nextEnd = bands[index + 1].rowEnd
        guard newEnd >= thisStart, newEnd < nextEnd else { return }
        bands[index].rowEnd = newEnd
        bands[index + 1].rowStart = newEnd + 1
        rebalanceZones(between: index, and: index + 1, in: &bands)
        columnBands = bands
    }

    /// Replaces the labels of the band with the given identifier.
    /// Pass `nil` to reset to the default A/B/C… fallback.
    public mutating func updateBandLabels(id: UUID, labels: [String]?) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }) else { return }
        bands[idx].labels = labels
        columnBands = bands
    }

    /// Moves zones between two adjacent bands so each zone lives in
    /// the band that currently owns its `rowStart`. Called after a
    /// boundary move to preserve the invariant.
    private func rebalanceZones(between a: Int, and b: Int,
                                in bands: inout [ColumnBand]) {
        let bandA = bands[a]
        let bandB = bands[b]
        var zonesA = bandA.zones
        var zonesB = bandB.zones

        let fromA = zonesA.filter { !bandA.contains(row: Int($0.rowStart.rounded(.down))) }
        zonesA.removeAll { zone in fromA.contains(where: { $0.id == zone.id }) }

        let fromB = zonesB.filter { !bandB.contains(row: Int($0.rowStart.rounded(.down))) }
        zonesB.removeAll { zone in fromB.contains(where: { $0.id == zone.id }) }

        zonesA.append(contentsOf: fromB)
        zonesB.append(contentsOf: fromA)

        bands[a].zones = zonesA
        bands[b].zones = zonesB
    }
}
