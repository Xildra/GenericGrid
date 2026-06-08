//
//  GridCanvasConfig+Resize.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Mutating helpers for resizing the overall grid. Resizing must
//  keep compartments tiling every cell and zones inside the new
//  bounds — direct writes to `rows` / `cols` would otherwise leave
//  `columnBands` invalid and wipe the visible grid.
//

import Foundation

extension GridCanvasConfig {

    /// Updates the grid's row count while keeping compartments tiled and
    /// clamping any zones that fall outside the new range. Bands touching
    /// the previous bottom edge are stretched to the new bottom; bands
    /// fully outside the new range are dropped.
    public mutating func setRows(_ newRows: Int) {
        let target = max(1, newRows)
        guard target != rows else { return }
        let oldRows = rows
        rows = target
        if let labels = rowLabels {
            rowLabels = Array(labels.prefix(target))
        }
        adjustBandsForDimensionChange(oldRows: oldRows, oldCols: cols)
    }

    /// Updates the grid's column count while clamping zones to the new
    /// horizontal range and trimming oversized band labels.
    public mutating func setCols(_ newCols: Int) {
        let target = max(1, newCols)
        guard target != cols else { return }
        let oldCols = cols
        cols = target
        if let labels = colLabels {
            colLabels = Array(labels.prefix(target))
        }
        adjustBandsForDimensionChange(oldRows: rows, oldCols: oldCols)
    }

    /// Re-tiles `columnBands` to the current `rows` / `cols`. Drops
    /// bands that fell outside the new bounds, clamps the rest, and
    /// stretches bands that were on the previous bottom/right edge so
    /// the tiling reaches the new edge. Falls back to a single full-grid
    /// band (preserving the union of zones) when the result wouldn't
    /// form a valid tiling.
    private mutating func adjustBandsForDimensionChange(oldRows: Int, oldCols: Int) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands else { return }

        bands = bands.compactMap { band in
            var b = band
            if b.rowStart >= rows || b.colStart >= cols { return nil }
            if b.rowEnd >= rows { b.rowEnd = rows - 1 }
            if b.colEnd >= cols { b.colEnd = cols - 1 }
            return b
        }

        if oldRows < rows {
            let oldMaxR = oldRows - 1
            for i in bands.indices where bands[i].rowEnd == oldMaxR {
                bands[i].rowEnd = rows - 1
            }
        }
        if oldCols < cols {
            let oldMaxC = oldCols - 1
            for i in bands.indices where bands[i].colEnd == oldMaxC {
                bands[i].colEnd = cols - 1
            }
        }

        if !Self.validate(bands: bands, totalRows: rows, totalCols: cols) {
            let allZones = bands.flatMap(\.zones)
            bands = [ColumnBand(id: Self.fallbackBandID,
                                rowStart: 0,
                                rowEnd: max(0, rows - 1),
                                colStart: 0,
                                colEnd: max(0, cols - 1),
                                labels: colLabels,
                                zones: allZones)]
        }

        for b in bands.indices {
            let effCols = bands[b].effectiveCols(default: cols)
            if let labels = bands[b].labels, labels.count > effCols {
                bands[b].labels = Array(labels.prefix(effCols))
            }
            bands[b].zones = bands[b].zones.compactMap { clampZone($0, band: bands[b]) }
        }

        columnBands = bands
    }

    /// Clamps a zone to its band's bounds. Returns nil if the zone no
    /// longer fits. Uses the band's effective subdivision count.
    private func clampZone(_ zone: GridZoneDefinition,
                           band: ColumnBand) -> GridZoneDefinition? {
        var z = zone
        let bandCols = band.effectiveCols(default: cols)
        if z.rowStart >= Double(rows) || z.colStart >= Double(bandCols) { return nil }
        z.rowEnd = min(z.rowEnd, Double(rows))
        z.colEnd = min(z.colEnd, Double(bandCols))
        let bandMaxRow = Double(band.rowEnd + 1)
        z.rowEnd = min(z.rowEnd, bandMaxRow)
        if z.rowEnd <= z.rowStart || z.colEnd <= z.colStart { return nil }
        return z
    }
}
