//
//  GridCoordinateSpaceTests.swift
//  GenericGrid Tests
//
//  Pins down the absolute coordinate convention: zone lookups across
//  side-by-side compartments, point-to-cell hit-testing, and the
//  schemaVersion migration of legacy band-local zone columns.
//

import Foundation
import Testing
@testable import GenericGrid

@Suite("Coordinate space")
struct GridCoordinateSpaceTests {

    // MARK: - Helpers

    /// 10×10 grid split vertically at column 5.
    private func sideBySide() -> GridCanvasConfig {
        var config = GridCanvasConfig(rows: 10, cols: 10)
        config.promoteToColumnBandsIfNeeded()
        config.splitBand(id: config.effectiveBands[0].id, atCol: 5)
        return config
    }

    // MARK: - Zone lookups across side-by-side bands

    @Test("zone(at:) does not leak a right-band zone into the left band")
    func zoneLookupRightBand() {
        var config = sideBySide()
        config.addZone(GridZoneDefinition(label: "R", rule: .forbidden,
                                          rowStart: 2, rowEnd: 5,
                                          colStart: 5, colEnd: 8))
        // Same (row, col-offset) in the left band: no zone there.
        #expect(config.zone(at: GridCell(3, c: 1)) == nil)
        // Inside the right-band zone.
        #expect(config.zone(at: GridCell(3, c: 6))?.label == "R")
    }

    @Test("canAccept honours zones in non-leftmost compartments")
    func canAcceptRightBand() {
        var config = sideBySide()
        config.addZone(GridZoneDefinition(label: "R", rule: .forbidden,
                                          rowStart: 0, rowEnd: 10,
                                          colStart: 5, colEnd: 10))
        #expect(config.canAccept(cell: GridCell(4, c: 2), typeName: "Small"))
        #expect(!config.canAccept(cell: GridCell(4, c: 7), typeName: "Small"))
    }

    // MARK: - Hit testing

    @Test("cell(at:) resolves taps in both side-by-side compartments")
    func hitTestSideBySide() {
        let config = sideBySide()
        let cs: CGFloat = 10
        // Left band: x = 21 → col 2.0 after half-cell snap.
        let left = config.cell(at: CGPoint(x: 21, y: 35), cellSize: cs)
        #expect(left == GridCell(3.5, c: 2))
        // Right band: x = 72 → col 7.0. Before the fix this returned
        // nil because the leftmost band's width capped the column.
        let right = config.cell(at: CGPoint(x: 72, y: 35), cellSize: cs)
        #expect(right == GridCell(3.5, c: 7))
    }

    @Test("cell(at:) accounts for a subdivision override in the right band")
    func hitTestOverride() {
        var config = sideBySide()
        let right = config.effectiveBands[1]
        config.setBandCols(id: right.id, cols: 2)   // 2 subdivisions over 5 natural cols
        let cs: CGFloat = 10
        // Right band spans x 50…100; each subdivision is 25 pt.
        // x = 76 → local 1.04 → snapped to half-steps → 1.0 → col 6.
        let cell = config.cell(at: CGPoint(x: 76, y: 2), cellSize: cs)
        #expect(cell == GridCell(0, c: 6))
    }

    @Test("cell(at:) rejects points outside the grid")
    func hitTestOutside() {
        let config = sideBySide()
        #expect(config.cell(at: CGPoint(x: -4, y: 10), cellSize: 10) == nil)
        #expect(config.cell(at: CGPoint(x: 10, y: 240), cellSize: 10) == nil)
    }

    @Test("cell(at:) rejects intermediate compartment header strips")
    func hitTestHeaderStrip() {
        var config = GridCanvasConfig(rows: 10, cols: 10)
        config.promoteToColumnBandsIfNeeded()
        config.splitBand(at: 5)
        let cs: CGFloat = 10
        // Visual layout: rows 0–4, then one header slot, then rows 5–9.
        // y = 55 falls inside the header strip.
        #expect(config.cell(at: CGPoint(x: 10, y: 55), cellSize: cs) == nil)
        // y = 65 is the first data row of the second strip → row 5.
        #expect(config.cell(at: CGPoint(x: 10, y: 65), cellSize: cs) == GridCell(5.5, c: 1))
    }

    @Test("snap uses the owning zone's unit grid")
    func snapZoneLocal() {
        var config = GridCanvasConfig(rows: 10, cols: 10)
        config.addZone(GridZoneDefinition(label: "Z", rule: .free,
                                          rowStart: 1.5, rowEnd: 4.5,
                                          colStart: 2.5, colEnd: 5.5))
        // Inside the zone: snaps to the zone's own origin-aligned grid.
        let snapped = config.snap(GridCell(2.9, c: 4.1))
        #expect(snapped == GridCell(2.5, c: 3.5))
        // Outside any zone: falls back to the half-cell guide.
        #expect(config.snap(GridCell(7.3, c: 8.6)) == GridCell(7.5, c: 8.5))
    }

    // MARK: - Schema migration

    private func decode(_ json: String) throws -> GridCanvasConfig {
        try JSONDecoder().decode(GridCanvasConfig.self, from: Data(json.utf8))
    }

    @Test("legacy files re-base band-local zone columns to absolute")
    func legacyMigration() throws {
        let json = """
        {
          "rows": 10, "cols": 10,
          "columnBands": [
            { "rowStart": 0, "rowEnd": 9, "colStart": 0, "colEnd": 4, "zones": [] },
            { "rowStart": 0, "rowEnd": 9, "colStart": 5, "colEnd": 9, "zones": [
              { "id": "11111111-1111-1111-1111-111111111111",
                "label": "R", "rule": "free",
                "rowStart": 2, "rowEnd": 4, "colStart": 1, "colEnd": 3 }
            ] }
          ]
        }
        """
        let config = try decode(json)
        let zone = config.effectiveBands[1].zones[0]
        #expect(zone.colStart == 6)   // 1 + colStart 5
        #expect(zone.colEnd == 8)
        #expect(zone.rowStart == 2)   // rows were already absolute
    }

    @Test("version-2 files decode without re-basing")
    func currentVersionNoMigration() throws {
        let json = """
        {
          "schemaVersion": 2,
          "rows": 10, "cols": 10,
          "columnBands": [
            { "rowStart": 0, "rowEnd": 9, "colStart": 0, "colEnd": 4, "zones": [] },
            { "rowStart": 0, "rowEnd": 9, "colStart": 5, "colEnd": 9, "zones": [
              { "id": "11111111-1111-1111-1111-111111111111",
                "label": "R", "rule": "free",
                "rowStart": 2, "rowEnd": 4, "colStart": 6, "colEnd": 8 }
            ] }
          ]
        }
        """
        let config = try decode(json)
        let zone = config.effectiveBands[1].zones[0]
        #expect(zone.colStart == 6)
        #expect(zone.colEnd == 8)
    }

    @Test("encode emits schemaVersion 2 and round-trips zones unchanged")
    func encodeRoundTrip() throws {
        var config = sideBySide()
        config.addZone(GridZoneDefinition(label: "R", rule: .locked,
                                          rowStart: 1, rowEnd: 3,
                                          colStart: 6, colEnd: 9))
        let data = try JSONEncoder().encode(config)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["schemaVersion"] as? Int == 2)

        let decoded = try JSONDecoder().decode(GridCanvasConfig.self, from: data)
        let zone = decoded.effectiveBands[1].zones[0]
        #expect(zone.colStart == 6)
        #expect(zone.colEnd == 9)
    }

    @Test("legacy top-level zones land in the band owning their origin")
    func legacyTopLevelZones() throws {
        let json = """
        {
          "rows": 10, "cols": 10,
          "columnBands": [
            { "rowStart": 0, "rowEnd": 9, "colStart": 0, "colEnd": 4, "zones": [] },
            { "rowStart": 0, "rowEnd": 9, "colStart": 5, "colEnd": 9, "zones": [] }
          ],
          "zones": [
            { "id": "22222222-2222-2222-2222-222222222222",
              "label": "R", "rule": "free",
              "rowStart": 0, "rowEnd": 2, "colStart": 6, "colEnd": 8 }
          ]
        }
        """
        let config = try decode(json)
        #expect(config.effectiveBands[0].zones.isEmpty)
        #expect(config.effectiveBands[1].zones.map(\.label) == ["R"])
    }

    // MARK: - Tiling validation

    @Test("validate accepts a proper 2×2 tiling")
    func validateTiling() {
        let bands = [
            ColumnBand(rowStart: 0, rowEnd: 4, colStart: 0, colEnd: 4),
            ColumnBand(rowStart: 0, rowEnd: 4, colStart: 5, colEnd: 9),
            ColumnBand(rowStart: 5, rowEnd: 9, colStart: 0, colEnd: 9),
        ]
        #expect(GridCanvasConfig.validate(bands: bands, totalRows: 10, totalCols: 10))
    }

    @Test("validate rejects overlaps, gaps, and out-of-bounds bands")
    func validateRejects() {
        let overlap = [
            ColumnBand(rowStart: 0, rowEnd: 5, colStart: 0, colEnd: 9),
            ColumnBand(rowStart: 5, rowEnd: 9, colStart: 0, colEnd: 9),
        ]
        #expect(!GridCanvasConfig.validate(bands: overlap, totalRows: 10, totalCols: 10))

        let gap = [
            ColumnBand(rowStart: 0, rowEnd: 3, colStart: 0, colEnd: 9),
            ColumnBand(rowStart: 5, rowEnd: 9, colStart: 0, colEnd: 9),
        ]
        #expect(!GridCanvasConfig.validate(bands: gap, totalRows: 10, totalCols: 10))

        let outOfBounds = [
            ColumnBand(rowStart: 0, rowEnd: 10, colStart: 0, colEnd: 9),
        ]
        #expect(!GridCanvasConfig.validate(bands: outOfBounds, totalRows: 10, totalCols: 10))
    }
}
