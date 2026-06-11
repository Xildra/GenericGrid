//
//  ColumnBand.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  A 2D compartment of the main grid: a rectangle defined by its row
//  range AND its column range. Carries its own set of column titles
//  and owns the zones placed inside its bounds. Bands tile the grid
//  as a rectangular partition — every cell belongs to exactly one
//  band, with no gap or overlap. The defaults (`colStart = 0`,
//  `colEnd = -1`) keep backwards-compatible behaviour: a band created
//  without explicit column bounds spans the full grid width, which is
//  resolved against `GridCanvasConfig.cols` at load time.
//

import SwiftUI

public struct ColumnBand: Codable, Identifiable, Hashable, Sendable {

    public var id: UUID
    /// Inclusive index of the first row of the band.
    public var rowStart: Int
    /// Inclusive index of the last row of the band.
    public var rowEnd: Int
    /// Inclusive index of the first column of the band.
    public var colStart: Int
    /// Inclusive index of the last column of the band. A value below
    /// `colStart` is treated as a "spans to grid end" sentinel and
    /// normalised by `GridCanvasConfig` against the grid's `cols`.
    public var colEnd: Int
    /// Optional labels, one per column. When nil, falls back to A/B/C…
    public var labels: [String]?
    /// Optional column subdivision count override for this compartment.
    /// When nil the band uses its natural column count
    /// (`colEnd - colStart + 1`). Allows compartments to subdivide
    /// their horizontal extent more or less finely than their natural
    /// width.
    public var cols: Int?
    /// Optional custom border colour, drawn on top of the regular grid
    /// lines around the band's rectangle. Stored as a hex string for
    /// JSON portability. Nil = no custom border (regular grid lines
    /// still show).
    public var borderColorHex: String?
    /// Optional custom border width, in points. Ignored when
    /// `borderColorHex` is nil. A value of 0 hides the border.
    public var borderWidth: Double?
    /// Zones belonging to this compartment. A zone's `(rowStart, colStart)`
    /// must fall inside the band's range — enforced by the mutating
    /// helpers on `GridCanvasConfig`.
    public var zones: [GridZoneDefinition]

    public init(id: UUID = UUID(),
                rowStart: Int,
                rowEnd: Int,
                colStart: Int = 0,
                colEnd: Int = -1,
                labels: [String]? = nil,
                cols: Int? = nil,
                borderColorHex: String? = nil,
                borderWidth: Double? = nil,
                zones: [GridZoneDefinition] = []) {
        self.id = id
        self.rowStart = rowStart
        self.rowEnd = rowEnd
        self.colStart = colStart
        self.colEnd = colEnd
        self.labels = labels
        self.cols = cols
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.zones = zones
    }

    private enum CodingKeys: String, CodingKey {
        case id, rowStart, rowEnd, colStart, colEnd, labels, cols,
             borderColorHex, borderWidth, zones
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        rowStart = try c.decode(Int.self, forKey: .rowStart)
        rowEnd = try c.decode(Int.self, forKey: .rowEnd)
        colStart = try c.decodeIfPresent(Int.self, forKey: .colStart) ?? 0
        colEnd = try c.decodeIfPresent(Int.self, forKey: .colEnd) ?? -1
        labels = try c.decodeIfPresent([String].self, forKey: .labels)
        cols = try c.decodeIfPresent(Int.self, forKey: .cols)
        borderColorHex = try c.decodeIfPresent(String.self, forKey: .borderColorHex)
        borderWidth = try c.decodeIfPresent(Double.self, forKey: .borderWidth)
        zones = try c.decodeIfPresent([GridZoneDefinition].self, forKey: .zones) ?? []
    }

    /// Resolved SwiftUI border colour, backed by `borderColorHex`.
    /// Nil when no custom border is set.
    public var borderColor: Color? {
        get { borderColorHex.map { Color(hex: $0) } }
        set { borderColorHex = newValue?.toHex() }
    }

    /// `true` when this band has a visible custom border (non-nil
    /// colour and non-zero width).
    public var hasCustomBorder: Bool {
        borderColorHex != nil && (borderWidth ?? 0) > 0
    }

    /// Natural column count: width of the band's column range.
    /// Returns 0 when bounds are not yet normalised against the grid.
    public var colCount: Int { max(0, colEnd - colStart + 1) }

    /// Effective subdivision count: this band's override or its natural
    /// column count, falling back to the grid default when neither is
    /// available (legacy code path).
    public func effectiveCols(default gridCols: Int) -> Int {
        if let cols { return max(1, cols) }
        let natural = colCount
        return natural > 0 ? natural : max(1, gridCols)
    }

    /// Number of rows the band spans (inclusive range).
    public var rowCount: Int { max(0, rowEnd - rowStart + 1) }

    /// `true` if the given logical row index falls inside the band.
    public func contains(row r: Int) -> Bool {
        r >= rowStart && r <= rowEnd
    }

    /// `true` if the given logical column index falls inside the band.
    public func contains(col c: Int) -> Bool {
        c >= colStart && c <= colEnd
    }

    /// `true` if the given (row, col) pair falls inside the band.
    public func contains(row r: Int, col c: Int) -> Bool {
        contains(row: r) && contains(col: c)
    }

    /// Column label at `col` within this band, falling back to A/B/C…
    public func colLabel(at col: Int) -> String {
        if let labels, col < labels.count { return labels[col] }
        return col < 26 ? String(UnicodeScalar(65 + col)!) : "\(col)"
    }
}
