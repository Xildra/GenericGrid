//
//  GridEngineTests.swift
//  GenericGrid Tests
//

import Testing
@testable import GenericGrid

@Suite("GridEngine")
struct GridEngineTests {

    // MARK: - Helpers

    private func makeEngine(rows: Int = 10, cols: Int = 10,
                            zones: [GridZoneDefinition] = []) -> GridEngine<MockItem> {
        let config = GridCanvasConfig(rows: rows, cols: cols, zones: zones)
        return GridEngine(config: config)
    }

    // MARK: - Init

    @Test("engine initialises with config dimensions")
    func initDimensions() {
        let engine = makeEngine(rows: 5, cols: 8)
        #expect(engine.rows == 5)
        #expect(engine.cols == 8)
    }

    @Test("config update resets rows and cols")
    func configUpdate() {
        let engine = makeEngine(rows: 5, cols: 5)
        engine.config = GridCanvasConfig(rows: 12, cols: 20)
        #expect(engine.rows == 12)
        #expect(engine.cols == 20)
    }

    // MARK: - Footprint

    @Test("footprint for 1×1 item produces 4 sub-cells")
    func footprintSmall() {
        let engine = makeEngine()
        let cells = engine.footprint(anchor: GridCell(0, c: 0), type: .small, rotated: false)
        #expect(cells.count == 4)
    }

    @Test("footprint for 2×2 item produces 16 sub-cells")
    func footprintLarge() {
        let engine = makeEngine()
        let cells = engine.footprint(anchor: GridCell(0, c: 0), type: .large, rotated: false)
        #expect(cells.count == 16)
    }

    @Test("footprint for rotated item swaps dimensions")
    func footprintRotated() {
        let engine = makeEngine()
        let normal  = engine.footprint(anchor: GridCell(0, c: 0), type: .medium, rotated: false) // 2×1 → 8
        let rotated = engine.footprint(anchor: GridCell(0, c: 0), type: .medium, rotated: true)  // 1×2 → 8
        #expect(normal.count == rotated.count)

        // Normal: cols 0..1.5, rows 0..0.5
        let normalMaxC = normal.map(\.c).max()!
        let rotatedMaxR = rotated.map(\.r).max()!
        #expect(normalMaxC == 1.5)  // 2 wide → sub-cells up to 1.5
        #expect(rotatedMaxR == 1.5) // 2 tall → sub-cells up to 1.5
    }

    @Test("footprint at half-cell offset")
    func footprintOffset() {
        let engine = makeEngine()
        let cells = engine.footprint(anchor: GridCell(2.5, c: 3.5), type: .small, rotated: false)
        #expect(cells.count == 4)
        let minR = cells.map(\.r).min()!
        let minC = cells.map(\.c).min()!
        #expect(minR == 2.5)
        #expect(minC == 3.5)
    }

    // MARK: - canPlace

    @Test("canPlace allows valid empty position")
    func canPlaceValid() {
        let engine = makeEngine()
        #expect(engine.canPlace(anchor: GridCell(0, c: 0), type: .small, rotated: false))
        #expect(engine.canPlace(anchor: GridCell(5, c: 5), type: .large, rotated: false))
    }

    @Test("canPlace rejects out-of-bounds placement")
    func canPlaceOutOfBounds() {
        let engine = makeEngine(rows: 5, cols: 5)
        // 2×2 item at (4, 4) → extends to (6, 6)
        #expect(!engine.canPlace(anchor: GridCell(4, c: 4), type: .large, rotated: false))
        // At boundary
        #expect(engine.canPlace(anchor: GridCell(3, c: 3), type: .large, rotated: false))
    }

    @Test("canPlace rejects occupied position")
    func canPlaceOccupied() {
        let engine = makeEngine()
        let item = MockItem(type: .small, row: 0, col: 0)
        engine.sync([item])
        #expect(!engine.canPlace(anchor: GridCell(0, c: 0), type: .small, rotated: false))
    }

    @Test("canPlace allows position with exclusion")
    func canPlaceWithExclusion() {
        let engine = makeEngine()
        let item = MockItem(type: .small, row: 0, col: 0)
        engine.sync([item])
        #expect(engine.canPlace(anchor: GridCell(0, c: 0), type: .small, rotated: false, excluding: item))
    }

    @Test("canPlace rejects locked zone")
    func canPlaceLockedZone() {
        let zone = GridZoneDefinition(label: "Lock", rule: .locked, rowStart: 0, rowEnd: 3, colStart: 0, colEnd: 3)
        let engine = makeEngine(zones: [zone])
        #expect(!engine.canPlace(anchor: GridCell(1, c: 1), type: .small, rotated: false))
    }

    @Test("canPlace rejects forbidden zone")
    func canPlaceForbiddenZone() {
        let zone = GridZoneDefinition(label: "No", rule: .forbidden, rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5)
        let engine = makeEngine(zones: [zone])
        #expect(!engine.canPlace(anchor: GridCell(2, c: 2), type: .small, rotated: false))
    }

    @Test("canPlace respects restricted zone")
    func canPlaceRestrictedZone() {
        let zone = GridZoneDefinition(
            label: "R", rule: .restricted,
            rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5,
            allowedTypeNames: ["Small"]
        )
        let engine = makeEngine(zones: [zone])
        #expect(engine.canPlace(anchor: GridCell(1, c: 1), type: .small, rotated: false))
        #expect(!engine.canPlace(anchor: GridCell(1, c: 1), type: .medium, rotated: false))
    }

    // MARK: - Sync & Map

    @Test("sync builds occupancy map")
    func syncBuildsMap() {
        let engine = makeEngine()
        let item = MockItem(type: .small, row: 2, col: 3)
        engine.sync([item])
        #expect(engine.map[GridCell(2.0, c: 3.0)] === item)
        #expect(engine.map[GridCell(2.0, c: 3.5)] === item)
        #expect(engine.map[GridCell(2.5, c: 3.0)] === item)
        #expect(engine.map[GridCell(2.5, c: 3.5)] === item)
    }

    @Test("sync replaces previous map")
    func syncReplacesMap() {
        let engine = makeEngine()
        let item1 = MockItem(type: .small, row: 0, col: 0)
        engine.sync([item1])
        #expect(engine.map.count == 4)

        engine.sync([]) // clear
        #expect(engine.map.isEmpty)
    }

    @Test("registerImmediate adds to map")
    func registerImmediate() {
        let engine = makeEngine()
        let item = MockItem(type: .small, row: 0, col: 0)
        engine.registerImmediate(item)
        #expect(engine.map[GridCell(0, c: 0)] === item)
    }

    @Test("unregisterImmediate removes from map")
    func unregisterImmediate() {
        let engine = makeEngine()
        let item = MockItem(type: .small, row: 0, col: 0)
        engine.registerImmediate(item)
        engine.unregisterImmediate(item)
        #expect(engine.map[GridCell(0, c: 0)] == nil)
    }

    // MARK: - Place

    @Test("place calls insert on valid empty position")
    func placeValid() {
        let engine = makeEngine()
        engine.selectedType = .small
        var inserted = false
        engine.place(at: GridCell(1, c: 1), insert: { type, r, c, rot in
            inserted = true
            #expect(type.name == "Small")
            #expect(r == 1.0)
            #expect(c == 1.0)
            #expect(rot == false)
        })
        #expect(inserted)
    }

    @Test("place does nothing without selectedType")
    func placeNoSelection() {
        let engine = makeEngine()
        engine.selectedType = nil
        var inserted = false
        engine.place(at: GridCell(0, c: 0), insert: { _, _, _, _ in inserted = true })
        #expect(!inserted)
    }

    @Test("place does nothing when out of bounds")
    func placeOutOfBounds() {
        let engine = makeEngine(rows: 2, cols: 2)
        engine.selectedType = .large // 2×2 at (1,1) → out of bounds
        var inserted = false
        engine.place(at: GridCell(1, c: 1), insert: { _, _, _, _ in inserted = true })
        #expect(!inserted)
    }

    @Test("place calls onConflict when occupied")
    func placeConflict() {
        let engine = makeEngine()
        let existing = MockItem(type: .small, row: 0, col: 0)
        engine.sync([existing])
        engine.selectedType = .small

        var conflictCalled = false
        engine.place(at: GridCell(0, c: 0), insert: { _, _, _, _ in },
                     onConflict: { cell, item in
            conflictCalled = true
            #expect(item === existing)
        })
        #expect(conflictCalled)
    }

    @Test("place silently fails when occupied and no conflict handler")
    func placeOccupiedSilent() {
        let engine = makeEngine()
        let existing = MockItem(type: .small, row: 0, col: 0)
        engine.sync([existing])
        engine.selectedType = .small
        var inserted = false
        engine.place(at: GridCell(0, c: 0), insert: { _, _, _, _ in inserted = true })
        #expect(!inserted)
    }

    @Test("place respects zone rules")
    func placeZoneRules() {
        let zone = GridZoneDefinition(label: "No", rule: .forbidden, rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5)
        let engine = makeEngine(zones: [zone])
        engine.selectedType = .small
        var inserted = false
        engine.place(at: GridCell(1, c: 1), insert: { _, _, _, _ in inserted = true })
        #expect(!inserted)
    }

    // MARK: - Move

    @Test("beginMove sets interaction to moving")
    func beginMove() {
        let engine = makeEngine()
        let item = MockItem(type: .small, row: 1, col: 1)
        engine.sync([item])
        engine.beginMove(item: item, at: GridCell(1, c: 1))
        if case .moving(let movedItem, _, _) = engine.interaction {
            #expect(movedItem === item)
        } else {
            Issue.record("Expected .moving interaction")
        }
    }

    @Test("beginMove does nothing in locked zone")
    func beginMoveLockedZone() {
        let zone = GridZoneDefinition(label: "L", rule: .locked, rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5)
        let engine = makeEngine(zones: [zone])
        let item = MockItem(type: .small, row: 1, col: 1)
        engine.sync([item])
        engine.beginMove(item: item, at: GridCell(1, c: 1))
        if case .idle = engine.interaction {
            // expected
        } else {
            Issue.record("Expected .idle interaction after locked zone beginMove")
        }
    }

    @Test("commitMove updates item position on valid target")
    func commitMoveValid() {
        let engine = makeEngine()
        let item = MockItem(type: .small, row: 0, col: 0)
        engine.sync([item])
        engine.beginMove(item: item, at: GridCell(0, c: 0))
        engine.updateMove(to: GridCell(3, c: 3))
        engine.commitMove()
        #expect(item.anchorRow == 3.0)
        #expect(item.anchorCol == 3.0)
        if case .idle = engine.interaction { } else {
            Issue.record("Expected .idle after commitMove")
        }
    }

    @Test("commitMove reverts on invalid target")
    func commitMoveInvalid() {
        let engine = makeEngine(rows: 3, cols: 3)
        let item = MockItem(type: .small, row: 0, col: 0)
        engine.sync([item])
        engine.beginMove(item: item, at: GridCell(0, c: 0))
        engine.updateMove(to: GridCell(5, c: 5)) // out of bounds
        engine.commitMove()
        // Position unchanged
        #expect(item.anchorRow == 0.0)
        #expect(item.anchorCol == 0.0)
    }

    @Test("cancelInteraction resets to idle")
    func cancelInteraction() {
        let engine = makeEngine()
        engine.interaction = .previewing(anchor: GridCell(0, c: 0))
        engine.cancelInteraction()
        if case .idle = engine.interaction { } else {
            Issue.record("Expected .idle after cancel")
        }
    }

    // MARK: - Statistics

    @Test("stats are correct for empty grid")
    func statsEmpty() {
        let engine = makeEngine(rows: 5, cols: 5)
        #expect(engine.usedCells == 0)
        #expect(engine.totalCells == 25)
        #expect(engine.freeCells == 25)
        #expect(engine.fillPct == 0)
    }

    @Test("stats update after sync")
    func statsAfterSync() {
        let engine = makeEngine(rows: 10, cols: 10)
        let item = MockItem(type: .small, row: 0, col: 0) // occupies 4 sub-cells
        engine.sync([item])
        #expect(engine.usedCells == 4)
        #expect(engine.freeCells == 96)
    }

    // MARK: - Preview

    @Test("previewCells empty when idle")
    func previewIdle() {
        let engine = makeEngine()
        #expect(engine.previewCells.isEmpty)
    }

    @Test("previewCells populated when previewing")
    func previewPopulated() {
        let engine = makeEngine()
        engine.selectedType = .small
        engine.interaction = .previewing(anchor: GridCell(1, c: 1))
        #expect(engine.previewCells.count == 4)
    }

    @Test("isPreviewValid reflects placement validity")
    func previewValid() {
        let engine = makeEngine()
        engine.selectedType = .small
        engine.interaction = .previewing(anchor: GridCell(0, c: 0))
        #expect(engine.isPreviewValid)
    }

    @Test("isPreviewValid false when out of bounds")
    func previewInvalidBounds() {
        let engine = makeEngine(rows: 2, cols: 2)
        engine.selectedType = .large // 2×2 at (1,1) goes OOB
        engine.interaction = .previewing(anchor: GridCell(1, c: 1))
        #expect(!engine.isPreviewValid)
    }

    @Test("movingItem returns item during move")
    func movingItem() {
        let engine = makeEngine()
        let item = MockItem(type: .small, row: 0, col: 0)
        engine.sync([item])
        #expect(engine.movingItem == nil)
        engine.beginMove(item: item, at: GridCell(0, c: 0))
        #expect(engine.movingItem === item)
    }
}
