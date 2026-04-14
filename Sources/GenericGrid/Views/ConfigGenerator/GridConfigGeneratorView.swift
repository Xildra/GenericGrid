//
//  GridConfigGeneratorView.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Standalone config generator view that lets users visually
//  build a GridCanvasConfig and export it as JSON.
//  Zones can be moved and resized directly on the grid preview.
//

import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - Main view

@available(iOS 17.0, macOS 14.0, *)
public struct GridConfigGeneratorView: View {

    @State private var config: GridCanvasConfig
    @State private var editingZone: GridZoneDefinition?
    @State private var showZoneSheet = false
    @State private var showImporter = false
    @State private var importError: String?
    @State private var saveSuccess = false
    @State private var sourceURL: URL?

    /// Callback after a successful save — receives the URL of the written file.
    public var onExport: ((URL) -> Void)?

    // MARK: - Init

    /// Creates the generator with an empty default config.
    public init(onExport: ((URL) -> Void)? = nil) {
        config = .default
        sourceURL = nil
        self.onExport = onExport
    }

    /// Creates the generator by loading a JSON file at the given URL.
    /// If the URL is nil, falls back to a default config.
    /// On export the file is written back to the same URL.
    public init(url: URL?, onExport: ((URL) -> Void)? = nil) {
        let loaded = url.flatMap { GridCanvasConfig.load(url: $0) } ?? .default
        config = loaded
        sourceURL = url
        self.onExport = onExport
    }

    // MARK: - Body

    public var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            ConfigGridPreviewView(config: $config) { zone in
                editingZone = zone
                showZoneSheet = true
            }
        }
        .navigationTitle("Aircraft Configuration Maker")
		.navigationBarTitleDisplayMode(.inline)
		
        .sheet(isPresented: $showZoneSheet) {
            ZoneEditorSheet(
                zone: editingZone,
                maxRows: config.rows,
                maxCols: config.cols
            ) { saved in
                if let idx = config.zones.firstIndex(where: { $0.id == saved.id }) {
                    config.zones[idx] = saved
                } else {
                    config.zones.append(saved)
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        Form {
            generalSection
            labelsSection
            zonesListSection
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImporter = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                saveAndExport()
            } label: {
                Label(
                    saveSuccess ? "Saved" : "Save",
                    systemImage: saveSuccess ? "checkmark.circle.fill" : "square.and.arrow.up"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            TextField("Title", text: Binding(
                get: { config.title ?? "" },
                set: { config.title = $0.isEmpty ? nil : $0 }
            ))
            Stepper("Rows: \(config.rows)", value: $config.rows, in: 1...100)
            Stepper("Columns: \(config.cols)", value: $config.cols, in: 1...100)
        }
    }

    // MARK: - Labels

    private var labelsSection: some View {
        Section("Labels") {
            Toggle("Custom row labels", isOn: Binding(
                get: { config.rowLabels != nil },
                set: { on in
                    config.rowLabels = on
                        ? (0..<config.rows).map { "\($0 + 1)" }
                        : nil
                }
            ))
            if let labels = config.rowLabels {
                LabelsEditor(kind: "Row", count: config.rows, labels: labels) {
                    config.rowLabels = $0
                }
            }

            Toggle("Custom column labels", isOn: Binding(
                get: { config.colLabels != nil },
                set: { on in
                    config.colLabels = on
                        ? (0..<config.cols).map { config.colLabel(at: $0) }
                        : nil
                }
            ))
            if let labels = config.colLabels {
                LabelsEditor(kind: "Col", count: config.cols, labels: labels) {
                    config.colLabels = $0
                }
            }
        }
    }

    // MARK: - Zones list

    private var zonesListSection: some View {
        Section {
            ForEach(config.zones) { zone in
                zoneRow(zone)
            }
            .onDelete { idx in config.zones.remove(atOffsets: idx) }

            Button {
                editingZone = nil
                showZoneSheet = true
            } label: {
                Label("Add zone", systemImage: "plus.circle")
            }
        } header: {
            Text("Zones (\(config.zones.count))")
        } footer: {
            if !config.zones.isEmpty {
                Text("Drag zones directly on the preview to move them. Tap to edit. Use the handles at edges to resize.")
                    .font(.caption2)
            }
        }
    }

    private func zoneRow(_ zone: GridZoneDefinition) -> some View {
        Button {
            editingZone = zone
            showZoneSheet = true
        } label: {
            HStack {
                if let hex = zone.colorHex {
                    Circle().fill(Color(hex: hex)).frame(width: 12, height: 12)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.label).font(.headline)
                    Text(zone.rule.rawValue)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }

    // MARK: - Save

    /// Returns `<Application Support>/<AppName>/Configurations/`, creating it if needed.
    private static var configurationsDirectory: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? Bundle.main.bundleIdentifier ?? "GenericGrid"
        let dir = appSupport
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Configurations", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func saveAndExport() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }

        let destination: URL
        if let sourceURL {
            destination = sourceURL
        } else {
            guard let dir = Self.configurationsDirectory else {
                importError = "Unable to access Documents directory."
                return
            }
            let name = (config.title ?? "grid_config")
                .replacingOccurrences(of: " ", with: "_")
                .lowercased()
            destination = dir.appendingPathComponent("\(name).json")
        }

        do {
            try data.write(to: destination, options: .atomic)
            sourceURL = destination
            withAnimation { saveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { saveSuccess = false }
            }
            onExport?(destination)
        } catch {
            importError = "Save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Import handler

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let loaded = GridCanvasConfig.load(url: url) {
                withAnimation {
                    config = loaded
                    sourceURL = url
                }
            } else {
                importError = "Unable to decode the selected JSON file as a valid GridCanvasConfig."
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}
