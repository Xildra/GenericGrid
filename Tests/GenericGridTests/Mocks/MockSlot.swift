//
//  MockSlot.swift
//  GenericGrid Tests
//
//  Fixed-position slot: coordinates come from the configuration and
//  never change, only the occupant does. Anchor setters are no-ops, as
//  in a real slot model.
//

import SwiftUI
import Observation
@testable import GenericGrid

@Observable
final class MockSlot: GridSlot, @unchecked Sendable {
    typealias ItemType = MockItemType

    let id = UUID()
    let label: String
    var occupant: MockItemType?
    var rotated: Bool = false

    private let slotRow: Double
    private let slotCol: Double

    var anchorRow: Double {
        get { slotRow }
        set { }
    }
    var anchorCol: Double {
        get { slotCol }
        set { }
    }

    init(label: String, row: Double, col: Double, occupant: MockItemType? = nil) {
        self.label = label
        self.slotRow = row
        self.slotCol = col
        self.occupant = occupant
    }
}
