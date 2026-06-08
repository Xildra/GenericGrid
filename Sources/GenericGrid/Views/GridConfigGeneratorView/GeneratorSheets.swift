//
//  GeneratorSheets.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Groups the sheet presenters used by the config generator
//  (zone editor, row-labels editor, compartment editor, split
//  compartment) so the root view stays focused on layout.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GeneratorSheets: ViewModifier {
    @Binding var config: GridCanvasConfig

    @Binding var editingZone: GridZoneDefinition?
    /// Band the next "Add zone" action should write into. Captured when
    /// the user picks "Add zone" on a specific compartment so vertical
    /// splits land the zone in the right column range.
    @Binding var newZoneTargetBandID: UUID?

    @Binding var showRowLabelsSheet: Bool

    @Binding var editingBand: EditingBandRef?

    @Binding var showSplitSheet: Bool
    /// Band the split sheet should target. Nil = let the sheet pick the
    /// best splittable band for the chosen axis.
    @Binding var splitBandID: UUID?

    let onDismissFocus: () -> Void

    func body(content: Content) -> some View {
        content
            // `.sheet(item:)` makes the sheet content closure receive
            // the zone directly, avoiding the race where the closure
            // was evaluated before `editingZone` had propagated and
            // the seed (with the band-correct rowStart) was lost.
            .sheet(item: $editingZone, onDismiss: onDismissFocus) { zoneToEdit in
                ZoneEditorSheet(zone: zoneToEdit,
                                config: config,
                                targetBandID: newZoneTargetBandID) { saved in
                    if config.containsZone(id: saved.id) {
                        config.updateZone(saved)
                    } else if let id = newZoneTargetBandID {
                        config.addZone(saved, toBandID: id)
                        newZoneTargetBandID = nil
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
            .sheet(isPresented: $showSplitSheet, onDismiss: { splitBandID = nil }) {
                SplitCompartmentSheet(
                    config: config,
                    bandID: splitBandID
                ) { id, axis, pos in
                    switch axis {
                    case .horizontal:
                        config.splitBand(id: id, atRow: pos)
                    case .vertical:
                        config.splitBand(id: id, atCol: pos)
                    }
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
