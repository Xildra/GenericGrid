//
//  GridCanvasConfig.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  JSON-driven configuration defining the grid dimensions,
//  zones, labels, and bundle discovery helpers.
//

import SwiftUI

public struct GridCanvasConfig: Codable, Sendable {
    public var rows: Int
    public var cols: Int
    public var zones: [GridZoneDefinition]
    public var title: String?

    /// Optional labels for each row (index 0 = row 0).
    public var rowLabels: [String]?
    /// Optional labels for each column (index 0 = column 0).
    public var colLabels: [String]?

    /// Whether the main grid lines are drawn. Only a visual toggle —
    /// zone rectangles and their own internal grids are always shown.
    public var showMainGrid: Bool

    public init(rows: Int = GridDefaults.rows, cols: Int = GridDefaults.cols,
                zones: [GridZoneDefinition] = [], title: String? = nil,
                rowLabels: [String]? = nil, colLabels: [String]? = nil,
                showMainGrid: Bool = true) {
        self.rows = rows; self.cols = cols
        self.zones = zones; self.title = title
        self.rowLabels = rowLabels; self.colLabels = colLabels
        self.showMainGrid = showMainGrid
    }

    // Custom decoding so older JSON without `showMainGrid` still loads.
    private enum CodingKeys: String, CodingKey {
        case rows, cols, zones, title, rowLabels, colLabels, showMainGrid
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rows = try c.decode(Int.self, forKey: .rows)
        cols = try c.decode(Int.self, forKey: .cols)
        zones = try c.decodeIfPresent([GridZoneDefinition].self, forKey: .zones) ?? []
        title = try c.decodeIfPresent(String.self, forKey: .title)
        rowLabels = try c.decodeIfPresent([String].self, forKey: .rowLabels)
        colLabels = try c.decodeIfPresent([String].self, forKey: .colLabels)
        showMainGrid = try c.decodeIfPresent(Bool.self, forKey: .showMainGrid) ?? true
    }

    // MARK: - Label helpers

    /// Row label at the given index, falling back to "1", "2", "3"…
    public func rowLabel(at index: Int) -> String {
        if let labels = rowLabels, index < labels.count { return labels[index] }
        return "\(index + 1)"
    }

    /// Column label at the given index, falling back to "A", "B", "C"…
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
        guard colLabels != nil else { return GridCellSize.absoluteMin }
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: GridDefaults.labelMeasureFontSize, weight: .medium)
        #elseif canImport(AppKit)
        let font = NSFont.systemFont(ofSize: GridDefaults.labelMeasureFontSize, weight: .medium)
        #endif
        let maxWidth = (0..<cols).map { c in
            (colLabel(at: c) as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return maxWidth + GridCellSize.labelPadding
    }

    /// Base cell size that fits the grid in `size`, reserving `margin` for labels.
    /// Cells are bounded below by the minimum label width so column labels always fit.
    public func baseCellSize(in size: CGSize, margin: CGFloat) -> CGFloat {
        let availW = size.width  - margin
        let availH = size.height - margin
        let byCol = availW / CGFloat(cols)
        let byRow = availH / CGFloat(rows)
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

    public static let `default` = GridCanvasConfig(rows: GridDefaults.rows, cols: GridDefaults.cols, title: "Empty grid")

    // MARK: - Bundle discovery

    /// Represents a config found inside the app bundle.
    public struct BundleEntry: Identifiable {
        public let id: String          // filename without extension
        public let filename: String    // full filename (with .json)
        public let config: GridCanvasConfig

        public var title: String { config.title ?? id }
        public var subtitle: String { "\(config.cols)×\(config.rows) — \(config.zones.count) zones" }
    }

    /// Scans the bundle for files matching `*_config.json` or `grid_*.json`
    /// and attempts to decode them as `GridCanvasConfig`.
    public static func discoverConfigs(in bundle: Bundle = .main,
                                        suffix: String = "_config") -> [BundleEntry] {
        guard let resourceURL = bundle.resourceURL else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: resourceURL, includingPropertiesForKeys: nil
        )) ?? []

        return files.compactMap { url -> BundleEntry? in
            guard url.pathExtension == "json" else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            guard name.contains(suffix) || name.hasPrefix("grid_") else { return nil }
            guard let config = load(url: url) else { return nil }
            return BundleEntry(id: name, filename: url.lastPathComponent, config: config)
        }
        .sorted { $0.title < $1.title }
    }
}
