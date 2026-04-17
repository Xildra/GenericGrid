//
//  MockItem.swift
//  GenericGrid Tests
//
//  Mock placeable item for unit testing.
//

import SwiftUI
import Observation
@testable import GenericGrid

@Observable
final class MockItem: GridPlaceable, @unchecked Sendable {
    typealias ItemType = MockItemType

    let id = UUID()
    var itemType: MockItemType?
    var anchorRow: Double
    var anchorCol: Double
    var rotated: Bool

    init(type: MockItemType, row: Double = 0, col: Double = 0, rotated: Bool = false) {
        self.itemType = type
        self.anchorRow = row
        self.anchorCol = col
        self.rotated = rotated
    }
}
