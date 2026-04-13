//
//  GridCell.swift
//  GenericGrid Module
//
//  Represents a single cell position on the grid.
//

import Foundation

public struct GridCell: Hashable, Sendable {
    public let r: Int
    public let c: Int

    public init(_ r: Int, c: Int) {
        self.r = r
        self.c = c
    }
}
