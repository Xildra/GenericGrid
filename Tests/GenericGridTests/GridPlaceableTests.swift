//
//  GridPlaceableTests.swift
//  GenericGrid Tests
//

import Testing
@testable import GenericGrid

@Suite("GridPlaceable")
struct GridPlaceableTests {

    // MARK: - Effective dimensions

    @Test("effectiveWidth and effectiveHeight without rotation")
    func dimensionsNoRotation() {
        let item = MockItem(type: .medium) // 2×1
        #expect(item.effectiveWidth == 2)
        #expect(item.effectiveHeight == 1)
    }

    @Test("effectiveWidth and effectiveHeight with rotation")
    func dimensionsRotated() {
        let item = MockItem(type: .medium, rotated: true) // 2×1 rotated → 1×2
        #expect(item.effectiveWidth == 1)
        #expect(item.effectiveHeight == 2)
    }

    @Test("square item dimensions unchanged by rotation")
    func squareRotation() {
        let item = MockItem(type: .large) // 2×2
        #expect(item.effectiveWidth == 2)
        #expect(item.effectiveHeight == 2)
        item.rotated = true
        #expect(item.effectiveWidth == 2)
        #expect(item.effectiveHeight == 2)
    }

    // MARK: - Cells (sub-cell footprint)

    @Test("1×1 item generates 4 sub-cells at origin")
    func cellsSmallAtOrigin() {
        let item = MockItem(type: .small, row: 0, col: 0) // 1×1
        let cells = item.cells
        #expect(cells.count == 4) // 2×2 sub-cells
        let expected: Set<GridCell> = [
            GridCell(0.0, c: 0.0), GridCell(0.0, c: 0.5),
            GridCell(0.5, c: 0.0), GridCell(0.5, c: 0.5)
        ]
        #expect(Set(cells) == expected)
    }

    @Test("2×1 item generates 8 sub-cells")
    func cellsMedium() {
        let item = MockItem(type: .medium, row: 0, col: 0) // 2×1
        let cells = item.cells
        #expect(cells.count == 8) // 4 wide × 2 tall
    }

    @Test("2×2 item generates 16 sub-cells")
    func cellsLarge() {
        let item = MockItem(type: .large, row: 0, col: 0) // 2×2
        let cells = item.cells
        #expect(cells.count == 16) // 4×4
    }

    @Test("cells at half-cell offset")
    func cellsAtHalfOffset() {
        let item = MockItem(type: .small, row: 0.5, col: 1.5) // 1×1
        let cells = item.cells
        let expected: Set<GridCell> = [
            GridCell(0.5, c: 1.5), GridCell(0.5, c: 2.0),
            GridCell(1.0, c: 1.5), GridCell(1.0, c: 2.0)
        ]
        #expect(Set(cells) == expected)
    }

    @Test("rotated item generates correctly oriented sub-cells")
    func cellsRotated() {
        let item = MockItem(type: .tall, row: 0, col: 0, rotated: true) // 1×3 rotated → 3×1
        #expect(item.effectiveWidth == 3)
        #expect(item.effectiveHeight == 1)
        let cells = item.cells
        // 6 wide × 2 tall = 12 sub-cells
        #expect(cells.count == 12)
    }
}
