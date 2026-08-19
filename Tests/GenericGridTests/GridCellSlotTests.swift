//
//  GridCellSlotTests.swift
//  GenericGrid Tests
//
//  Covers the whole-cell enumeration used to mirror a config into a
//  consumer's own position model: which cells count as available,
//  their labels, and their ordering across compartments.
//

import Foundation
import Testing
@testable import GenericGrid

@Suite("Cell slots")
struct GridCellSlotTests {

    // MARK: - Helpers

    /// 4×4 grid with a 2×2 `.free` zone at the top-left corner.
    private func freeCorner() -> GridCanvasConfig {
        var config = GridCanvasConfig(rows: 4, cols: 4,
                                      rowLabels: ["10", "11", "12", "13"])
        config.addZone(GridZoneDefinition(label: "Cabine", rule: .free,
                                          rowStart: 0, rowEnd: 2,
                                          colStart: 0, colEnd: 2))
        return config
    }

    // MARK: - Labels

    @Test("cellLabel combines row and column labels")
    func cellLabel() {
        let config = freeCorner()
        #expect(config.cellLabel(row: 0, col: 0) == "10A")
        #expect(config.cellLabel(row: 2, col: 3) == "12D")
    }

    @Test("free cells expose the zone that owns them")
    func slotCarriesZone() {
        let config = freeCorner()
        let slots = config.freeCellSlots()
        #expect(slots.allSatisfy { $0.zoneLabel == "Cabine" })
        #expect(slots.first?.cell == GridCell(0, c: 0))
    }

    // MARK: - Availability

    @Test("only cells covered by a .free zone are returned")
    func freeCellsOnly() {
        let config = freeCorner()
        #expect(config.freeCellLabels() == ["10A", "10B", "11A", "11B"])
    }

    @Test("locked, forbidden and restricted zones are excluded")
    func blockingRulesExcluded() {
        var config = GridCanvasConfig(rows: 1, cols: 4)
        for (i, rule) in [ZoneRule.free, .locked, .forbidden, .restricted].enumerated() {
            config.addZone(GridZoneDefinition(label: "\(rule)", rule: rule,
                                              rowStart: 0, rowEnd: 1,
                                              colStart: Double(i), colEnd: Double(i + 1)))
        }
        #expect(config.freeCellLabels() == ["1A"])
    }

    @Test("a runtime lock dropped on a free zone removes the cell")
    func runtimeLockWins() {
        var config = freeCorner()
        config.addZone(GridZoneDefinition(label: "Verrou", rule: .locked,
                                          rowStart: 1, rowEnd: 2,
                                          colStart: 1, colEnd: 2),
                       prepend: true)
        #expect(config.freeCellLabels() == ["10A", "10B", "11A"])
    }

    @Test("unzoned cells are opt-in")
    func unzonedOptIn() {
        let config = freeCorner()
        #expect(config.freeCellSlots().count == 4)
        let all = config.freeCellSlots(includingUnzoned: true)
        #expect(all.count == 16)
        #expect(all.first(where: { $0.label == "13D" })?.zoneID == nil)
    }

    // MARK: - Compartments

    @Test("cells are ordered row by row across side-by-side compartments")
    func readingOrderAcrossBands() {
        var config = GridCanvasConfig(rows: 2, cols: 4)
        config.promoteToColumnBandsIfNeeded()
        config.splitBand(id: config.effectiveBands[0].id, atCol: 2)
        let labels = config.freeCellSlots(includingUnzoned: true).map(\.label)
        #expect(labels == ["1A", "1B", "1A", "1B", "2A", "2B", "2A", "2B"])
        let cols = config.freeCellSlots(includingUnzoned: true).map(\.col)
        #expect(cols == [0, 1, 2, 3, 0, 1, 2, 3])
    }

    @Test("compartment labels and subdivision overrides drive the columns")
    func bandLabelsAndSubdivisions() {
        var config = GridCanvasConfig(
            rows: 1, cols: 4,
            columnBands: [ColumnBand(rowStart: 0, rowEnd: 0,
                                     colStart: 0, colEnd: 3,
                                     labels: ["W", "X", "Y"],
                                     cols: 3)])
        #expect(config.freeCellLabels(includingUnzoned: true) == ["1W", "1X", "1Y"])
        // The 3 subdivisions live at absolute columns 0, 1, 2.
        config.addZone(GridZoneDefinition(label: "F", rule: .free,
                                          rowStart: 0, rowEnd: 1,
                                          colStart: 1, colEnd: 3))
        #expect(config.freeCellLabels() == ["1X", "1Y"])
    }

    // MARK: - Identity

    @Test("slots are stable across calls")
    func stableIdentity() {
        let config = freeCorner()
        #expect(config.freeCellSlots() == config.freeCellSlots())
        #expect(config.freeCellSlots().first?.id == "0x0")
    }
}
