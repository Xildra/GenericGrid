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
    /// Band the next "Add zone" call should target. Captured when the
    /// user picks "Add zone" on a specific compartment so vertical
    /// splits land the zone in the right column range.
    @State private var newZoneTargetBandID: UUID?
	@State private var exportDocument: ConfigDocument?

	@State private var sourceURL: URL?
	@State private var editingBand: EditingBandRef?

	/// Band targeted by the split sheet — nil means "let the sheet pick".
	@State private var splitBandID: UUID?
	@State private var importError: String?

    @State private var showRowLabelsSheet = false
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
            }
        }
        .modifier(GeneratorSheets(
            config: $config,
            editingZone: $editingZone,
            newZoneTargetBandID: $newZoneTargetBandID,
            showRowLabelsSheet: $showRowLabelsSheet,
            editingBand: $editingBand,
            showSplitSheet: $showSplitSheet,
            splitBandID: $splitBandID,
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
                editingBand: $editingBand,
                showSplitSheet: $showSplitSheet,
                splitBandID: $splitBandID,
                onEditZone: { zone in
                    editingZone = zone
                },
                onAddZone: { band in
                    newZoneTargetBandID = band.id
                    editingZone = seededZone(in: band)
                }
            )
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

    /// Builds a new zone pre-positioned inside the given compartment,
    /// using the compartment's own column count. Coordinates are
    /// absolute, so the zone starts at the band's own origin.
    private func seededZone(in band: ColumnBand) -> GridZoneDefinition {
        let bandCols = band.effectiveCols(default: config.cols)
        let size = min(GridDefaults.newZoneEnd, Double(max(1, band.rowCount)))
        let colSize = min(GridDefaults.newZoneEnd, Double(bandCols))
        return GridZoneDefinition(
            rowStart: Double(band.rowStart),
            rowEnd: Double(band.rowStart) + size,
            colStart: Double(band.colStart),
            colEnd: Double(band.colStart) + colSize
        )
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
