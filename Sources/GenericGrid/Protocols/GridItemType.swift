//
//  GridItemType.swift
//  GenericGrid Module
//
//  Protocol for item types that can be placed on the grid
//  (e.g. parcel type, furniture type, passenger class…).
//

import SwiftUI

public protocol GridItemType: Identifiable, Equatable {
    var name: String { get }
    var width: Int { get }
    var height: Int { get }
    var colorHex: String { get }
    var label: String { get }
}

public extension GridItemType {
    /// Resolved SwiftUI colour from `colorHex`.
    var color: Color { Color(hex: colorHex) }
    /// Total number of cells occupied by this type.
    var surface: Int { width * height }
}
