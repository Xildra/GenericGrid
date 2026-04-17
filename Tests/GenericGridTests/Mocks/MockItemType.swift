//
//  MockItemType.swift
//  GenericGrid Tests
//
//  Mock item type for unit testing.
//

import SwiftUI
@testable import GenericGrid

struct MockItemType: GridItemType, Sendable {
    var id: String { name }
    var name: String
    var width: Int
    var height: Int
    var colorHex: String
    var label: String

    static let small  = MockItemType(name: "Small",  width: 1, height: 1, colorHex: "#FF0000", label: "S")
    static let medium = MockItemType(name: "Medium", width: 2, height: 1, colorHex: "#00FF00", label: "M")
    static let large  = MockItemType(name: "Large",  width: 2, height: 2, colorHex: "#0000FF", label: "L")
    static let tall   = MockItemType(name: "Tall",   width: 1, height: 3, colorHex: "#FFFF00", label: "T")
}
