//
//  GridCanvasConfig+ColumnBands.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Band geometry: resolution, lookups, visual Y coordinates,
//  validation, and overall content sizing that depends on
//  intermediate compartment header strips.
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

    /// Resolved, always-valid list of bands covering the whole grid.
    /// Falls back to a single band wrapping `colLabels` when `columnBands`
    /// is nil or fails validation.
    public var effectiveBands: [ColumnBand] {
        if let bands = columnBands,
           Self.validate(bands: bands, totalRows: rows) {
            return bands
        }
        return [ColumnBand(id: Self.fallbackBandID,
                           rowStart: 0,
                           rowEnd: max(0, rows - 1),
                           labels: colLabels)]
    }

    /// Number of distinct compartments in the grid.
    public var bandCount: Int { effectiveBands.count }

    /// Total vertical cell-slot count: data rows + intermediate headers.
    /// Intermediate headers (between compartments) each occupy one cell row.
    public var totalVerticalCells: Int {
        rows + max(0, bandCount - 1)
    }

    // MARK: - Lookups

    /// The compartment containing the given logical row (clamped to valid range).
    public func band(forRow r: Int) -> ColumnBand {
        let clamped = max(0, min(rows - 1, r))
        let bands = effectiveBands
        return bands.first { $0.contains(row: clamped) } ?? bands[0]
    }

    /// Zero-based index of the compartment containing the given logical row.
    public func bandIndex(forRow r: Int) -> Int {
        let clamped = max(0, min(rows - 1, r))
        let bands = effectiveBands
        for (i, band) in bands.enumerated() where band.contains(row: clamped) {
            return i
        }
        return 0
    }

    /// Vertical offset (in cells) added by intermediate compartment headers
    /// above the given logical row. The first band's header lives in the
    /// top `labelMargin`, so it does not contribute.
    public func bandHeaderOffsetCells(forRow r: Int) -> Int {
        bandIndex(forRow: r)
    }

    /// Column label at column `col` within the compartment containing row `r`.
    public func colLabel(at col: Int, forRow r: Int) -> String {
        band(forRow: r).colLabel(at: col)
    }

    // MARK: - Visual Y geometry

    /// Visual Y coordinate of a given logical row, accounting for
    /// intermediate compartment header strips.
    public func yForRow(_ r: Double, cellSize cs: CGFloat) -> CGFloat {
        let idx = bandIndex(forRow: Int(r.rounded(.down)))
        return (CGFloat(r) + CGFloat(idx)) * cs
    }

    /// Converts a visual Y coordinate (within the content area) back to
    /// a logical row index. Returns nil when the point falls inside an
    /// intermediate compartment header strip (not a data row).
    public func rowForY(_ y: CGFloat, cellSize cs: CGFloat) -> Double? {
        guard cs > 0 else { return nil }
        let slot = Double(y / cs)
        guard slot >= 0 else { return nil }
        let bands = effectiveBands
        var logicalStart = 0
        for (i, band) in bands.enumerated() {
            let visualStart = Double(logicalStart + i)
            let visualEnd = visualStart + Double(band.rowCount)
            if i > 0 {
                let headerStart = visualStart - 1
                if slot >= headerStart && slot < visualStart { return nil }
            }
            if slot < visualEnd {
                let local = slot - visualStart
                return Double(band.rowStart) + max(0, local)
            }
            logicalStart += band.rowCount
        }
        return nil
    }

    /// Total visual height of the content area (data rows + intermediate
    /// header rows) at the given cell size.
    public func totalContentHeight(cellSize cs: CGFloat) -> CGFloat {
        CGFloat(totalVerticalCells) * cs
    }

    // MARK: - Validation

    /// Validates that bands are non-empty, sorted, contiguous, and
    /// exactly cover `[0, totalRows - 1]` with no gap or overlap.
    public static func validate(bands: [ColumnBand], totalRows: Int) -> Bool {
        guard totalRows > 0, !bands.isEmpty else { return false }
        let sorted = bands.sorted { $0.rowStart < $1.rowStart }
        guard sorted.first?.rowStart == 0 else { return false }
        guard sorted.last?.rowEnd == totalRows - 1 else { return false }
        for i in 0..<sorted.count {
            guard sorted[i].rowStart <= sorted[i].rowEnd else { return false }
            if i > 0 {
                guard sorted[i - 1].rowEnd + 1 == sorted[i].rowStart else { return false }
            }
        }
        return true
    }
}
