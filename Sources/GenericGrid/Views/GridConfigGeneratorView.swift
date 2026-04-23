//
//  GridConfigGeneratorView.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Standalone config generator view that lets users visually
//  build a GridCanvasConfig and export it as JSON. The three
//  sidebar sections (grid, compartments, zones) live in their
//  own files under `Sections/`, as do the split and label sheets.
//

import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct GridConfigGeneratorView: View {

    @State private var config: GridCanvasConfig
    @State private var editingZone: GridZoneDefinition?
	@State private var exportDocument: ConfigDocument?
	
	@State private var sourceURL: URL?
	@State private var editingBandID: UUID?
	
	@State private var splitRow: Int = 1
	@State private var importError: String?
	
    @State private var showZoneSheet = false
    @State private var showRowLabelsSheet = false
    @State private var showBandLabelsSheet = false
    @State private var showSplitSheet = false
	
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var saveSuccess = false
	
    @FocusState private var focusedField: Bool

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
            sidebar
        } detail: {
            ConfigGridPreviewView(config: $config) { zone in
                editingZone = zone
                showZoneSheet = true
            }
        }
        .modifier(GeneratorSheets(
            config: $config,
            editingZone: $editingZone,
            showZoneSheet: $showZoneSheet,
            showRowLabelsSheet: $showRowLabelsSheet,
            editingBandID: $editingBandID,
            showBandLabelsSheet: $showBandLabelsSheet,
            showSplitSheet: $showSplitSheet,
            splitRow: $splitRow,
            onDismissFocus: { focusedField = false }
        ))
        .modifier(GeneratorFileTransfer(
            config: $config,
            sourceURL: $sourceURL,
            showImporter: $showImporter,
            showExporter: $showExporter,
            exportDocument: $exportDocument,
            importError: $importError,
            saveSuccess: $saveSuccess,
            onExport: onExport
        ))
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        Form {
            GridSection(
                config: $config,
                showRowLabelsSheet: $showRowLabelsSheet,
                focusedField: $focusedField
            )
            CompartmentsSection(
                config: $config,
                editingBandID: $editingBandID,
                showBandLabelsSheet: $showBandLabelsSheet,
                showSplitSheet: $showSplitSheet,
                splitRow: $splitRow
            )
            ZonesListSection(config: $config) { zone in
                editingZone = zone
                showZoneSheet = true
            }
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
            saveButton
        }
    }

    private var saveButton: some View {
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

#Preview {
    GridConfigGeneratorView()
}
