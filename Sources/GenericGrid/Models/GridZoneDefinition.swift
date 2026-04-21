//
//  GridZoneDefinition.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Describes a rectangular zone on the grid.
//  - Position (start) is free and can fall anywhere on the canvas.
//  - Size (end - start) is an integer on each axis, so the zone's
//    interior always draws a clean `rowCount × colCount` grid.
//  - Each zone carries its own rule, optional colour and optional
//    type restrictions.
//

import SwiftUI

public struct GridZoneDefinition: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var label: String
    public var rule: ZoneRule

    /// Zone rectangle. `rowStart` / `colStart` can be any `Double`.
    /// `rowEnd` / `colEnd` are constrained so that the size on each axis
    /// is an integer (enforced by the editor).
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

    /// Returns `true` if the given sub-cell (0.5×0.5) is fully inside this zone.
    public func contains(_ cell: GridCell) -> Bool {
        cell.r >= rowStart && cell.r + GridGesture.halfCell <= rowEnd &&
        cell.c >= colStart && cell.c + GridGesture.halfCell <= colEnd
    }

    /// Returns `true` if the raw anchor point lies inside the zone bounds.
    /// Used for snap lookups where the anchor itself — not a half-cell
    /// sub-cell — must be located.
    public func containsPoint(_ cell: GridCell) -> Bool {
        cell.r >= rowStart && cell.r <= rowEnd &&
        cell.c >= colStart && cell.c <= colEnd
    }

    // MARK: - Dimensions

    public var rowSize: Double { rowEnd - rowStart }
    public var colSize: Double { colEnd - colStart }

    /// Integer count of rows / columns in the zone's internal grid.
    /// Rounded defensively — the editor enforces integer sizes.
    public var rowCount: Int { max(1, Int(rowSize.rounded())) }
    public var colCount: Int { max(1, Int(colSize.rounded())) }
}
