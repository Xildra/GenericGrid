//
//  GridCell.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Represents a position on the grid at half-cell precision.
//  Coordinates are always aligned to 0.5 increments
//  (0, 0.5, 1, 1.5, …) so the hash/equality of two cells is stable.
//

import Foundation

public struct GridCell: Hashable, Sendable {
    public let r: Double
    public let c: Double

    /// Builds a cell, snapping `r` and `c` to the nearest 0.5.
    public init(_ r: Double, c: Double) {
        self.r = GridCell.snapHalf(r)
        self.c = GridCell.snapHalf(c)
    }

    /// Snaps a value to the nearest half-cell (0, 0.5, 1, 1.5…).
    public static func snapHalf(_ v: Double) -> Double {
        (v * 2).rounded() / 2
    }
}
