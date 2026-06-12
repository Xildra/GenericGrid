//
//  GridCanvasConfig+ColumnBands.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Band geometry: resolution, lookups, visual coordinates, validation,
//  and overall content sizing. Bands tile the grid as a rectangular
//  partition (every cell belongs to exactly one band, no gap, no
//  overlap). Their column range may not span the full width when a
//  band has been split vertically — so column geometry is band-local
//  (X offset + cell width derived from the band's own col extent),
//  and vertical geometry is driven by "row strips" (maximal row
//  ranges where the column partition is consistent).
//

import SwiftUI

extension GridCanvasConfig {

    // MARK: - Resolution

    /// Stable identifier used by the synthetic fallback band so SwiftUI's
    /// `ForEach` keeps a consistent identity across renders when
    /// `columnBands` is nil. Also reused when we first promote a config
    /// into the explicit `columnBands` representation, so any
    /// `editingBandID` captured from the fallback still matches.
    public static let fallbackBandID = UUID(uuidString: "00000000-0000-0000-0000-0000000FA11B")!

    /// Resolved, always-valid list of bands tiling the whole grid.
    /// Falls back to a single full-grid band wrapping `colLabels` when
    /// `columnBands` is nil or fails validation.
    public var effectiveBands: [ColumnBand] {
        if let bands = columnBands,
           Self.validate(bands: bands, totalRows: rows, totalCols: cols) {
            return bands
        }
        return [ColumnBand(id: Self.fallbackBandID,
                           rowStart: 0,
                           rowEnd: max(0, rows - 1),
                           colStart: 0,
                           colEnd: max(0, cols - 1),
                           labels: colLabels)]
    }

    /// Number of distinct compartments in the grid.
    public var bandCount: Int { effectiveBands.count }

    // MARK: - Row strips

    /// Horizontal slices of the grid delimited by *global* horizontal
    /// cuts — rows that no band crosses. A strip header is only
    /// inserted between adjacent strips, so this guarantees that no
    /// band is split visually by a header it doesn't actually break
    /// against. For pure horizontal splits every band boundary is a
    /// global cut and the behaviour matches the 1D model; for
    /// asymmetric 2D layouts (e.g. a full-height band next to a
    /// horizontally-split column) no intermediate header is inserted,
    /// so the full-height band keeps its true row count.
    public var rowStrips: [(rowStart: Int, rowEnd: Int)] {
        let bands = effectiveBands
        var cuts = Set<Int>([0, rows])
        for r in 1..<rows {
            let isCrossed = bands.contains { $0.rowStart < r && $0.rowEnd >= r }
            if !isCrossed { cuts.insert(r) }
        }
        let sorted = cuts.sorted()
        var strips: [(Int, Int)] = []
        for i in 0..<sorted.count - 1 {
            strips.append((sorted[i], sorted[i + 1] - 1))
        }
        return strips
    }

    /// Zero-based index of the strip containing the given logical row.
    public func rowStripIndex(forRow r: Int) -> Int {
        let clamped = max(0, min(rows - 1, r))
        let strips = rowStrips
        for (i, strip) in strips.enumerated() where clamped >= strip.rowStart && clamped <= strip.rowEnd {
            return i
        }
        return 0
    }

    /// Total vertical cell-slot count: data rows + intermediate strip
    /// header rows. Intermediate headers (between strips) each occupy
    /// one cell row; the first strip uses the top `labelMargin` instead.
    public var totalVerticalCells: Int {
        rows + max(0, rowStrips.count - 1)
    }

    // MARK: - Lookups

    /// The compartment containing the given (row, col) position
    /// (clamped to valid range). Disambiguates between bands stacked
    /// side by side in the same row range.
    public func band(forRow r: Int, col c: Int) -> ColumnBand {
        let cr = max(0, min(rows - 1, r))
        let cc = max(0, min(cols - 1, c))
        let bands = effectiveBands
        return bands.first { $0.contains(row: cr, col: cc) } ?? bands[0]
    }

    /// Convenience: first band intersecting the given row. Use the
    /// `(row, col)` variant when several bands share the row range,
    /// otherwise this returns the leftmost one.
    public func band(forRow r: Int) -> ColumnBand {
        let clamped = max(0, min(rows - 1, r))
        let bands = effectiveBands
        return bands.first { $0.contains(row: clamped) } ?? bands[0]
    }

    /// Index of the band containing (row, col) in `effectiveBands`.
    public func bandIndex(forRow r: Int, col c: Int) -> Int {
        let cr = max(0, min(rows - 1, r))
        let cc = max(0, min(cols - 1, c))
        let bands = effectiveBands
        for (i, band) in bands.enumerated() where band.contains(row: cr, col: cc) {
            return i
        }
        return 0
    }

    /// Convenience: first band index intersecting the given row.
    public func bandIndex(forRow r: Int) -> Int {
        let clamped = max(0, min(rows - 1, r))
        let bands = effectiveBands
        for (i, band) in bands.enumerated() where band.contains(row: clamped) {
            return i
        }
        return 0
    }

    /// Band owning the given absolute position. Like `band(forRow:col:)`
    /// but takes a fractional column and tolerates columns that overflow
    /// a band's natural range (possible when a subdivision override
    /// exceeds the band's natural width): it then falls back to the
    /// rightmost band of the row starting at or before the column.
    public func band(forRow r: Int, atCol c: Double) -> ColumnBand {
        let row = max(0, min(rows - 1, r))
        let bands = effectiveBands
        var fallback: ColumnBand? = nil
        var rightmost: ColumnBand? = nil
        for band in bands where band.contains(row: row) {
            if fallback == nil { fallback = band }
            if c >= Double(band.colStart) && c < Double(band.colEnd + 1) {
                return band
            }
            if Double(band.colStart) <= c,
               rightmost.map({ band.colStart > $0.colStart }) ?? true {
                rightmost = band
            }
        }
        return rightmost ?? fallback ?? bands[0]
    }

    /// Vertical offset (in cells) added by intermediate strip headers
    /// above the given logical row. The first strip's header lives in
    /// the top `labelMargin`, so it does not contribute.
    public func bandHeaderOffsetCells(forRow r: Int) -> Int {
        rowStripIndex(forRow: r)
    }

    /// The band that currently owns the zone with the given identifier,
    /// or nil when no band contains it. Zone coordinates are absolute,
    /// but ownership drives which compartment's cell width the zone is
    /// rendered with — this id-based lookup is the reliable way for
    /// renderers to recover the owning band.
    public func band(forZoneID id: UUID) -> ColumnBand? {
        effectiveBands.first { $0.zones.contains(where: { $0.id == id }) }
    }

    /// Column label at column `col` within the band containing (r, col).
    public func colLabel(at col: Int, forRow r: Int) -> String {
        let band = band(forRow: r, col: col)
        let local = col - band.colStart
        return band.colLabel(at: max(0, local))
    }

    // MARK: - Visual Y geometry

    /// Visual Y coordinate of a given logical row, accounting for
    /// intermediate strip header rows.
    public func yForRow(_ r: Double, cellSize cs: CGFloat) -> CGFloat {
        let idx = rowStripIndex(forRow: Int(r.rounded(.down)))
        return (CGFloat(r) + CGFloat(idx)) * cs
    }

    /// Converts a visual Y coordinate (within the content area) back to
    /// a logical row index. Returns nil when the point falls inside an
    /// intermediate strip header strip (not a data row).
    public func rowForY(_ y: CGFloat, cellSize cs: CGFloat) -> Double? {
        guard cs > 0 else { return nil }
        let slot = Double(y / cs)
        guard slot >= 0 else { return nil }
        let strips = rowStrips
        var cursor = 0
        for (i, strip) in strips.enumerated() {
            let stripRows = strip.rowEnd - strip.rowStart + 1
            let visualStart = Double(cursor)
            let visualEnd = visualStart + Double(stripRows)
            if i > 0 {
                let headerStart = visualStart - 1
                if slot >= headerStart && slot < visualStart { return nil }
            }
            if slot < visualEnd {
                let local = slot - visualStart
                return Double(strip.rowStart) + max(0, local)
            }
            cursor += stripRows + 1 // +1 for the header strip below
        }
        return nil
    }

    /// Total visual height of the content area (data rows + intermediate
    /// header rows) at the given cell size.
    public func totalContentHeight(cellSize cs: CGFloat) -> CGFloat {
        CGFloat(totalVerticalCells) * cs
    }

    // MARK: - Band-local column geometry

    /// Effective subdivision count for the given band: its override or
    /// the band's natural column count.
    public func cols(for band: ColumnBand) -> Int {
        band.effectiveCols(default: cols)
    }

    /// Pixel width of one cell inside the given band. The band's
    /// horizontal extent is `band.colCount * cellSize`; that width is
    /// distributed across the band's subdivision count, so a band with
    /// fewer subdivisions than its natural width gets wider cells.
    public func bandCellWidth(_ band: ColumnBand, baseCellSize cs: CGFloat) -> CGFloat {
        let bandSubdivisions = max(1, cols(for: band))
        let natural = max(1, band.colCount)
        return cs * CGFloat(natural) / CGFloat(bandSubdivisions)
    }

    /// X offset (in pixels) of the band's left edge in the grid.
    public func xForBand(_ band: ColumnBand, baseCellSize cs: CGFloat) -> CGFloat {
        CGFloat(band.colStart) * cs
    }

    /// Absolute X coordinate (in pixels) of a column coordinate inside
    /// the given band. `col` is in the band's local column space
    /// (0 = band's first subdivision).
    public func xForCol(_ col: Double, in band: ColumnBand,
                        baseCellSize cs: CGFloat) -> CGFloat {
        xForBand(band, baseCellSize: cs) + CGFloat(col) * bandCellWidth(band, baseCellSize: cs)
    }

    /// Inverse of `xForCol`: converts an absolute pixel x to a column
    /// coordinate in the given band's local space.
    public func colForX(_ x: CGFloat, in band: ColumnBand,
                        baseCellSize cs: CGFloat) -> Double {
        let bandCellW = bandCellWidth(band, baseCellSize: cs)
        guard bandCellW > 0 else { return 0 }
        let local = x - xForBand(band, baseCellSize: cs)
        return Double(local / bandCellW)
    }

    // MARK: - Hit testing

    /// Converts a touch point (in the content area's coordinate space)
    /// to the snapped anchor cell it falls into, or nil when the point
    /// lies outside the grid or on an intermediate compartment header.
    ///
    /// The owning compartment is resolved from **both** axes — y picks
    /// the row, x picks the band among compartments sharing that row —
    /// so side-by-side compartments hit-test correctly. The column is
    /// converted through the band's own cell width, then re-based into
    /// absolute coordinates (`band.colStart + local`). Snapping
    /// delegates to `snap`, which uses the owning zone's unit grid
    /// inside zones and the half-cell guide elsewhere.
    public func cell(at point: CGPoint, cellSize cs: CGFloat) -> GridCell? {
        guard cs > 0, let r = rowForY(point.y, cellSize: cs) else { return nil }
        let rowsD = Double(rows)
        guard r >= 0, r <= rowsD else { return nil }
        let row = max(0, min(rows - 1, Int(r.rounded(.down))))

        // Resolve the band horizontally among those covering the row.
        let bandsInRow = effectiveBands.filter { $0.contains(row: row) }
        guard !bandsInRow.isEmpty else { return nil }
        let band = bandsInRow.first(where: { b in
            let x0 = xForBand(b, baseCellSize: cs)
            let x1 = x0 + CGFloat(b.colCount) * cs
            return point.x >= x0 && point.x < x1
        }) ?? bandsInRow.max(by: { $0.colEnd < $1.colEnd })!
        let local = colForX(point.x, in: band, baseCellSize: cs)
        let bandCols = Double(cols(for: band))
        guard local >= 0, local <= bandCols else { return nil }

        let c = Double(band.colStart) + local
        let snapped = snap(GridCell(r, c: c))
        guard snapped.r + GridGesture.halfCell <= rowsD,
              snapped.c + GridGesture.halfCell <= Double(band.colStart) + bandCols
        else { return nil }
        return snapped
    }

    // MARK: - Validation

    /// Validates that bands form a rectangular tiling of the grid:
    /// every `(row, col)` cell belongs to exactly one band, with no
    /// gap or overlap. Bands themselves must be non-empty rectangles
    /// inside the grid bounds.
    public static func validate(bands: [ColumnBand], totalRows: Int, totalCols: Int) -> Bool {
        guard totalRows > 0, totalCols > 0, !bands.isEmpty else { return false }
        var covered = Array(repeating: Array(repeating: false, count: totalCols),
                            count: totalRows)
        for band in bands {
            guard band.rowStart >= 0, band.rowEnd < totalRows,
                  band.colStart >= 0, band.colEnd < totalCols,
                  band.rowStart <= band.rowEnd,
                  band.colStart <= band.colEnd else { return false }
            for r in band.rowStart...band.rowEnd {
                for c in band.colStart...band.colEnd {
                    if covered[r][c] { return false }
                    covered[r][c] = true
                }
            }
        }
        for row in covered where row.contains(false) { return false }
        return true
    }
}
