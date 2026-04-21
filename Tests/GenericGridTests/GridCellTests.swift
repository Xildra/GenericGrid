//
//  GridCellTests.swift
//  GenericGrid Tests
//

import Testing
@testable import GenericGrid

@Suite("GridCell")
struct GridCellTests {

    // MARK: - Snap half

    @Test("snapHalf rounds to nearest 0.5")
    func snapHalfRounding() {
        #expect(GridCell.snapHalf(0.0)  == 0.0)
        #expect(GridCell.snapHalf(0.24) == 0.0)
        #expect(GridCell.snapHalf(0.25) == 0.5)
        #expect(GridCell.snapHalf(0.5)  == 0.5)
        #expect(GridCell.snapHalf(0.74) == 0.5)
        #expect(GridCell.snapHalf(0.75) == 1.0)
        #expect(GridCell.snapHalf(1.0)  == 1.0)
        #expect(GridCell.snapHalf(2.3)  == 2.5)
        #expect(GridCell.snapHalf(2.7)  == 2.5)
        #expect(GridCell.snapHalf(2.76) == 3.0)
    }

    @Test("snapHalf handles negative values")
    func snapHalfNegative() {
        #expect(GridCell.snapHalf(-0.3) == -0.5)
        #expect(GridCell.snapHalf(-0.1) == 0.0)
        #expect(GridCell.snapHalf(-1.0) == -1.0)
    }

    // MARK: - Init

    @Test("init stores raw coordinates without snapping")
    func initIsRaw() {
        let cell = GridCell(0.3, c: 1.8)
        #expect(cell.r == 0.3)
        #expect(cell.c == 1.8)
    }

    @Test("init preserves already-aligned values")
    func initPreservesAligned() {
        let cell = GridCell(1.5, c: 3.0)
        #expect(cell.r == 1.5)
        #expect(cell.c == 3.0)
    }

    // MARK: - Equality & Hashing

    @Test("cells with identical coordinates are equal")
    func equality() {
        let a = GridCell(0.5, c: 1.5)
        let b = GridCell(0.5, c: 1.5)
        #expect(a == b)
    }

    @Test("different cells are not equal")
    func inequality() {
        let a = GridCell(0.0, c: 0.0)
        let b = GridCell(0.5, c: 0.0)
        #expect(a != b)
    }

    @Test("equal cells produce same hash")
    func hashing() {
        let a = GridCell(0.5, c: 2.0)
        let b = GridCell(0.5, c: 2.0)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("cells work correctly in a Set")
    func setUsage() {
        var set = Set<GridCell>()
        set.insert(GridCell(0.0, c: 0.0))
        set.insert(GridCell(0.0, c: 0.0)) // same raw coords → duplicate
        set.insert(GridCell(0.5, c: 0.0))
        #expect(set.count == 2)
    }
}
