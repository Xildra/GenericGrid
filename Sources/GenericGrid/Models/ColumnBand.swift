//
//  ColumnBand.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  A horizontal compartment of the main grid that carries its own
//  set of column titles. Bands are contiguous and must cover every
//  row of the grid — no gaps, no overlaps.
//

import Foundation

public struct ColumnBand: Codable, Identifiable, Hashable, Sendable {

    public var id: UUID
    /// Inclusive index of the first row of the band.
    public var rowStart: Int
    /// Inclusive index of the last row of the band.
    public var rowEnd: Int
    /// Optional labels, one per column. When nil, falls back to A/B/C…
    public var labels: [String]?

    public init(id: UUID = UUID(),
                rowStart: Int,
                rowEnd: Int,
                labels: [String]? = nil) {
        self.id = id
        self.rowStart = rowStart
        self.rowEnd = rowEnd
        self.labels = labels
    }

    /// Number of rows the band spans (inclusive range).
    public var rowCount: Int { max(0, rowEnd - rowStart + 1) }

    /// `true` if the given logical row index falls inside the band.
    public func contains(row r: Int) -> Bool {
        r >= rowStart && r <= rowEnd
    }

    /// Column label at `col` within this band, falling back to A/B/C…
    public func colLabel(at col: Int) -> String {
        if let labels, col < labels.count { return labels[col] }
        return col < 26 ? String(UnicodeScalar(65 + col)!) : "\(col)"
    }
}
