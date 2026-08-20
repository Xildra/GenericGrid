//
//  GridSlotTests.swift
//  GenericGrid Tests
//
//  Covers the fixed-slot placement model: an empty slot occupies
//  nothing, assigning moves an occupant without touching coordinates,
//  and freeing keeps the slot on the grid.
//

import Foundation
import Testing
@testable import GenericGrid

@Suite("Grid slots")
struct GridSlotTests {

    // MARK: - Helpers

    /// 4×4 grid with a free zone covering it, and a slot per whole cell.
    private func engineWithSlots() -> (GridEngine<MockSlot>, [MockSlot]) {
        var config = GridCanvasConfig(rows: 4, cols: 4)
        config.addZone(GridZoneDefinition(label: "Cabine", rule: .free,
                                          rowStart: 0, rowEnd: 4,
                                          colStart: 0, colEnd: 4))
        let engine = GridEngine<MockSlot>(config: config)
        let slots = config.freeCellSlots().map {
            MockSlot(label: $0.label, row: Double($0.row), col: Double($0.col))
        }
        return (engine, slots)
    }

    private func occupied(_ slots: [MockSlot]) -> [MockSlot] {
        slots.filter { $0.occupant != nil }
    }

    // MARK: - Occupancy

    @Test("an empty slot has no type, so it occupies no cell")
    func emptySlotIsWeightless() {
        let (engine, slots) = engineWithSlots()
        engine.sync(occupied(slots))
        #expect(engine.usedCells == 0)
        #expect(slots[0].itemType == nil)
    }

    @Test("assign fills the slot and registers it immediately")
    func assignRegisters() {
        let (engine, slots) = engineWithSlots()
        engine.assign(.small, to: slots[0])
        #expect(slots[0].occupant == .small)
        #expect(slots[0].itemType == .small)
        #expect(engine.map[GridCell(0, c: 0)] === slots[0])
    }

    @Test("free empties the slot but keeps it on the grid")
    func freeKeepsSlot() {
        let (engine, slots) = engineWithSlots()
        engine.assign(.small, to: slots[0])
        engine.free(slots[0])
        #expect(slots[0].occupant == nil)
        #expect(engine.map[GridCell(0, c: 0)] == nil)
        #expect(slots[0].anchorRow == 0)   // la place n'a pas bougé
    }

    // MARK: - One occupant, one slot

    @Test("assigning elsewhere frees the previous slot")
    func assignReleasesPrevious() {
        let (engine, slots) = engineWithSlots()
        engine.assign(.small, to: slots[0])
        engine.assign(.small, to: slots[5])
        #expect(slots[0].occupant == nil)
        #expect(slots[5].occupant == .small)
        #expect(engine.map[GridCell(0, c: 0)] == nil)
        #expect(engine.usedCells == 1)
    }

    @Test("re-assigning the same slot is a no-op")
    func assignSameSlot() {
        let (engine, slots) = engineWithSlots()
        engine.assign(.small, to: slots[0])
        engine.assign(.small, to: slots[0])
        #expect(slots[0].occupant == .small)
        #expect(engine.usedCells == 1)
    }

    @Test("slot(occupiedBy:) finds the occupied slot, and only it")
    func slotLookup() {
        let (engine, slots) = engineWithSlots()
        #expect(engine.slot(occupiedBy: .small) == nil)
        engine.assign(.small, to: slots[3])
        #expect(engine.slot(occupiedBy: .small) === slots[3])
        #expect(engine.slot(occupiedBy: .medium) == nil)
    }

    // MARK: - Coordinates

    @Test("a slot ignores anchor writes")
    func anchorsAreFixed() {
        let (_, slots) = engineWithSlots()
        let slot = slots[5]
        let row = slot.anchorRow, col = slot.anchorCol
        slot.anchorRow = 99
        slot.anchorCol = 99
        #expect(slot.anchorRow == row)
        #expect(slot.anchorCol == col)
    }

    @Test("assign carries rotation onto the slot")
    func assignRotates() {
        let (engine, slots) = engineWithSlots()
        engine.assign(.medium, to: slots[0], rotated: true)
        #expect(slots[0].rotated)
        #expect(slots[0].effectiveWidth == 1)
        #expect(slots[0].effectiveHeight == 2)
    }

    // MARK: - Statistiques

    @Test("stats count occupied slots only")
    func statsIgnoreFreeSlots() {
        let (engine, slots) = engineWithSlots()
        engine.assign(.small, to: slots[0])
        engine.assign(.medium, to: slots[2])
        engine.sync(occupied(slots))
        #expect(engine.usedCells == 3)      // 1×1 + 2×1
        #expect(engine.totalCells == 16)
        #expect(engine.freeCells == 13)
    }
}
