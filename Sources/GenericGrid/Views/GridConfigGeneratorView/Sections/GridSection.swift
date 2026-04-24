//
//  GridSection.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Sidebar section covering the "big picture" grid settings:
//  title, dimensions, grid-lines toggle, and row-titles entry point.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridSection: View {
    @Binding var config: GridCanvasConfig
    @Binding var showRowLabelsSheet: Bool
    @FocusState.Binding var focusedField: Bool

    var body: some View {
        Section("General") {
            TextField("Title", text: Binding(
                get: { config.title ?? "" },
                set: { config.title = $0.isEmpty ? nil : $0 }
            ))
            .focused($focusedField)

            DimensionsField(
                rows: Binding(
                    get: { config.rows },
                    set: { config.setRows($0) }
                ),
                cols: Binding(
                    get: { config.cols },
                    set: { config.setCols($0) }
                ),
                focusedField: $focusedField
            )

            Toggle("Grid lines", isOn: $config.showMainGrid)

            Button {
                if config.rowLabels == nil {
                    config.rowLabels = (0..<config.rows).map { "\($0 + 1)" }
                }
                showRowLabelsSheet = true
            } label: {
                HStack {
                    Image(systemName: "list.number").foregroundStyle(.secondary)
                    Text("Row titles")
                    Spacer()
                    if allRowLabelsEdited {
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            .tint(.primary)
        }
    }

    /// `true` if row labels differ from defaults across all rows.
    private var allRowLabelsEdited: Bool {
        guard let labels = config.rowLabels else { return false }
        let defaults = (0..<config.rows).map { "\($0 + 1)" }
        guard labels.count >= config.rows else { return false }
        return (0..<config.rows).allSatisfy { labels[$0] != defaults[$0] }
    }
}
