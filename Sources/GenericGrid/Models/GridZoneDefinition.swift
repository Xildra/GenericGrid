//
//  GridZoneDefinition.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Describes a rectangular zone on the grid with a rule,
//  optional colour, and optional type restrictions.
//

import SwiftUI

public struct GridZoneDefinition: Codable, Identifiable, Hashable, Sendable {
	public var id = UUID()
    public var label: String
    public var rule: ZoneRule

    /// Zone rectangle (inclusive start, exclusive end):
    /// rows [rowStart, rowEnd), cols [colStart, colEnd)
    /// Supports half-cell increments (e.g. 0.5, 3.5).
    public var rowStart: Double
    public var rowEnd: Double
    public var colStart: Double
    public var colEnd: Double

    /// Optional background colour for the zone (hex string).
    public var colorHex: String?

    /// For `.restricted` zones: names of the item types that are allowed.
    public var allowedTypeNames: [String]?

    public init(label: String = "New Zone", rule: ZoneRule = .free,
                rowStart: Double = 0, rowEnd: Double, colStart: Double = 0, colEnd: Double,
                color: Color = .gray, allowedTypeNames: [String]? = nil) {
        self.label = label; self.rule = rule
        self.rowStart = rowStart; self.rowEnd = rowEnd
        self.colStart = colStart; self.colEnd = colEnd
        self.colorHex = color.toHex()
        self.allowedTypeNames = allowedTypeNames
    }

    /// Resolved SwiftUI colour, backed by `colorHex`. Defaults to `.gray`.
    public var color: Color {
        get { colorHex.map { Color(hex: $0) } ?? .gray }
        set { colorHex = newValue.toHex() }
    }

    /// Returns `true` if the given cell falls inside this zone.
    public func contains(_ cell: GridCell) -> Bool {
        Double(cell.r) >= rowStart && Double(cell.r) < rowEnd &&
        Double(cell.c) >= colStart && Double(cell.c) < colEnd
    }
}
