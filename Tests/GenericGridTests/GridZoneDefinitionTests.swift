//
//  GridZoneDefinitionTests.swift
//  GenericGrid Tests
//

import Testing
import SwiftUI
@testable import GenericGrid

@Suite("GridZoneDefinition")
struct GridZoneDefinitionTests {

    // MARK: - Init

    @Test("default init creates valid zone")
    func defaultInit() {
        let zone = GridZoneDefinition(rowEnd: 3, colEnd: 4)
        #expect(zone.label == "New Zone")
        #expect(zone.rule == .free)
        #expect(zone.rowStart == 0)
        #expect(zone.rowEnd == 3)
        #expect(zone.colStart == 0)
        #expect(zone.colEnd == 4)
        #expect(zone.allowedTypeNames == nil)
    }

    @Test("custom init stores all values")
    func customInit() {
        let zone = GridZoneDefinition(
            label: "VIP", rule: .restricted,
            rowStart: 1.5, rowEnd: 4, colStart: 2, colEnd: 6,
            color: .blue, allowedTypeNames: ["Business"]
        )
        #expect(zone.label == "VIP")
        #expect(zone.rule == .restricted)
        #expect(zone.rowStart == 1.5)
        #expect(zone.colStart == 2)
        #expect(zone.allowedTypeNames == ["Business"])
    }

    // MARK: - Contains

    @Test("contains returns true for cell inside zone")
    func containsInside() {
        let zone = GridZoneDefinition(rowStart: 1, rowEnd: 5, colStart: 2, colEnd: 8)
        #expect(zone.contains(GridCell(1.0, c: 2.0)))
        #expect(zone.contains(GridCell(2.5, c: 4.0)))
        #expect(zone.contains(GridCell(4.5, c: 7.5)))
    }

    @Test("contains returns false for cell outside zone")
    func containsOutside() {
        let zone = GridZoneDefinition(rowStart: 1, rowEnd: 3, colStart: 2, colEnd: 5)
        // Before zone
        #expect(!zone.contains(GridCell(0.0, c: 2.0)))
        #expect(!zone.contains(GridCell(1.0, c: 1.0)))
        // After zone (cell.r + 0.5 > rowEnd)
        #expect(!zone.contains(GridCell(3.0, c: 2.0)))
        // After zone (cell.c + 0.5 > colEnd)
        #expect(!zone.contains(GridCell(1.0, c: 5.0)))
    }

    @Test("contains respects half-cell boundary")
    func containsHalfCell() {
        let zone = GridZoneDefinition(rowStart: 0, rowEnd: 2.5, colStart: 0, colEnd: 3)
        // Cell at 2.0 → 2.0 + 0.5 = 2.5 <= 2.5 ✓
        #expect(zone.contains(GridCell(2.0, c: 0.0)))
        // Cell at 2.5 → 2.5 + 0.5 = 3.0 > 2.5 ✗
        #expect(!zone.contains(GridCell(2.5, c: 0.0)))
    }

    // MARK: - Color

    @Test("color getter returns default gray when no hex")
    func colorDefaultGray() {
        var zone = GridZoneDefinition(rowEnd: 1, colEnd: 1)
        zone.colorHex = nil
        #expect(zone.color == .gray)
    }

    @Test("color setter updates colorHex")
    func colorSetter() {
        var zone = GridZoneDefinition(rowEnd: 1, colEnd: 1, color: .red)
        let hex1 = zone.colorHex
        zone.color = .blue
        let hex2 = zone.colorHex
        #expect(hex1 != hex2)
        #expect(hex2 != nil)
    }

    // MARK: - Codable

    @Test("zone round-trips through JSON")
    func codableRoundTrip() throws {
        let original = GridZoneDefinition(
            label: "Test", rule: .locked,
            rowStart: 0.5, rowEnd: 3, colStart: 1, colEnd: 5.5,
            color: .orange, allowedTypeNames: nil
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GridZoneDefinition.self, from: data)

        #expect(decoded.label == original.label)
        #expect(decoded.rule == original.rule)
        #expect(decoded.rowStart == original.rowStart)
        #expect(decoded.rowEnd == original.rowEnd)
        #expect(decoded.colStart == original.colStart)
        #expect(decoded.colEnd == original.colEnd)
        #expect(decoded.colorHex == original.colorHex)
    }

    // MARK: - Identifiable / Hashable

    @Test("each zone has a unique id")
    func uniqueId() {
        let a = GridZoneDefinition(rowEnd: 1, colEnd: 1)
        let b = GridZoneDefinition(rowEnd: 1, colEnd: 1)
        #expect(a.id != b.id)
    }
}
