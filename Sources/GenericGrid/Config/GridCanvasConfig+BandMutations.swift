//
//  GridCanvasConfig+BandMutations.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Mutating helpers for editing compartments (splitting, merging,
//  relabelling). Kept on the model so every editor shares the same
//  rules and the view layer stays thin.
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
                                  labels: colLabels)]
    }

    /// Splits the band containing `row` in two, with the new compartment
    /// starting at `row`. No-op if `row` is out of range or already
    /// lies on a band boundary.
    public mutating func splitBand(at row: Int) {
        guard row > 0, row < rows else { return }
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands,
              let idx = bands.firstIndex(where: { $0.contains(row: row) }) else { return }
        let target = bands[idx]
        guard row > target.rowStart else { return }
        let upper = ColumnBand(id: target.id,
                               rowStart: target.rowStart,
                               rowEnd: row - 1,
                               labels: target.labels)
        let lower = ColumnBand(rowStart: row,
                               rowEnd: target.rowEnd,
                               labels: nil)
        bands.replaceSubrange(idx...idx, with: [upper, lower])
        columnBands = bands
    }

    /// Merges the bands at the given offsets into their neighbour, keeping
    /// the grid fully covered. No-op if only one band remains.
    public mutating func mergeBands(at offsets: IndexSet) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands, bands.count > 1 else { return }
        for i in offsets.sorted(by: >) {
            guard bands.indices.contains(i), bands.count > 1 else { continue }
            if i == 0 {
                let removed = bands.remove(at: 0)
                bands[0].rowStart = removed.rowStart
            } else {
                let removed = bands.remove(at: i)
                bands[i - 1].rowEnd = removed.rowEnd
            }
        }
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
}
