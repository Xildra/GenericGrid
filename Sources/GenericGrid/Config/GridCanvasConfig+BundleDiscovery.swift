//
//  GridCanvasConfig+BundleDiscovery.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Scans app bundles for grid configs so hosting apps can offer a
//  pick-from-bundle experience without hardcoding filenames.
//

import Foundation

extension GridCanvasConfig {

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
