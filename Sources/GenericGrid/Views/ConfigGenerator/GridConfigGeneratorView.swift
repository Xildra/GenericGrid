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
    @State private var showRowLabelsSheet = false
    @State private var showColLabelsSheet = false
    @State private var showImporter = false
    @State private var importError: String?
    @State private var showExporter = false
    @State private var exportDocument: ConfigDocument?
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
        .sheet(isPresented: $showRowLabelsSheet) {
            LabelsEditorSheet(
                kind: "Row",
                count: config.rows,
                labels: config.rowLabels ?? []
            ) { saved in
                config.rowLabels = saved
            } onReset: {
                config.rowLabels = nil
            }
        }
        .sheet(isPresented: $showColLabelsSheet) {
            LabelsEditorSheet(
                kind: "Column",
                count: config.cols,
                labels: config.colLabels ?? []
            ) { saved in
                config.colLabels = saved
            } onReset: {
                config.colLabels = nil
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultFilename
        ) { result in
            handleExport(result)
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
		.navigationTitle("Aircraft Configuration Maker")
		#if os(iOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif

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
                exportDocument = ConfigDocument(config: config)
                showExporter = true
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
            stepperWithField("Rows", value: $config.rows)
            stepperWithField("Columns", value: $config.cols)
        }
    }

    private func stepperWithField(_ label: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 1...999) {
            HStack {
                Text(label)
                Spacer()
                TextField("", value: value, format: .number)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
        }
    }

    // MARK: - Labels

    /// Returns `true` if every label differs from its default value.
    private func allRowLabelsEdited() -> Bool {
        guard let labels = config.rowLabels else { return false }
        let defaults = (0..<config.rows).map { "\($0 + 1)" }
        guard labels.count >= config.rows else { return false }
        return (0..<config.rows).allSatisfy { labels[$0] != defaults[$0] }
    }

    private func allColLabelsEdited() -> Bool {
        guard let labels = config.colLabels else { return false }
        let defaults = (0..<config.cols).map { idx in
            idx < 26 ? String(UnicodeScalar(65 + idx)!) : "\(idx)"
        }
        guard labels.count >= config.cols else { return false }
        return (0..<config.cols).allSatisfy { labels[$0] != defaults[$0] }
    }

    private var labelsSection: some View {
        Section("Labels") {
            Button {
                if config.rowLabels == nil {
                    config.rowLabels = (0..<config.rows).map { "\($0 + 1)" }
                }
                showRowLabelsSheet = true
            } label: {
                HStack {
                    Text("Row labels")
                    Spacer()
                    if config.rowLabels != nil {
                        if allRowLabelsEdited() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Edited")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(.primary)

            Button {
                if config.colLabels == nil {
                    config.colLabels = (0..<config.cols).map { config.colLabel(at: $0) }
                }
                showColLabelsSheet = true
            } label: {
                HStack {
                    Text("Column labels")
                    Spacer()
                    if config.colLabels != nil {
                        if allColLabelsEdited() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Edited")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(.primary)
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

    // MARK: - Save (fileExporter)

    /// Default filename derived from the config title.
    private var defaultFilename: String {
        let name = (config.title ?? "grid_config")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        return "\(name).json"
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            sourceURL = url
            withAnimation { saveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { saveSuccess = false }
            }
            onExport?(url)
        case .failure(let error):
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
