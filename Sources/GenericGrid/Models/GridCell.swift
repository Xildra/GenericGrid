//
//  GridCell.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Represents a position on the grid. Coordinates are stored as-is,
//  so a cell can live on the global half-cell guide (outside zones)
//  or on a zone-local step (inside a zone with subdivisions).
//  Snapping is explicit via `GridCanvasConfig.snap` or
//  `GridCell.snapHalf` — never implicit at construction.
//

import Foundation

public struct GridCell: Hashable, Sendable {
    public let r: Double
    public let c: Double

    /// Builds a cell at the given coordinates, without any snapping.
    public init(_ r: Double, c: Double) {
        self.r = r
        self.c = c
    }

    /// Snaps a value to the nearest half-cell (0, 0.5, 1, 1.5…).
    /// Used as the default fallback when no zone drives the placement.
    public static func snapHalf(_ v: Double) -> Double {
        (v * 2).rounded() / 2
    }
}
