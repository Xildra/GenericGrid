//
//  GridCanvasConfig+CellSlots.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Whole-cell enumeration: walks every compartment and exposes each
//  grid cell with its display label ("12A"), so a config can be
//  mirrored into a consumer's own position model (seats, parking
//  slots…). Availability follows the same first-match-wins rule as
//  `zone(at:)`: a cell is free when the first zone covering it is
//  `.free`, so a runtime lock prepended on top of a free zone
//  correctly removes the cell from the list.
//

import Foundation

/// A whole grid cell resolved to its absolute coordinates, its display
/// labels and the zone that owns it. Produced by the enumeration
/// helpers on `GridCanvasConfig`.
public struct GridCellSlot: Hashable, Sendable, Identifiable {

    /// Absolute row index of the cell.
    public let row: Int
    /// Absolute column index of the cell.
    public let col: Int
    /// Row label from the config ("12"), falling back to the 1-based index.
    public let rowLabel: String
    /// Column label of the owning compartment ("A"), falling back to A/B/C…
    public let colLabel: String
    /// Identifier of the zone covering the cell, when there is one.
    public let zoneID: UUID?
    /// Label of the zone covering the cell, when there is one.
    public let zoneLabel: String?

    public init(row: Int, col: Int, rowLabel: String, colLabel: String,
                zoneID: UUID? = nil, zoneLabel: String? = nil) {
        self.row = row; self.col = col
        self.rowLabel = rowLabel; self.colLabel = colLabel
        self.zoneID = zoneID; self.zoneLabel = zoneLabel
    }

    /// Stable identity for `ForEach` — a cell belongs to exactly one
    /// compartment, so its coordinates are unique across the grid.
    public var id: String { "\(row)x\(col)" }

    /// Display label of the cell: row label followed by column label
    /// ("12" + "A" = "12A"). Build a different format from `rowLabel`
    /// and `colLabel` when a separator is needed.
    public var label: String { rowLabel + colLabel }

    /// Anchor cell in engine coordinates — the top-left sub-cell of
    /// the whole cell, ready to be used as `anchorRow` / `anchorCol`.
    public var cell: GridCell { GridCell(Double(row), c: Double(col)) }
}

extension GridCanvasConfig {

    // MARK: - Single-cell lookups

    /// Display label of the whole cell at `(row, col)`: row label
    /// followed by the column label of the owning compartment ("12A").
    public func cellLabel(row: Int, col: Int) -> String {
        let band = band(forRow: row, atCol: Double(col))
        return rowLabel(at: row) + band.colLabel(at: max(0, col - band.colStart))
    }

    /// First zone covering the whole cell at `(row, col)`, in the same
    /// order as `zones` — so a zone prepended into its compartment
    /// (runtime lock) wins over the free zone underneath. Returns nil
    /// when the cell is outside every zone.
    public func zone(atRow r: Int, col c: Int) -> GridZoneDefinition? {
        for band in effectiveBands {
            for z in band.zones where z.containsWholeCell(row: r, col: c) { return z }
        }
        return nil
    }

    // MARK: - Enumeration

    /// Every whole cell of the grid, ordered by row then column.
    /// Honours per-compartment column subdivisions, so a band with a
    /// `cols` override yields exactly its own number of cells per row.
    public func allCellSlots() -> [GridCellSlot] {
        cellSlots { _ in true }
    }

    /// Cells available for placement — those covered by a `.free` zone,
    /// ordered by row then column. `.locked`, `.forbidden` and
    /// `.restricted` zones are excluded.
    ///
    /// - Parameter includingUnzoned: also returns cells that belong to
    ///   no zone at all. They accept placements (`canAccept` returns
    ///   `true` outside zones) but carry no explicit rule, so they are
    ///   left out by default.
    public func freeCellSlots(includingUnzoned: Bool = false) -> [GridCellSlot] {
        cellSlots { zone in
            guard let zone else { return includingUnzoned }
            return zone.rule == .free
        }
    }

    /// Labels of the available cells ("12A", "12B", …), ordered by row
    /// then column. Convenience over `freeCellSlots(includingUnzoned:)`.
    public func freeCellLabels(includingUnzoned: Bool = false) -> [String] {
        freeCellSlots(includingUnzoned: includingUnzoned).map(\.label)
    }

    /// Core enumeration: walks each compartment's own row and column
    /// range, resolves the zone owning every whole cell, and keeps the
    /// ones accepted by `isIncluded`. Results are sorted into reading
    /// order so vertically split grids still come out row by row.
    private func cellSlots(
        matching isIncluded: (GridZoneDefinition?) -> Bool
    ) -> [GridCellSlot] {
        var slots: [GridCellSlot] = []
        for band in effectiveBands {
            let bandCols = band.effectiveCols(default: cols)
            guard band.rowCount > 0, bandCols > 0 else { continue }
            for r in band.rowStart...band.rowEnd {
                let rLabel = rowLabel(at: r)
                for local in 0..<bandCols {
                    let c = band.colStart + local
                    let zone = zone(atRow: r, col: c)
                    guard isIncluded(zone) else { continue }
                    slots.append(GridCellSlot(row: r, col: c,
                                              rowLabel: rLabel,
                                              colLabel: band.colLabel(at: local),
                                              zoneID: zone?.id,
                                              zoneLabel: zone?.label))
                }
            }
        }
        return slots.sorted { $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row }
    }
}
