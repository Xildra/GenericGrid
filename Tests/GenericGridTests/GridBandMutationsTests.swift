//
//  GridBandMutationsTests.swift
//  GenericGrid Tests
//
//  Covers compartment editing: horizontal & vertical splits, merges,
//  boundary moves, subdivision overrides, and the tiling invariant.
//

import Foundation
import Testing
@testable import GenericGrid

@Suite("GridCanvasConfig+BandMutations")
struct GridBandMutationsTests {

    // MARK: - Helpers

    /// Fresh config promoted to explicit bands (one full-grid band).
    private func promoted(rows: Int = 10, cols: Int = 10) -> GridCanvasConfig {
        var config = GridCanvasConfig(rows: rows, cols: cols)
        config.promoteToColumnBandsIfNeeded()
        return config
    }

    /// 10×10 grid split vertically at column 5: left band cols 0–4,
    /// right band cols 5–9, both spanning every row.
    private func sideBySide() -> GridCanvasConfig {
        var config = promoted()
        config.splitBand(id: config.effectiveBands[0].id, atCol: 5)
        return config
    }

    private func zone(_ label: String, rule: ZoneRule = .free,
                      rows: ClosedRange<Double>, cols: ClosedRange<Double>) -> GridZoneDefinition {
        GridZoneDefinition(label: label, rule: rule,
                           rowStart: rows.lowerBound, rowEnd: rows.upperBound,
                           colStart: cols.lowerBound, colEnd: cols.upperBound)
    }

    /// Asserts the config's explicit bands form a valid tiling.
    private func expectValidTiling(_ config: GridCanvasConfig,
                                   sourceLocation: SourceLocation = #_sourceLocation) {
        let bands = config.columnBands ?? []
        #expect(GridCanvasConfig.validate(bands: bands,
                                          totalRows: config.rows,
                                          totalCols: config.cols),
                "bands must tile the grid", sourceLocation: sourceLocation)
    }

    // MARK: - Promotion

    @Test("promotion seeds a single full-grid band")
    func promotionSeedsFullGrid() {
        let config = promoted(rows: 6, cols: 8)
        let bands = config.columnBands ?? []
        #expect(bands.count == 1)
        #expect(bands[0].rowStart == 0 && bands[0].rowEnd == 5)
        #expect(bands[0].colStart == 0 && bands[0].colEnd == 7)
        expectValidTiling(config)
    }

    // MARK: - Horizontal split

    @Test("horizontal split produces two stacked bands")
    func horizontalSplit() {
        var config = promoted()
        config.splitBand(at: 4)
        let bands = config.effectiveBands
        #expect(bands.count == 2)
        #expect(bands[0].rowEnd == 3)
        #expect(bands[1].rowStart == 4)
        expectValidTiling(config)
    }

    @Test("horizontal split redistributes zones by rowStart")
    func horizontalSplitZones() {
        var config = promoted()
        config.addZone(zone("Upper", rows: 1...3, cols: 0...2))
        config.addZone(zone("Lower", rows: 6...8, cols: 0...2))
        config.splitBand(id: config.effectiveBands[0].id, atRow: 5)
        let bands = config.effectiveBands
        #expect(bands[0].zones.map(\.label) == ["Upper"])
        #expect(bands[1].zones.map(\.label) == ["Lower"])
        expectValidTiling(config)
    }

    @Test("split on the top edge or out of range is a no-op")
    func horizontalSplitNoOp() {
        var config = promoted()
        let id = config.effectiveBands[0].id
        config.splitBand(id: id, atRow: 0)
        #expect(config.effectiveBands.count == 1)
        config.splitBand(at: 99)
        #expect(config.effectiveBands.count == 1)
    }

    // MARK: - Vertical split

    @Test("vertical split produces two side-by-side bands")
    func verticalSplit() {
        let config = sideBySide()
        let bands = config.effectiveBands
        #expect(bands.count == 2)
        #expect(bands[0].colStart == 0 && bands[0].colEnd == 4)
        #expect(bands[1].colStart == 5 && bands[1].colEnd == 9)
        expectValidTiling(config)
    }

    @Test("vertical split redistributes zones without changing their coordinates")
    func verticalSplitZones() {
        var config = promoted()
        config.addZone(zone("Left", rows: 0...2, cols: 1...3))
        config.addZone(zone("Right", rows: 0...2, cols: 6...8))
        config.splitBand(id: config.effectiveBands[0].id, atCol: 5)
        let bands = config.effectiveBands
        #expect(bands[0].zones.map(\.label) == ["Left"])
        #expect(bands[1].zones.map(\.label) == ["Right"])
        // Absolute coordinates survive the ownership transfer.
        #expect(bands[1].zones[0].colStart == 6)
        #expect(bands[1].zones[0].colEnd == 8)
        expectValidTiling(config)
    }

    @Test("vertical split distributes labels to both sides")
    func verticalSplitLabels() {
        var config = promoted()
        let id = config.effectiveBands[0].id
        config.updateBandLabels(id: id, labels: (1...10).map { "C\($0)" })
        config.splitBand(id: id, atCol: 5)
        let bands = config.effectiveBands
        #expect(bands[0].labels == ["C1", "C2", "C3", "C4", "C5"])
        #expect(bands[1].labels == ["C6", "C7", "C8", "C9", "C10"])
    }

    // MARK: - Merge

    @Test("merging a horizontal split restores a single band")
    func mergeHorizontal() {
        var config = promoted()
        config.addZone(zone("Z", rows: 6...8, cols: 0...2))
        config.splitBand(at: 5)
        let lower = config.effectiveBands[1]
        config.mergeBand(id: lower.id)
        let bands = config.effectiveBands
        #expect(bands.count == 1)
        #expect(bands[0].rowStart == 0 && bands[0].rowEnd == 9)
        #expect(bands[0].zones.map(\.label) == ["Z"])
        expectValidTiling(config)
    }

    @Test("merging a vertical split restores a single band and keeps zone coordinates")
    func mergeVertical() {
        var config = sideBySide()
        config.addZone(zone("Z", rows: 0...2, cols: 6...8))
        let right = config.effectiveBands[1]
        config.mergeBand(id: right.id)
        let bands = config.effectiveBands
        #expect(bands.count == 1)
        #expect(bands[0].colStart == 0 && bands[0].colEnd == 9)
        #expect(bands[0].zones.first?.colStart == 6)
        expectValidTiling(config)
    }

    @Test("merge folds into top, bottom, left, or right neighbours")
    func mergeAllDirections() {
        // Top: remove the lower band of a horizontal split.
        var c1 = promoted(); c1.splitBand(at: 5)
        c1.mergeBand(id: c1.effectiveBands[1].id)
        #expect(c1.effectiveBands.count == 1)
        // Bottom: remove the upper band.
        var c2 = promoted(); c2.splitBand(at: 5)
        c2.mergeBand(id: c2.effectiveBands[0].id)
        #expect(c2.effectiveBands.count == 1)
        // Left: remove the right band of a vertical split.
        var c3 = sideBySide()
        c3.mergeBand(id: c3.effectiveBands[1].id)
        #expect(c3.effectiveBands.count == 1)
        // Right: remove the left band.
        var c4 = sideBySide()
        c4.mergeBand(id: c4.effectiveBands[0].id)
        #expect(c4.effectiveBands.count == 1)
        for c in [c1, c2, c3, c4] { expectValidTiling(c) }
    }

    @Test("merge without a full shared edge is a no-op")
    func mergeNoFullEdge() {
        // Split horizontally, then split only the lower band vertically:
        // the upper band shares no single full edge with either half.
        var config = promoted()
        config.splitBand(at: 5)
        let lower = config.effectiveBands[1]
        config.splitBand(id: lower.id, atCol: 5)
        #expect(config.effectiveBands.count == 3)
        config.mergeBand(id: config.effectiveBands[0].id)
        #expect(config.effectiveBands.count == 3)
        expectValidTiling(config)
    }

    @Test("the last remaining band cannot be merged away")
    func mergeLastBand() {
        var config = promoted()
        config.mergeBand(id: config.effectiveBands[0].id)
        #expect(config.effectiveBands.count == 1)
    }

    // MARK: - Row boundary moves

    @Test("moving a row boundary resizes both bands and transfers zones")
    func rowBoundaryMove() {
        var config = promoted()
        config.addZone(zone("Z", rows: 4...5, cols: 0...2))
        config.splitBand(at: 6)   // upper rows 0–5 (owns Z), lower rows 6–9
        let upper = config.effectiveBands[0]
        let lower = config.effectiveBands[1]
        #expect(upper.zones.map(\.label) == ["Z"])

        config.setBandRowStart(id: lower.id, newStart: 4)
        let bands = config.effectiveBands
        #expect(bands[0].rowEnd == 3)
        #expect(bands[1].rowStart == 4)
        // Z starts at row 4, now owned by the lower band.
        #expect(bands[1].zones.map(\.label) == ["Z"])
        expectValidTiling(config)
    }

    @Test("row boundary move that would empty a band is rejected")
    func rowBoundaryMoveRejected() {
        var config = promoted()
        config.splitBand(at: 5)
        let lower = config.effectiveBands[1]
        config.setBandRowStart(id: lower.id, newStart: 0)   // would erase the upper band
        #expect(config.effectiveBands[0].rowEnd == 4)
        #expect(config.effectiveBands[1].rowStart == 5)
    }

    @Test("canResize gates require a single full-edge neighbour")
    func canResizeGates() {
        var config = promoted()
        let only = config.effectiveBands[0].id
        #expect(!config.canResizeRowStart(bandID: only))
        #expect(!config.canResizeRowEnd(bandID: only))

        config.splitBand(at: 5)
        let upper = config.effectiveBands[0].id
        let lower = config.effectiveBands[1].id
        #expect(config.canResizeRowEnd(bandID: upper))
        #expect(config.canResizeRowStart(bandID: lower))
        #expect(!config.canResizeRowStart(bandID: upper))
        #expect(!config.canResizeRowEnd(bandID: lower))
    }

    // MARK: - Column boundary moves

    @Test("moving a column boundary resizes both bands and transfers zones")
    func colBoundaryMove() {
        var config = sideBySide()
        config.addZone(zone("Z", rows: 0...2, cols: 4...5))
        #expect(config.effectiveBands[0].zones.map(\.label) == ["Z"])

        let right = config.effectiveBands[1]
        config.setBandColStart(id: right.id, newStart: 4)
        let bands = config.effectiveBands
        #expect(bands[0].colEnd == 3)
        #expect(bands[1].colStart == 4)
        // Z starts at col 4, now owned by the right band — coordinates intact.
        #expect(bands[1].zones.map(\.label) == ["Z"])
        #expect(bands[1].zones[0].colStart == 4)
        expectValidTiling(config)
    }

    @Test("column boundary moves clear subdivision overrides")
    func colBoundaryClearsOverride() {
        var config = sideBySide()
        let left = config.effectiveBands[0]
        config.setBandCols(id: left.id, cols: 3)
        #expect(config.effectiveBands[0].cols == 3)
        config.setBandColEnd(id: left.id, newEnd: 6)
        #expect(config.effectiveBands[0].cols == nil)
        #expect(config.effectiveBands[1].cols == nil)
        expectValidTiling(config)
    }

    // MARK: - Subdivision override

    @Test("setBandCols clamps zones to the band's absolute column limit")
    func setBandColsClampsZones() {
        var config = sideBySide()
        config.addZone(zone("Kept", rows: 0...2, cols: 5...7))
        config.addZone(zone("Dropped", rows: 4...6, cols: 8.5...9.5))
        let right = config.effectiveBands[1]
        config.setBandCols(id: right.id, cols: 3)   // columns 5..<8 remain
        let zones = config.effectiveBands[1].zones
        #expect(zones.map(\.label) == ["Kept"])
        #expect(zones[0].colEnd == 7)
    }

    @Test("setBandCols(nil) restores the natural width")
    func setBandColsReset() {
        var config = promoted()
        let id = config.effectiveBands[0].id
        config.setBandCols(id: id, cols: 4)
        #expect(config.cols(for: config.effectiveBands[0]) == 4)
        config.setBandCols(id: id, cols: nil)
        #expect(config.cols(for: config.effectiveBands[0]) == 10)
    }

    // MARK: - Batch merge

    @Test("mergeBands(at:) folds each offset into a neighbour")
    func mergeBandsOffsets() {
        var config = promoted()
        config.splitBand(at: 3)
        config.splitBand(at: 6)
        #expect(config.effectiveBands.count == 3)
        config.mergeBands(at: IndexSet([1, 2]))
        #expect(config.effectiveBands.count == 1)
        expectValidTiling(config)
    }

    // MARK: - Border

    @Test("setBandBorder stores and clears the custom border")
    func bandBorder() {
        var config = promoted()
        let id = config.effectiveBands[0].id
        config.setBandBorder(id: id, color: .red, width: 3)
        let band = config.effectiveBands[0]
        #expect(band.hasCustomBorder)
        #expect(band.borderWidth == 3)
        config.setBandBorder(id: id, color: nil, width: nil)
        #expect(!config.effectiveBands[0].hasCustomBorder)
    }
}
