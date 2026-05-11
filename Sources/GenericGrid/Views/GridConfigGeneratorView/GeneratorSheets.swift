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

    @Binding var showRowLabelsSheet: Bool

    @Binding var editingBand: EditingBandRef?

    @Binding var showSplitSheet: Bool
    @Binding var splitRow: Int

    let onDismissFocus: () -> Void

    func body(content: Content) -> some View {
        content
            // `.sheet(item:)` makes the sheet content closure receive
            // the zone directly, avoiding the race where the closure
            // was evaluated before `editingZone` had propagated and
            // the seed (with the band-correct rowStart) was lost.
            .sheet(item: $editingZone, onDismiss: onDismissFocus) { zoneToEdit in
                ZoneEditorSheet(zone: zoneToEdit, config: config) { saved in
                    if config.containsZone(id: saved.id) {
                        config.updateZone(saved)
                    } else {
                        config.addZone(saved)
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
            .sheet(item: $editingBand, onDismiss: onDismissFocus) { ref in
                CompartmentEditorSheet(config: $config, bandID: ref.id)
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
}

/// Identifiable reference to the compartment currently being edited.
/// Driving the sheet via `.sheet(item:)` avoids the empty-sheet race
/// where `editingBandID` isn't yet propagated when the content closure
/// is first evaluated.
@available(iOS 17.0, macOS 14.0, *)
struct EditingBandRef: Identifiable, Hashable {
    let id: UUID
}
