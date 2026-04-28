//
//  GridCanvasConfig.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Core JSON-driven configuration: grid dimensions, compartments
//  (column bands), and the simple zone/snap/label lookups. Zones
//  are owned by their compartment — the flat `zones` accessor is a
//  read-only flattened view provided for convenience. Band geometry,
//  band mutations, zone mutations, and bundle discovery live in
//  dedicated extension files.
//

import SwiftUI

public struct GridCanvasConfig: Codable, Sendable {
    public var rows: Int
    public var cols: Int
    public var title: String?

    /// Optional labels for each row (index 0 = row 0).
    public var rowLabels: [String]?
    /// Optional labels for each column (index 0 = column 0).
    /// Ignored when `columnBands` is set and valid.
    public var colLabels: [String]?

    /// Horizontal compartments of the grid. Each band carries its own
    /// column titles and the zones placed inside its row range. When nil,
    /// the grid is treated as a single implicit compartment (see
    /// `effectiveBands`). As soon as a zone is added, the config is
    /// promoted so `columnBands` is never nil for non-empty grids.
    public var columnBands: [ColumnBand]?

    /// Whether the main grid lines are drawn. Only a visual toggle —
    /// zone rectangles and their own internal grids are always shown.
    public var showMainGrid: Bool

    /// Whether zone titles are rendered inside the zone rectangle.
    /// Off by default — most consumers identify zones from the sidebar
    /// or by colour and prefer a clean canvas. Rule icons (lock, ban,
    /// restricted) keep showing regardless.
    public var showZoneLabels: Bool

    public init(rows: Int = GridDefaults.rows, cols: Int = GridDefaults.cols,
                zones: [GridZoneDefinition] = [], title: String? = nil,
                rowLabels: [String]? = nil, colLabels: [String]? = nil,
                columnBands: [ColumnBand]? = nil,
                showMainGrid: Bool = true,
                showZoneLabels: Bool = false) {
        self.rows = rows; self.cols = cols
        self.title = title
        self.rowLabels = rowLabels; self.colLabels = colLabels
        self.columnBands = columnBands
        self.showMainGrid = showMainGrid
        self.showZoneLabels = showZoneLabels
        // Zones live inside compartments: distribute the top-level
        // array into the matching band, synthesizing one if needed.
        if !zones.isEmpty {
            ingestLegacyZones(zones)
        }
    }

    // Legacy `zones` is accepted on decode for backwards compatibility
    // but is never emitted on encode — zones are written inside their
    // owning compartment.
    private enum CodingKeys: String, CodingKey {
        case rows, cols, zones, title, rowLabels, colLabels, columnBands,
             showMainGrid, showZoneLabels
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rows = try c.decode(Int.self, forKey: .rows)
        cols = try c.decode(Int.self, forKey: .cols)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        rowLabels = try c.decodeIfPresent([String].self, forKey: .rowLabels)
        colLabels = try c.decodeIfPresent([String].self, forKey: .colLabels)
        columnBands = try c.decodeIfPresent([ColumnBand].self, forKey: .columnBands)
        showMainGrid = try c.decodeIfPresent(Bool.self, forKey: .showMainGrid) ?? true
        showZoneLabels = try c.decodeIfPresent(Bool.self, forKey: .showZoneLabels) ?? false
        let legacyZones = try c.decodeIfPresent([GridZoneDefinition].self, forKey: .zones) ?? []
        if !legacyZones.isEmpty {
            ingestLegacyZones(legacyZones)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rows, forKey: .rows)
        try c.encode(cols, forKey: .cols)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(rowLabels, forKey: .rowLabels)
        try c.encodeIfPresent(colLabels, forKey: .colLabels)
        try c.encodeIfPresent(columnBands, forKey: .columnBands)
        try c.encode(showMainGrid, forKey: .showMainGrid)
        try c.encode(showZoneLabels, forKey: .showZoneLabels)
    }

    /// Seeds columnBands with the supplied legacy flat zone list,
    /// placing each zone inside the band containing its `rowStart`.
    private mutating func ingestLegacyZones(_ legacy: [GridZoneDefinition]) {
        promoteToColumnBandsIfNeeded()
        guard var bands = columnBands, !bands.isEmpty else { return }
        for zone in legacy {
            let startRow = Int(zone.rowStart.rounded(.down))
            let idx = bands.firstIndex(where: { $0.contains(row: startRow) })
                ?? bands.indices.last ?? 0
            bands[idx].zones.append(zone)
        }
        columnBands = bands
    }

    // MARK: - Flat zone view

    /// Flattened, read-only view of every zone in the grid. Ordered by
    /// compartment (top to bottom), preserving each compartment's local
    /// zone order. Use `addZone`, `updateZone`, or `removeZone` to mutate.
    public var zones: [GridZoneDefinition] {
        effectiveBands.flatMap(\.zones)
    }

    // MARK: - Label helpers

    /// Row label at the given index, falling back to "1", "2", "3"…
    public func rowLabel(at index: Int) -> String {
        if let labels = rowLabels, index < labels.count { return labels[index] }
        return "\(index + 1)"
    }

    /// Column label at the given index, falling back to "A", "B", "C"…
    /// This is the flat (single-band) lookup — prefer
    /// `colLabel(at:forRow:)` when compartments may be involved.
    public func colLabel(at index: Int) -> String {
        if let labels = colLabels, index < labels.count { return labels[index] }
        let letter = index < 26 ? String(UnicodeScalar(65 + index)!) : "\(index)"
        return letter
    }

    // MARK: - Zone queries

    /// Returns the first zone that contains the given cell, if any.
    public func zone(at cell: GridCell) -> GridZoneDefinition? {
        zones.first { $0.contains(cell) }
    }

    /// Returns `true` if a cell accepts placement of the given item type.
    public func canAccept(cell: GridCell, typeName: String?) -> Bool {
        guard let z = zone(at: cell) else { return true } // outside any zone → free
        switch z.rule {
        case .free:       return true
        case .locked:     return false
        case .forbidden:  return false
        case .restricted:
            guard let allowed = z.allowedTypeNames, let name = typeName else { return false }
            return allowed.contains(name)
        }
    }

    // MARK: - Zone-aware snap

    /// Snaps a raw fractional anchor:
    /// - if the point falls inside a zone, snaps to that zone's local
    ///   unit grid (origin = zone start, step = 1 in both axes);
    /// - otherwise falls back to the global half-cell guide.
    /// The main grid is therefore only a guide outside zones — zones
    /// govern their own placement and never inherit half-cell offsets.
    public func snap(_ cell: GridCell) -> GridCell {
        if let z = zones.first(where: { $0.containsPoint(cell) }) {
            let localR = (cell.r - z.rowStart).rounded(.down)
            let localC = (cell.c - z.colStart).rounded(.down)
            return GridCell(z.rowStart + localR, c: z.colStart + localC)
        }
        return GridCell(GridCell.snapHalf(cell.r), c: GridCell.snapHalf(cell.c))
    }

    // MARK: - Cell sizing

    /// Minimum cell width required so the widest column label fits.
    /// Falls back to `GridCellSize.absoluteMin` when no custom labels are set.
    public func minCellWidthForLabels() -> CGFloat {
        guard colLabels != nil || columnBands != nil else {
            return GridCellSize.absoluteMin
        }
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: GridDefaults.labelMeasureFontSize, weight: .medium)
        #elseif canImport(AppKit)
        let font = NSFont.systemFont(ofSize: GridDefaults.labelMeasureFontSize, weight: .medium)
        #endif
        let bands = effectiveBands
        let maxWidth = bands.flatMap { band in
            (0..<cols).map { c in
                (band.colLabel(at: c) as NSString)
                    .size(withAttributes: [.font: font]).width
            }
        }.max() ?? 0
        return maxWidth + GridCellSize.labelPadding
    }

    /// Base cell size that fits the grid in `size`, reserving `margin` for labels.
    /// Cells are bounded below by the minimum label width so column labels always fit.
    public func baseCellSize(in size: CGSize, margin: CGFloat) -> CGFloat {
        let availW = size.width  - margin
        let availH = size.height - margin
        let byCol = availW / CGFloat(cols)
        let byRow = availH / CGFloat(max(1, totalVerticalCells))
        let fitSize = min(byCol, byRow)
        return max(minCellWidthForLabels(), max(GridCellSize.absoluteMin, fitSize))
    }

    // MARK: - JSON loading

    /// Loads a config from a JSON file in the given bundle.
    public static func load(from filename: String, bundle: Bundle = .main) -> GridCanvasConfig? {
        guard let url = bundle.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GridCanvasConfig.self, from: data)
    }

    /// Loads a config from a local or imported URL.
    public static func load(url: URL) -> GridCanvasConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GridCanvasConfig.self, from: data)
    }

    // MARK: - Default config (empty grid)

    public static let `default` = GridCanvasConfig(rows: GridDefaults.rows,
                                                   cols: GridDefaults.cols,
                                                   title: "Empty grid")
}
