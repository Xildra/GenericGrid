//
//  GridZoneDefinition.swift
//  GenericGrid Module
//
//  Describes a rectangular zone on the grid with a rule,
//  optional colour, and optional type restrictions.
//

import SwiftUI

public struct GridZoneDefinition: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var rule: ZoneRule

    /// Zone rectangle (inclusive start, exclusive end):
    /// rows [rowStart, rowEnd), cols [colStart, colEnd)
    public var rowStart: Int
    public var rowEnd: Int
    public var colStart: Int
    public var colEnd: Int

    /// Optional background colour for the zone (hex string).
    public var colorHex: String?

    /// For `.restricted` zones: names of the item types that are allowed.
    public var allowedTypeNames: [String]?

    public init(id: String, label: String, rule: ZoneRule,
                rowStart: Int, rowEnd: Int, colStart: Int, colEnd: Int,
                colorHex: String? = nil, allowedTypeNames: [String]? = nil) {
        self.id = id; self.label = label; self.rule = rule
        self.rowStart = rowStart; self.rowEnd = rowEnd
        self.colStart = colStart; self.colEnd = colEnd
        self.colorHex = colorHex; self.allowedTypeNames = allowedTypeNames
    }

    /// Resolved SwiftUI colour from the hex string (nil if no hex provided).
    public var color: Color? {
        guard let hex = colorHex else { return nil }
        return Color(hex: hex)
    }

    /// Returns `true` if the given cell falls inside this zone.
    public func contains(_ cell: GridCell) -> Bool {
        cell.r >= rowStart && cell.r < rowEnd &&
        cell.c >= colStart && cell.c < colEnd
    }
}
