//
//  GridCanvasConfig.swift
//  GenericGrid Module
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

    public init(rows: Int = 10, cols: Int = 14,
                zones: [GridZoneDefinition] = [], title: String? = nil,
                rowLabels: [String]? = nil, colLabels: [String]? = nil) {
        self.rows = rows; self.cols = cols
        self.zones = zones; self.title = title
        self.rowLabels = rowLabels; self.colLabels = colLabels
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

    public static let `default` = GridCanvasConfig(rows: 10, cols: 14, title: "Empty grid")

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
