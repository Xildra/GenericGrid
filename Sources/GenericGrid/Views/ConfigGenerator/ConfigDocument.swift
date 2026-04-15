//
//  ConfigDocument.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  FileDocument wrapper used by fileExporter to save
//  a GridCanvasConfig as a JSON file.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfigDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(config: GridCanvasConfig) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.data = (try? encoder.encode(config)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
