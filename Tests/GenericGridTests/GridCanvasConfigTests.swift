//
//  GridCanvasConfigTests.swift
//  GenericGrid Tests
//

import Testing
import Foundation
@testable import GenericGrid

@Suite("GridCanvasConfig")
struct GridCanvasConfigTests {

    // MARK: - Init & Defaults

    @Test("default config has correct dimensions")
    func defaultConfig() {
        let config = GridCanvasConfig.default
        #expect(config.rows == GridDefaults.rows)
        #expect(config.cols == GridDefaults.cols)
        #expect(config.zones.isEmpty)
        #expect(config.title == "Empty grid")
    }

    @Test("custom init stores values")
    func customInit() {
        let config = GridCanvasConfig(rows: 5, cols: 8, title: "Test")
        #expect(config.rows == 5)
        #expect(config.cols == 8)
        #expect(config.title == "Test")
        #expect(config.rowLabels == nil)
        #expect(config.colLabels == nil)
    }

    // MARK: - Row labels

    @Test("rowLabel falls back to 1-based index")
    func rowLabelDefault() {
        let config = GridCanvasConfig(rows: 3, cols: 3)
        #expect(config.rowLabel(at: 0) == "1")
        #expect(config.rowLabel(at: 1) == "2")
        #expect(config.rowLabel(at: 2) == "3")
    }

    @Test("rowLabel uses custom labels when provided")
    func rowLabelCustom() {
        let config = GridCanvasConfig(rows: 3, cols: 3, rowLabels: ["A", "B", "C"])
        #expect(config.rowLabel(at: 0) == "A")
        #expect(config.rowLabel(at: 1) == "B")
        #expect(config.rowLabel(at: 2) == "C")
    }

    @Test("rowLabel falls back for out-of-range index")
    func rowLabelOutOfRange() {
        let config = GridCanvasConfig(rows: 5, cols: 3, rowLabels: ["X"])
        #expect(config.rowLabel(at: 0) == "X")
        #expect(config.rowLabel(at: 1) == "2") // fallback
    }

    // MARK: - Column labels

    @Test("colLabel falls back to A, B, C…")
    func colLabelDefault() {
        let config = GridCanvasConfig(rows: 3, cols: 5)
        #expect(config.colLabel(at: 0) == "A")
        #expect(config.colLabel(at: 1) == "B")
        #expect(config.colLabel(at: 4) == "E")
        #expect(config.colLabel(at: 25) == "Z")
    }

    @Test("colLabel falls back to index for >= 26")
    func colLabelBeyondAlphabet() {
        let config = GridCanvasConfig(rows: 1, cols: 30)
        #expect(config.colLabel(at: 26) == "26")
        #expect(config.colLabel(at: 29) == "29")
    }

    @Test("colLabel uses custom labels")
    func colLabelCustom() {
        let config = GridCanvasConfig(rows: 1, cols: 3, colLabels: ["L", "M", "R"])
        #expect(config.colLabel(at: 0) == "L")
        #expect(config.colLabel(at: 2) == "R")
    }

    // MARK: - Zone queries

    @Test("zone(at:) returns matching zone")
    func zoneAtCell() {
        let zone = GridZoneDefinition(label: "Z1", rowStart: 0, rowEnd: 3, colStart: 0, colEnd: 4)
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [zone])
        let found = config.zone(at: GridCell(1.0, c: 2.0))
        #expect(found?.label == "Z1")
    }

    @Test("zone(at:) returns nil outside zones")
    func zoneAtCellNil() {
        let zone = GridZoneDefinition(label: "Z1", rowStart: 0, rowEnd: 2, colStart: 0, colEnd: 2)
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [zone])
        #expect(config.zone(at: GridCell(5.0, c: 5.0)) == nil)
    }

    @Test("zone(at:) returns first matching zone when overlapping")
    func zoneAtOverlapping() {
        let z1 = GridZoneDefinition(label: "First", rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5)
        let z2 = GridZoneDefinition(label: "Second", rowStart: 2, rowEnd: 8, colStart: 2, colEnd: 8)
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [z1, z2])
        let found = config.zone(at: GridCell(3.0, c: 3.0))
        #expect(found?.label == "First")
    }

    // MARK: - canAccept

    @Test("canAccept returns true outside any zone")
    func canAcceptFreeArea() {
        let config = GridCanvasConfig(rows: 10, cols: 10)
        #expect(config.canAccept(cell: GridCell(5.0, c: 5.0), typeName: "Any"))
    }

    @Test("canAccept returns true in free zone")
    func canAcceptFreeZone() {
        let zone = GridZoneDefinition(label: "Free", rule: .free, rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5)
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [zone])
        #expect(config.canAccept(cell: GridCell(2.0, c: 2.0), typeName: "Any"))
    }

    @Test("canAccept returns false in locked zone")
    func canAcceptLocked() {
        let zone = GridZoneDefinition(label: "Locked", rule: .locked, rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5)
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [zone])
        #expect(!config.canAccept(cell: GridCell(2.0, c: 2.0), typeName: "Any"))
    }

    @Test("canAccept returns false in forbidden zone")
    func canAcceptForbidden() {
        let zone = GridZoneDefinition(label: "No", rule: .forbidden, rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5)
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [zone])
        #expect(!config.canAccept(cell: GridCell(1.0, c: 1.0), typeName: "Anything"))
    }

    @Test("canAccept in restricted zone allows listed type")
    func canAcceptRestrictedAllowed() {
        let zone = GridZoneDefinition(
            label: "VIP", rule: .restricted,
            rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5,
            allowedTypeNames: ["Business", "First"]
        )
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [zone])
        #expect(config.canAccept(cell: GridCell(1.0, c: 1.0), typeName: "Business"))
        #expect(config.canAccept(cell: GridCell(1.0, c: 1.0), typeName: "First"))
    }

    @Test("canAccept in restricted zone rejects unlisted type")
    func canAcceptRestrictedRejected() {
        let zone = GridZoneDefinition(
            label: "VIP", rule: .restricted,
            rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5,
            allowedTypeNames: ["Business"]
        )
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [zone])
        #expect(!config.canAccept(cell: GridCell(1.0, c: 1.0), typeName: "Economy"))
    }

    @Test("canAccept in restricted zone rejects nil typeName")
    func canAcceptRestrictedNilType() {
        let zone = GridZoneDefinition(
            label: "VIP", rule: .restricted,
            rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 5,
            allowedTypeNames: ["Business"]
        )
        let config = GridCanvasConfig(rows: 10, cols: 10, zones: [zone])
        #expect(!config.canAccept(cell: GridCell(1.0, c: 1.0), typeName: nil))
    }

    // MARK: - Codable

    @Test("config round-trips through JSON")
    func codableRoundTrip() throws {
        let zone = GridZoneDefinition(label: "Z", rule: .locked, rowEnd: 3, colEnd: 4)
        let original = GridCanvasConfig(
            rows: 8, cols: 12,
            zones: [zone],
            title: "Test Config",
            rowLabels: ["1", "2", "3", "4", "5", "6", "7", "8"],
            colLabels: nil
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GridCanvasConfig.self, from: data)

        #expect(decoded.rows == 8)
        #expect(decoded.cols == 12)
        #expect(decoded.title == "Test Config")
        #expect(decoded.zones.count == 1)
        #expect(decoded.zones[0].label == "Z")
        #expect(decoded.zones[0].rule == .locked)
        #expect(decoded.rowLabels?.count == 8)
        #expect(decoded.colLabels == nil)
    }
}
