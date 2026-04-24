//
//  ColumnBand.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  A horizontal compartment of the main grid that carries its own
//  set of column titles and owns the zones placed inside its row
//  range. Bands are contiguous and must cover every row of the grid
//  — no gaps, no overlaps.
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
    /// Zones belonging to this compartment. A zone's `rowStart` must
    /// fall inside the band's row range — enforced by the mutating
    /// helpers on `GridCanvasConfig`.
    public var zones: [GridZoneDefinition]

    public init(id: UUID = UUID(),
                rowStart: Int,
                rowEnd: Int,
                labels: [String]? = nil,
                zones: [GridZoneDefinition] = []) {
        self.id = id
        self.rowStart = rowStart
        self.rowEnd = rowEnd
        self.labels = labels
        self.zones = zones
    }

    private enum CodingKeys: String, CodingKey {
        case id, rowStart, rowEnd, labels, zones
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        rowStart = try c.decode(Int.self, forKey: .rowStart)
        rowEnd = try c.decode(Int.self, forKey: .rowEnd)
        labels = try c.decodeIfPresent([String].self, forKey: .labels)
        zones = try c.decodeIfPresent([GridZoneDefinition].self, forKey: .zones) ?? []
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
