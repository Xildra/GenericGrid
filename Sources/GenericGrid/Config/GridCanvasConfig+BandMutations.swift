//
//  GridCanvasConfig+BandMutations.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Mutating helpers for editing 2D compartments (splitting, merging,
//  resizing, relabelling). Kept on the model so every editor shares
//  the same rules and the view layer stays thin. Each helper keeps
//  zones attached to the band whose row/col range contains the zone's
//  `(rowStart, colStart)`.
//

import Foundation

extension GridCanvasConfig {

    // MARK: - Promotion

    /// Ensure `columnBands` is populated so edits persist. If nil, seeds
    /// with a single full-grid band wrapping the current `colLabels`. The
    /// seed reuses `fallbackBandID` so any identifier captured from the
    /// synthetic fallback (e.g. `editingBandID`) keeps matching.
    public mutating func promoteToColumnBandsIfNeeded() {
        guard columnBands == nil else { return }
        columnBands = [ColumnBand(id: Self.fallbackBandID,
                                  rowStart: 0,
                                  rowEnd: max(0, rows - 1),
                                  colStart: 0,
                                  colEnd: max(0, cols - 1),
                                  labels: colLabels,
                                  zones: [])]
    }

    // MARK: - Splits

    /// Splits the band containing `row` horizontally — the existing band
    /// keeps the rows above, a new band starts at `row`. Acts on the
    /// first band whose row range contains `row` (the leftmost one when
    /// several bands share that row range). No-op if `row` is out of
    /// range, or already on the target band's top edge.
    public mutating func splitBand(at row: Int) {
        guard row > 0, row < rows else { return }
        promoteToColumnBandsIfNeeded()
        guard let bands = columnBands,
              let target = bands.first(where: { $0.contains(row: row) }) else { return }
        splitBand(id: target.id, atRow: row)
    }

    /// Horizontal split: the band with the given id is split into two
    /// stacked vertically at `row`. Zones in the target band are
    /// redistributed to the side containing their `rowStart`. No-op if
    /// the row is out of the band or coincides with its top edge.
    public mutating func splitBand(id: UUID, atRow row: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }) else { return }
        let target = bands[idx]
        guard row > target.rowStart, row <= target.rowEnd else { return }

        let upperZones = target.zones.filter { Int($0.rowStart.rounded(.down)) < row }
        let lowerZones = target.zones.filter { Int($0.rowStart.rounded(.down)) >= row }

        let upper = ColumnBand(id: target.id,
                               rowStart: target.rowStart,
                               rowEnd: row - 1,
                               colStart: target.colStart,
                               colEnd: target.colEnd,
                               labels: target.labels,
                               cols: target.cols,
                               zones: upperZones)
        let lower = ColumnBand(rowStart: row,
                               rowEnd: target.rowEnd,
                               colStart: target.colStart,
                               colEnd: target.colEnd,
                               labels: nil,
                               cols: target.cols,
                               zones: lowerZones)
        bands.replaceSubrange(idx...idx, with: [upper, lower])
        columnBands = bands
    }

    /// Vertical split: the band with the given id is split into two
    /// side by side at `col`. Zones in the target band are redistributed
    /// to the side containing their `colStart`. No-op if the column is
    /// out of the band or coincides with its left edge.
    public mutating func splitBand(id: UUID, atCol col: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }) else { return }
        let target = bands[idx]
        guard col > target.colStart, col <= target.colEnd else { return }

        // Subdivision count overrides don't survive a vertical split:
        // each side inherits its own natural width unless explicitly
        // re-configured later.
        let leftWidth = col - target.colStart
        let rightWidth = target.colEnd - col + 1
        let leftLabels = target.labels.map { Array($0.prefix(leftWidth)) }
        let rightLabels = target.labels.flatMap { lbls -> [String]? in
            guard lbls.count > leftWidth else { return nil }
            return Array(lbls.dropFirst(leftWidth).prefix(rightWidth))
        }

        let leftZones = target.zones.filter { Int($0.colStart.rounded(.down)) + target.colStart < col }
        let rightZones = target.zones.filter { Int($0.colStart.rounded(.down)) + target.colStart >= col }

        let left = ColumnBand(id: target.id,
                              rowStart: target.rowStart,
                              rowEnd: target.rowEnd,
                              colStart: target.colStart,
                              colEnd: col - 1,
                              labels: leftLabels,
                              cols: nil,
                              zones: leftZones)
        let right = ColumnBand(rowStart: target.rowStart,
                               rowEnd: target.rowEnd,
                               colStart: col,
                               colEnd: target.colEnd,
                               labels: rightLabels,
                               cols: nil,
                               zones: rightZones)
        bands.replaceSubrange(idx...idx, with: [left, right])
        columnBands = bands
    }

    // MARK: - Merge

    /// Removes the band with the given id by merging it into a neighbour
    /// that shares one of its full edges. Tries top, then bottom, then
    /// left, then right. No-op if no neighbour shares a full edge or if
    /// only one band remains.
    public mutating func mergeBand(id: UUID) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands, bands.count > 1,
              let idx = bands.firstIndex(where: { $0.id == id }) else { return }
        let target = bands[idx]

        if let nIdx = bands.firstIndex(where: {
            $0.id != target.id &&
            $0.rowEnd + 1 == target.rowStart &&
            $0.colStart == target.colStart && $0.colEnd == target.colEnd
        }) {
            bands[nIdx].rowEnd = target.rowEnd
            bands[nIdx].zones.append(contentsOf: target.zones)
            bands.remove(at: idx > nIdx ? idx : idx)
            columnBands = bands
            return
        }
        if let nIdx = bands.firstIndex(where: {
            $0.id != target.id &&
            target.rowEnd + 1 == $0.rowStart &&
            $0.colStart == target.colStart && $0.colEnd == target.colEnd
        }) {
            bands[nIdx].rowStart = target.rowStart
            bands[nIdx].zones.insert(contentsOf: target.zones, at: 0)
            bands.remove(at: idx > nIdx ? idx : idx)
            columnBands = bands
            return
        }
        if let nIdx = bands.firstIndex(where: {
            $0.id != target.id &&
            $0.colEnd + 1 == target.colStart &&
            $0.rowStart == target.rowStart && $0.rowEnd == target.rowEnd
        }) {
            bands[nIdx].colEnd = target.colEnd
            bands[nIdx].zones.append(contentsOf: target.zones)
            bands[nIdx].cols = nil
            bands.remove(at: idx > nIdx ? idx : idx)
            columnBands = bands
            return
        }
        if let nIdx = bands.firstIndex(where: {
            $0.id != target.id &&
            target.colEnd + 1 == $0.colStart &&
            $0.rowStart == target.rowStart && $0.rowEnd == target.rowEnd
        }) {
            bands[nIdx].colStart = target.colStart
            bands[nIdx].zones.insert(contentsOf: target.zones, at: 0)
            bands[nIdx].cols = nil
            bands.remove(at: idx > nIdx ? idx : idx)
            columnBands = bands
            return
        }
    }

    /// Convenience: merges the bands at the given offsets (in order) by
    /// trying to fold each into a full-edge neighbour. Bands that can't
    /// be merged cleanly are left alone.
    public mutating func mergeBands(at offsets: IndexSet) {
        let bands = effectiveBands
        let targets = offsets.sorted(by: >).compactMap { offset -> UUID? in
            guard bands.indices.contains(offset) else { return nil }
            return bands[offset].id
        }
        for id in targets { mergeBand(id: id) }
    }

    // MARK: - Row boundary moves

    /// `true` when the band's top edge is shared as a single full edge
    /// with exactly one neighbouring band — the only case where moving
    /// the top boundary keeps the tiling well-defined.
    public func canResizeRowStart(bandID: UUID) -> Bool {
        topNeighbour(bandID: bandID) != nil
    }

    /// `true` when the band's bottom edge is shared as a single full
    /// edge with exactly one neighbouring band.
    public func canResizeRowEnd(bandID: UUID) -> Bool {
        bottomNeighbour(bandID: bandID) != nil
    }

    /// Moves the top edge of the band to `newStart`. The top neighbour
    /// is shrunk/grown accordingly. No-op when the band has no single
    /// top neighbour sharing a full edge, or when the value would leave
    /// either side with no rows.
    public mutating func setBandRowStart(id: UUID, newStart: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }),
              let topIdx = topNeighbour(bandID: id, in: bands) else { return }
        let prev = bands[topIdx]
        let target = bands[idx]
        guard newStart > prev.rowStart, newStart <= target.rowEnd else { return }
        bands[topIdx].rowEnd = newStart - 1
        bands[idx].rowStart = newStart
        rebalanceZones(between: topIdx, and: idx, in: &bands)
        columnBands = bands
    }

    /// Moves the bottom edge of the band to `newEnd`. The bottom
    /// neighbour is shrunk/grown accordingly.
    public mutating func setBandRowEnd(id: UUID, newEnd: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }),
              let botIdx = bottomNeighbour(bandID: id, in: bands) else { return }
        let target = bands[idx]
        let next = bands[botIdx]
        guard newEnd >= target.rowStart, newEnd < next.rowEnd else { return }
        bands[idx].rowEnd = newEnd
        bands[botIdx].rowStart = newEnd + 1
        rebalanceZones(between: idx, and: botIdx, in: &bands)
        columnBands = bands
    }

    // MARK: - Column boundary moves

    /// `true` when the band's left edge is shared as a single full edge
    /// with exactly one neighbouring band.
    public func canResizeColStart(bandID: UUID) -> Bool {
        leftNeighbour(bandID: bandID) != nil
    }

    /// `true` when the band's right edge is shared as a single full
    /// edge with exactly one neighbouring band.
    public func canResizeColEnd(bandID: UUID) -> Bool {
        rightNeighbour(bandID: bandID) != nil
    }

    /// Moves the left edge of the band to `newStart`. The left
    /// neighbour is shrunk/grown accordingly. Subdivision overrides on
    /// either side are cleared (the natural width changed).
    public mutating func setBandColStart(id: UUID, newStart: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }),
              let lefIdx = leftNeighbour(bandID: id, in: bands) else { return }
        let prev = bands[lefIdx]
        let target = bands[idx]
        guard newStart > prev.colStart, newStart <= target.colEnd else { return }
        bands[lefIdx].colEnd = newStart - 1
        bands[lefIdx].cols = nil
        bands[idx].colStart = newStart
        bands[idx].cols = nil
        rebalanceZones(between: lefIdx, and: idx, in: &bands)
        columnBands = bands
    }

    /// Moves the right edge of the band to `newEnd`. The right
    /// neighbour is shrunk/grown accordingly.
    public mutating func setBandColEnd(id: UUID, newEnd: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }),
              let rightIdx = rightNeighbour(bandID: id, in: bands) else { return }
        let target = bands[idx]
        let next = bands[rightIdx]
        guard newEnd >= target.colStart, newEnd < next.colEnd else { return }
        bands[idx].colEnd = newEnd
        bands[idx].cols = nil
        bands[rightIdx].colStart = newEnd + 1
        bands[rightIdx].cols = nil
        rebalanceZones(between: idx, and: rightIdx, in: &bands)
        columnBands = bands
    }

    // MARK: - Labels & subdivision

    /// Replaces the labels of the band with the given identifier.
    /// Pass `nil` to reset to the default A/B/C… fallback.
    public mutating func updateBandLabels(id: UUID, labels: [String]?) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }) else { return }
        bands[idx].labels = labels
        columnBands = bands
    }

    /// Overrides the subdivision count for the band with the given id.
    /// Pass `nil` to drop the override and use the band's natural width.
    /// Zones in the band are clamped to the new count and labels are
    /// trimmed if they would exceed it.
    public mutating func setBandCols(id: UUID, cols newCols: Int?) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.id == id }) else { return }
        let target = newCols.map { max(1, $0) }
        bands[idx].cols = target
        let effective = target ?? max(1, bands[idx].colCount)
        bands[idx].zones = bands[idx].zones.compactMap { zone in
            var z = zone
            if z.colStart >= Double(effective) { return nil }
            z.colEnd = min(z.colEnd, Double(effective))
            if z.colEnd <= z.colStart { return nil }
            return z
        }
        if let labels = bands[idx].labels, labels.count > effective {
            bands[idx].labels = Array(labels.prefix(effective))
        }
        columnBands = bands
    }

    // MARK: - Neighbour helpers

    private func topNeighbour(bandID: UUID) -> Int? {
        guard let bands = columnBands else { return nil }
        return topNeighbour(bandID: bandID, in: bands)
    }

    private func bottomNeighbour(bandID: UUID) -> Int? {
        guard let bands = columnBands else { return nil }
        return bottomNeighbour(bandID: bandID, in: bands)
    }

    private func leftNeighbour(bandID: UUID) -> Int? {
        guard let bands = columnBands else { return nil }
        return leftNeighbour(bandID: bandID, in: bands)
    }

    private func rightNeighbour(bandID: UUID) -> Int? {
        guard let bands = columnBands else { return nil }
        return rightNeighbour(bandID: bandID, in: bands)
    }

    /// Index of the unique band that touches the target's top edge
    /// along its full column range, or nil when no single such band
    /// exists.
    private func topNeighbour(bandID: UUID, in bands: [ColumnBand]) -> Int? {
        guard let target = bands.first(where: { $0.id == bandID }) else { return nil }
        let candidates = bands.indices.filter { i in
            bands[i].id != bandID &&
            bands[i].rowEnd + 1 == target.rowStart &&
            bands[i].colStart == target.colStart &&
            bands[i].colEnd == target.colEnd
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    private func bottomNeighbour(bandID: UUID, in bands: [ColumnBand]) -> Int? {
        guard let target = bands.first(where: { $0.id == bandID }) else { return nil }
        let candidates = bands.indices.filter { i in
            bands[i].id != bandID &&
            target.rowEnd + 1 == bands[i].rowStart &&
            bands[i].colStart == target.colStart &&
            bands[i].colEnd == target.colEnd
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    private func leftNeighbour(bandID: UUID, in bands: [ColumnBand]) -> Int? {
        guard let target = bands.first(where: { $0.id == bandID }) else { return nil }
        let candidates = bands.indices.filter { i in
            bands[i].id != bandID &&
            bands[i].colEnd + 1 == target.colStart &&
            bands[i].rowStart == target.rowStart &&
            bands[i].rowEnd == target.rowEnd
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    private func rightNeighbour(bandID: UUID, in bands: [ColumnBand]) -> Int? {
        guard let target = bands.first(where: { $0.id == bandID }) else { return nil }
        let candidates = bands.indices.filter { i in
            bands[i].id != bandID &&
            target.colEnd + 1 == bands[i].colStart &&
            bands[i].rowStart == target.rowStart &&
            bands[i].rowEnd == target.rowEnd
        }
        return candidates.count == 1 ? candidates[0] : nil
    }

    /// Moves zones between two bands so each zone lives in the band
    /// that currently owns its `(rowStart, colStart)`. Called after a
    /// boundary move to preserve the invariant.
    private func rebalanceZones(between a: Int, and b: Int,
                                in bands: inout [ColumnBand]) {
        let bandA = bands[a]
        let bandB = bands[b]
        var zonesA = bandA.zones
        var zonesB = bandB.zones

        let fromA = zonesA.filter { !bandA.contains(row: Int($0.rowStart.rounded(.down)),
                                                   col: Int($0.colStart.rounded(.down)) + bandA.colStart) }
        zonesA.removeAll { zone in fromA.contains(where: { $0.id == zone.id }) }

        let fromB = zonesB.filter { !bandB.contains(row: Int($0.rowStart.rounded(.down)),
                                                   col: Int($0.colStart.rounded(.down)) + bandB.colStart) }
        zonesB.removeAll { zone in fromB.contains(where: { $0.id == zone.id }) }

        zonesA.append(contentsOf: fromB)
        zonesB.append(contentsOf: fromA)

        bands[a].zones = zonesA
        bands[b].zones = zonesB
    }
}
