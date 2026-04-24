//
//  GridCanvasConfig+Resize.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Mutating helpers for resizing the overall grid. Resizing must
//  keep compartments covering every row and zones inside the new
//  bounds — direct writes to `rows` / `cols` would otherwise leave
//  `columnBands` invalid and wipe the visible grid.
//

import Foundation

extension GridCanvasConfig {

    /// Updates the grid's row count while keeping compartments
    /// contiguous and clamping any zones that fall outside the new
    /// range. The last compartment is stretched or shrunk to reach
    /// the new end row; compartments that no longer fit are dropped.
    public mutating func setRows(_ newRows: Int) {
        let target = max(1, newRows)
        guard target != rows else { return }
        rows = target
        if let labels = rowLabels {
            rowLabels = Array(labels.prefix(target))
        }
        adjustBandsForDimensionChange()
    }

    /// Updates the grid's column count while clamping zones to the
    /// new horizontal range and trimming oversized band labels.
    public mutating func setCols(_ newCols: Int) {
        let target = max(1, newCols)
        guard target != cols else { return }
        cols = target
        if let labels = colLabels {
            colLabels = Array(labels.prefix(target))
        }
        adjustBandsForDimensionChange()
    }

    /// Re-anchors `columnBands` to the current `rows` and clamps zone
    /// rectangles to `rows` / `cols`. Zones whose start row/column has
    /// fallen outside the new bounds are dropped.
    private mutating func adjustBandsForDimensionChange() {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands else { return }

        bands.removeAll { $0.rowStart >= rows }

        if bands.isEmpty {
            bands = [ColumnBand(id: Self.fallbackBandID,
                                rowStart: 0,
                                rowEnd: max(0, rows - 1),
                                labels: colLabels,
                                zones: [])]
        } else {
            bands[bands.count - 1].rowEnd = rows - 1
        }

        for b in bands.indices {
            if let labels = bands[b].labels {
                bands[b].labels = Array(labels.prefix(cols))
            }
            bands[b].zones = bands[b].zones.compactMap { clampZone($0, band: bands[b]) }
        }

        columnBands = bands
    }

    /// Clamps a zone to the current grid and compartment bounds.
    /// Returns nil if the zone no longer fits.
    private func clampZone(_ zone: GridZoneDefinition,
                           band: ColumnBand) -> GridZoneDefinition? {
        var z = zone
        if z.rowStart >= Double(rows) || z.colStart >= Double(cols) { return nil }
        z.rowEnd = min(z.rowEnd, Double(rows))
        z.colEnd = min(z.colEnd, Double(cols))
        let bandMax = Double(band.rowEnd + 1)
        z.rowEnd = min(z.rowEnd, bandMax)
        if z.rowEnd <= z.rowStart || z.colEnd <= z.colStart { return nil }
        return z
    }
}
