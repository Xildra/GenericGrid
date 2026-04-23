//
//  GeneratorFileTransfer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Groups the JSON import/export plumbing for the config generator
//  (fileImporter, fileExporter, error alert) in one place so the
//  root view only has to wire bindings.
//

import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

@available(iOS 17.0, macOS 14.0, *)
struct GeneratorFileTransfer: ViewModifier {
    @Binding var config: GridCanvasConfig
    @Binding var sourceURL: URL?

    @Binding var showImporter: Bool
    @Binding var showExporter: Bool
    @Binding var exportDocument: ConfigDocument?
    @Binding var importError: String?
    @Binding var saveSuccess: Bool

    let onExport: ((URL) -> Void)?

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: defaultFilename,
                onCompletion: handleExport
            )
            .alert("Import Error", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
    }

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
            DispatchQueue.main.asyncAfter(deadline: .now() + GridAnimation.saveResetDelay) {
                withAnimation { saveSuccess = false }
            }
            onExport?(url)
        case .failure(let error):
            importError = "Save failed: \(error.localizedDescription)"
        }
    }

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
