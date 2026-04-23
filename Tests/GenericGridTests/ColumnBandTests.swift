//
//  ColumnBandTests.swift
//  GenericGrid Tests
//

import Testing
import Foundation
import CoreGraphics
@testable import GenericGrid

@Suite("ColumnBand")
struct ColumnBandTests {

    // MARK: - Model

    @Test("contains respects inclusive bounds")
    func containsInclusive() {
        let band = ColumnBand(rowStart: 2, rowEnd: 5)
        #expect(band.contains(row: 2))
        #expect(band.contains(row: 5))
        #expect(!band.contains(row: 1))
        #expect(!band.contains(row: 6))
    }

    @Test("rowCount is inclusive span")
    func rowCountInclusive() {
        #expect(ColumnBand(rowStart: 0, rowEnd: 0).rowCount == 1)
        #expect(ColumnBand(rowStart: 0, rowEnd: 4).rowCount == 5)
    }

    @Test("colLabel falls back to A, B, C when labels nil")
    func colLabelFallback() {
        let band = ColumnBand(rowStart: 0, rowEnd: 0)
        #expect(band.colLabel(at: 0) == "A")
        #expect(band.colLabel(at: 1) == "B")
    }

    @Test("colLabel uses provided labels first")
    func colLabelCustom() {
        let band = ColumnBand(rowStart: 0, rowEnd: 0, labels: ["X", "Y", "Z"])
        #expect(band.colLabel(at: 0) == "X")
        #expect(band.colLabel(at: 2) == "Z")
    }

    @Test("colLabel falls back to numeric index beyond 26 letters")
    func colLabelNumericFallback() {
        let band = ColumnBand(rowStart: 0, rowEnd: 0)
        #expect(band.colLabel(at: 26) == "26")
    }

    // MARK: - Validation

    @Test("validate accepts a single band covering the grid")
    func validateSingleBand() {
        let band = ColumnBand(rowStart: 0, rowEnd: 9)
        #expect(GridCanvasConfig.validate(bands: [band], totalRows: 10))
    }

    @Test("validate accepts two contiguous bands")
    func validateContiguous() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        #expect(GridCanvasConfig.validate(bands: [a, b], totalRows: 10))
    }

    @Test("validate rejects a gap between bands")
    func validateRejectsGap() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 6, rowEnd: 9)
        #expect(!GridCanvasConfig.validate(bands: [a, b], totalRows: 10))
    }

    @Test("validate rejects overlapping bands")
    func validateRejectsOverlap() {
        let a = ColumnBand(rowStart: 0, rowEnd: 5)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        #expect(!GridCanvasConfig.validate(bands: [a, b], totalRows: 10))
    }

    @Test("validate rejects bands not starting at 0")
    func validateRejectsNonZeroStart() {
        let a = ColumnBand(rowStart: 1, rowEnd: 9)
        #expect(!GridCanvasConfig.validate(bands: [a], totalRows: 10))
    }

    @Test("validate rejects bands not ending at totalRows - 1")
    func validateRejectsWrongEnd() {
        let a = ColumnBand(rowStart: 0, rowEnd: 7)
        #expect(!GridCanvasConfig.validate(bands: [a], totalRows: 10))
    }

    @Test("validate rejects inverted start/end")
    func validateRejectsInverted() {
        let a = ColumnBand(rowStart: 5, rowEnd: 2)
        #expect(!GridCanvasConfig.validate(bands: [a], totalRows: 10))
    }

    @Test("validate rejects empty bands")
    func validateRejectsEmpty() {
        #expect(!GridCanvasConfig.validate(bands: [], totalRows: 10))
    }

    // MARK: - effectiveBands fallback

    @Test("effectiveBands returns a single band when columnBands is nil")
    func effectiveBandsFallback() {
        let config = GridCanvasConfig(rows: 6, cols: 3,
                                      colLabels: ["A", "B", "C"])
        let bands = config.effectiveBands
        #expect(bands.count == 1)
        #expect(bands[0].rowStart == 0)
        #expect(bands[0].rowEnd == 5)
        #expect(bands[0].labels == ["A", "B", "C"])
    }

    @Test("effectiveBands falls back when columnBands are invalid")
    func effectiveBandsInvalidFallback() {
        let bad = ColumnBand(rowStart: 1, rowEnd: 3)   // doesn't cover 0…4
        let config = GridCanvasConfig(rows: 5, cols: 2, columnBands: [bad])
        let bands = config.effectiveBands
        #expect(bands.count == 1)
        #expect(bands[0].rowStart == 0)
        #expect(bands[0].rowEnd == 4)
    }

    @Test("effectiveBands returns valid columnBands unchanged")
    func effectiveBandsValidPassthrough() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4, labels: ["A","B","C","D"])
        let b = ColumnBand(rowStart: 5, rowEnd: 9, labels: ["E","F","G","H"])
        let config = GridCanvasConfig(rows: 10, cols: 4, columnBands: [a, b])
        let bands = config.effectiveBands
        #expect(bands.count == 2)
        #expect(bands[0].labels == ["A","B","C","D"])
        #expect(bands[1].labels == ["E","F","G","H"])
    }

    // MARK: - Band lookups

    @Test("band(forRow:) returns the owning band")
    func bandForRow() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        let config = GridCanvasConfig(rows: 10, cols: 2, columnBands: [a, b])
        #expect(config.band(forRow: 0).id == a.id)
        #expect(config.band(forRow: 4).id == a.id)
        #expect(config.band(forRow: 5).id == b.id)
        #expect(config.band(forRow: 9).id == b.id)
    }

    @Test("band(forRow:) clamps out-of-range rows")
    func bandForRowClamps() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        let config = GridCanvasConfig(rows: 10, cols: 2, columnBands: [a, b])
        #expect(config.band(forRow: -3).id == a.id)
        #expect(config.band(forRow: 100).id == b.id)
    }

    @Test("bandIndex returns zero-based index")
    func bandIndexValues() {
        let a = ColumnBand(rowStart: 0, rowEnd: 2)
        let b = ColumnBand(rowStart: 3, rowEnd: 6)
        let c = ColumnBand(rowStart: 7, rowEnd: 9)
        let config = GridCanvasConfig(rows: 10, cols: 2, columnBands: [a, b, c])
        #expect(config.bandIndex(forRow: 0) == 0)
        #expect(config.bandIndex(forRow: 3) == 1)
        #expect(config.bandIndex(forRow: 9) == 2)
    }

    @Test("colLabel(at:forRow:) picks the owning band's labels")
    func colLabelPerRow() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4, labels: ["A","B","C","D"])
        let b = ColumnBand(rowStart: 5, rowEnd: 9, labels: ["E","F","G","H"])
        let config = GridCanvasConfig(rows: 10, cols: 4, columnBands: [a, b])
        #expect(config.colLabel(at: 0, forRow: 0) == "A")
        #expect(config.colLabel(at: 3, forRow: 4) == "D")
        #expect(config.colLabel(at: 0, forRow: 5) == "E")
        #expect(config.colLabel(at: 3, forRow: 9) == "H")
    }

    // MARK: - Y geometry

    @Test("yForRow adds no offset inside the first band")
    func yForRowFirstBand() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        let config = GridCanvasConfig(rows: 10, cols: 2, columnBands: [a, b])
        #expect(config.yForRow(0, cellSize: 10) == 0)
        #expect(config.yForRow(3, cellSize: 10) == 30)
    }

    @Test("yForRow adds one cell for the second band")
    func yForRowSecondBand() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        let config = GridCanvasConfig(rows: 10, cols: 2, columnBands: [a, b])
        #expect(config.yForRow(5, cellSize: 10) == 60)    // 5 data + 1 header
        #expect(config.yForRow(9, cellSize: 10) == 100)
    }

    @Test("rowForY maps a data row y back to its logical row")
    func rowForYDataRow() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        let config = GridCanvasConfig(rows: 10, cols: 2, columnBands: [a, b])
        #expect(config.rowForY(0, cellSize: 10) == 0)
        #expect(config.rowForY(35, cellSize: 10) == 3.5)
        #expect(config.rowForY(60, cellSize: 10) == 5)
    }

    @Test("rowForY returns nil inside an intermediate header strip")
    func rowForYHeaderStrip() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        let config = GridCanvasConfig(rows: 10, cols: 2, columnBands: [a, b])
        // Header strip sits at visual y [50, 60].
        #expect(config.rowForY(50, cellSize: 10) == nil)
        #expect(config.rowForY(55, cellSize: 10) == nil)
    }

    @Test("totalContentHeight accounts for intermediate headers")
    func totalContentHeight() {
        let a = ColumnBand(rowStart: 0, rowEnd: 4)
        let b = ColumnBand(rowStart: 5, rowEnd: 9)
        let config = GridCanvasConfig(rows: 10, cols: 2, columnBands: [a, b])
        #expect(config.totalContentHeight(cellSize: 10) == 110)  // 10 + 1
    }

    // MARK: - Codable

    @Test("columnBands round-trip through JSON")
    func columnBandsJSONRoundTrip() throws {
        let a = ColumnBand(rowStart: 0, rowEnd: 4, labels: ["A","B","C","D"])
        let b = ColumnBand(rowStart: 5, rowEnd: 9, labels: ["E","F","G","H"])
        let config = GridCanvasConfig(rows: 10, cols: 4, columnBands: [a, b])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GridCanvasConfig.self, from: data)
        #expect(decoded.columnBands?.count == 2)
        #expect(decoded.columnBands?[0].labels == ["A","B","C","D"])
        #expect(decoded.columnBands?[1].rowStart == 5)
    }

    @Test("legacy JSON without columnBands decodes with nil bands")
    func legacyJSONNoBands() throws {
        let json = """
        { "rows": 4, "cols": 3 }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GridCanvasConfig.self, from: json)
        #expect(decoded.columnBands == nil)
        // Effective fallback still gives one band covering the whole grid.
        #expect(decoded.effectiveBands.count == 1)
        #expect(decoded.effectiveBands[0].rowEnd == 3)
    }
}
