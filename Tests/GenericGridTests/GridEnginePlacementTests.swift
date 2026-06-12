//
//  GridEnginePlacementTests.swift
//  GenericGrid Tests
//
//  Covers the engine features around placement state: runtime cell
//  locking, unique-type relocation (including the rotation path),
//  and replace-on-conflict.
//

import Foundation
import Testing
@testable import GenericGrid

@Suite("GridEngine placement & locking")
struct GridEnginePlacementTests {

    // MARK: - Helpers

    private func makeEngine(rows: Int = 10, cols: Int = 10,
                            zones: [GridZoneDefinition] = []) -> GridEngine<MockItem> {
        GridEngine(config: GridCanvasConfig(rows: rows, cols: cols, zones: zones))
    }

    private func freeZone(rows: ClosedRange<Double>, cols: ClosedRange<Double>) -> GridZoneDefinition {
        GridZoneDefinition(label: "Free", rule: .free,
                           rowStart: rows.lowerBound, rowEnd: rows.upperBound,
                           colStart: cols.lowerBound, colEnd: cols.upperBound)
    }

    // MARK: - toggleLocked

    @Test("toggleLocked locks then unlocks a free-zone cell")
    func toggleLockRoundTrip() {
        let engine = makeEngine(zones: [freeZone(rows: 0...10, cols: 0...10)])
        let result = engine.toggleLocked(at: GridCell(2, c: 3))
        #expect(result == .locked(GridCell(2, c: 3)))
        #expect(engine.isLocked(at: GridCell(2, c: 3)))
        #expect(!engine.config.canAccept(cell: GridCell(2, c: 3), typeName: "Small"))

        let back = engine.toggleLocked(at: GridCell(2, c: 3))
        #expect(back == .unlocked(GridCell(2, c: 3)))
        #expect(!engine.isLocked(at: GridCell(2, c: 3)))
    }

    @Test("toggleLocked uses the configurable lock label")
    func toggleLockLabel() {
        let engine = makeEngine(zones: [freeZone(rows: 0...10, cols: 0...10)])
        engine.lockLabel = "Unavailable"
        engine.toggleLocked(at: GridCell(0, c: 0))
        #expect(engine.config.zone(at: GridCell(0, c: 0))?.label == "Unavailable")
    }

    @Test("toggleLocked ignores cells outside a free zone")
    func toggleLockOutsideFreeZone() {
        let engine = makeEngine(zones: [
            GridZoneDefinition(label: "F", rule: .forbidden,
                               rowStart: 0, rowEnd: 2, colStart: 0, colEnd: 2)
        ])
        #expect(engine.toggleLocked(at: GridCell(1, c: 1)) == .noChange)   // forbidden zone
        #expect(engine.toggleLocked(at: GridCell(5, c: 5)) == .noChange)   // no zone at all
        #expect(engine.toggleLocked(at: GridCell(-1, c: 0)) == .noChange)  // out of bounds
    }

    @Test("toggleLocked ignores occupied cells")
    func toggleLockOccupied() {
        let engine = makeEngine(zones: [freeZone(rows: 0...10, cols: 0...10)])
        let item = MockItem(type: .small, row: 2, col: 3)
        engine.registerImmediate(item)
        #expect(engine.toggleLocked(at: GridCell(2, c: 3)) == .noChange)
    }

    @Test("toggleLocked works in a side-by-side right compartment")
    func toggleLockRightBand() {
        var config = GridCanvasConfig(rows: 10, cols: 10)
        config.promoteToColumnBandsIfNeeded()
        config.splitBand(id: config.effectiveBands[0].id, atCol: 5)
        config.addZone(freeZone(rows: 0...10, cols: 5...10))
        let engine = GridEngine<MockItem>(config: config)

        // Before the band-resolution fix this was rejected because the
        // leftmost band's width capped the column at 5.
        let result = engine.toggleLocked(at: GridCell(2, c: 7))
        #expect(result == .locked(GridCell(2, c: 7)))
    }

    // MARK: - place: standard path

    @Test("place inserts on free cells and reports conflicts on occupied ones")
    func placeInsertAndConflict() {
        let engine = makeEngine()
        engine.selectedType = .small

        var inserted: [(Double, Double)] = []
        engine.place(at: GridCell(1, c: 1)) { _, r, c, _ in inserted.append((r, c)) }
        #expect(inserted.count == 1)

        let occupant = MockItem(type: .small, row: 3, col: 3)
        engine.registerImmediate(occupant)
        var conflicted: MockItem?
        engine.place(at: GridCell(3, c: 3),
                     insert: { _, _, _, _ in Issue.record("must not insert on occupied cell") },
                     onConflict: { _, item in conflicted = item })
        #expect(conflicted === occupant)
    }

    // MARK: - place: uniqueTypes

    @Test("uniqueTypes relocates the existing item instead of inserting")
    func uniqueTypesMove() {
        let engine = makeEngine()
        engine.uniqueTypes = true
        let item = MockItem(type: .small, row: 0, col: 0)
        engine.sync([item])
        engine.selectedType = .small

        engine.place(at: GridCell(4, c: 6)) { _, _, _, _ in
            Issue.record("must move the existing item, not insert")
        }
        #expect(item.anchorRow == 4)
        #expect(item.anchorCol == 6)
        #expect(engine.map[GridCell(4, c: 6)] === item)
        #expect(engine.map[GridCell(0, c: 0)] == nil)
    }

    @Test("uniqueTypes validates the move with the engine's current rotation")
    func uniqueTypesRotation() {
        let engine = makeEngine()
        engine.uniqueTypes = true
        let item = MockItem(type: .medium, row: 0, col: 0)   // 2×1
        engine.sync([item])
        engine.selectedType = .medium
        engine.rotated = true   // 1 wide × 2 tall

        // Column 9 only fits the rotated footprint. Before the fix the
        // validation used the item's old rotation (2 wide → out of
        // bounds) and the move was wrongly rejected.
        engine.place(at: GridCell(0, c: 9)) { _, _, _, _ in }
        #expect(item.anchorCol == 9)
        #expect(item.rotated)

        // The registered footprint matches the rotated shape.
        #expect(engine.map[GridCell(1.5, c: 9.5)] === item)
        #expect(engine.map[GridCell(0, c: 10)] == nil)
    }

    @Test("uniqueTypes reports the blocking occupant on conflict")
    func uniqueTypesConflict() {
        let engine = makeEngine()
        engine.uniqueTypes = true
        let mover = MockItem(type: .small, row: 0, col: 0)
        let blocker = MockItem(type: .tall, row: 4, col: 4)
        engine.sync([mover, blocker])
        engine.selectedType = .small

        var conflicted: MockItem?
        engine.place(at: GridCell(4, c: 4),
                     insert: { _, _, _, _ in Issue.record("must not insert") },
                     onConflict: { _, item in conflicted = item })
        #expect(conflicted === blocker)
        #expect(mover.anchorRow == 0 && mover.anchorCol == 0)
    }

    // MARK: - replace

    @Test("replace deletes the occupant and places the selected type")
    func replaceOccupant() {
        let engine = makeEngine()
        let occupant = MockItem(type: .small, row: 2, col: 2)
        engine.sync([occupant])
        engine.selectedType = .medium

        var deleted: MockItem?
        var inserted: [(Double, Double)] = []
        engine.replace(occupant, at: GridCell(2, c: 2),
                       onDelete: { deleted = $0 },
                       insert: { _, r, c, _ in inserted.append((r, c)) })
        #expect(deleted === occupant)
        #expect(inserted.count == 1)
        #expect(inserted.first?.0 == 2)
        #expect(inserted.first?.1 == 2)
    }

    @Test("replace without a selected type is a no-op")
    func replaceWithoutSelection() {
        let engine = makeEngine()
        let occupant = MockItem(type: .small, row: 2, col: 2)
        engine.sync([occupant])

        engine.replace(occupant, at: GridCell(2, c: 2),
                       onDelete: { _ in Issue.record("must not delete") },
                       insert: { _, _, _, _ in Issue.record("must not insert") })
        #expect(engine.map[GridCell(2, c: 2)] === occupant)
    }

    // MARK: - Stats across compartments

    @Test("totalCells excludes blocked cells in a right compartment")
    func statsRightBandBlockers() {
        var config = GridCanvasConfig(rows: 4, cols: 4)
        config.promoteToColumnBandsIfNeeded()
        config.splitBand(id: config.effectiveBands[0].id, atCol: 2)
        config.addZone(GridZoneDefinition(label: "L", rule: .locked,
                                          rowStart: 0, rowEnd: 2,
                                          colStart: 2, colEnd: 4))
        let engine = GridEngine<MockItem>(config: config)
        // 16 cells minus the 2×2 locked block in the right band.
        #expect(engine.totalCells == 12)
    }
}
