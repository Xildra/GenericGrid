//
//  GeneratorSheets.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Groups the sheet presenters used by the config generator
//  (zone editor, row-labels editor, band-labels editor, split
//  compartment) so the root view stays focused on layout.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GeneratorSheets: ViewModifier {
    @Binding var config: GridCanvasConfig

    @Binding var editingZone: GridZoneDefinition?
    @Binding var showZoneSheet: Bool

    @Binding var showRowLabelsSheet: Bool

    @Binding var editingBandID: UUID?
    @Binding var showBandLabelsSheet: Bool

    @Binding var showSplitSheet: Bool
    @Binding var splitRow: Int

    let onDismissFocus: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showZoneSheet, onDismiss: onDismissFocus) {
                ZoneEditorSheet(zone: editingZone, config: config) { saved in
                    if let idx = config.zones.firstIndex(where: { $0.id == saved.id }) {
                        config.zones[idx] = saved
                    } else {
                        config.zones.append(saved)
                    }
                }
            }
            .sheet(isPresented: $showRowLabelsSheet, onDismiss: onDismissFocus) {
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
            .sheet(isPresented: $showBandLabelsSheet, onDismiss: onDismissFocus) {
                bandLabelsSheet
            }
            .sheet(isPresented: $showSplitSheet) {
                SplitCompartmentSheet(
                    splitRow: $splitRow,
                    totalRows: config.rows
                ) { row in
                    config.splitBand(at: row)
                }
            }
    }

    @ViewBuilder
    private var bandLabelsSheet: some View {
        if let id = editingBandID,
           let band = config.effectiveBands.first(where: { $0.id == id }) {
            LabelsEditorSheet(
                kind: "Column",
                count: config.cols,
                labels: band.labels ?? (0..<config.cols).map { band.colLabel(at: $0) }
            ) { saved in
                config.updateBandLabels(id: id, labels: saved)
            } onReset: {
                config.updateBandLabels(id: id, labels: nil)
            }
        }
    }
}
