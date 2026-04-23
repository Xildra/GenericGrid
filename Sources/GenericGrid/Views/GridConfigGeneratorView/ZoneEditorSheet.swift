//
//  ZoneEditorSheet.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Modal sheet for creating or editing a GridZoneDefinition.
//  Exposes start position (fine) + size (integer), since a zone's
//  interior always draws a clean `rowCount × colCount` grid.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ZoneEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var zone: GridZoneDefinition
    @State private var allowedTypeNames: String = ""
    @FocusState private var focusedField: Bool

    private let isNew: Bool
    private let config: GridCanvasConfig
    private let onSave: (GridZoneDefinition) -> Void

    private var maxCols: Int { config.cols }
    private var bands: [ColumnBand] { config.effectiveBands }

    /// Band currently owning the zone (by `zone.rowStart`). Clamped values.
    private var currentBand: ColumnBand {
        config.band(forRow: Int(zone.rowStart.rounded(.down)))
    }

    /// Row-range bounds within the current band (lo inclusive, hi exclusive).
    private var bandRowBounds: (lo: Double, hi: Double) {
        (Double(currentBand.rowStart), Double(currentBand.rowEnd + 1))
    }

    init(zone: GridZoneDefinition?,
         config: GridCanvasConfig,
         onSave: @escaping (GridZoneDefinition) -> Void) {
        self.config = config
        self.onSave = onSave
        self.isNew = zone == nil

        let defaultEnd = min(GridDefaults.newZoneEnd, Double(config.rows))
        self.zone = zone ?? GridZoneDefinition(
            rowEnd: defaultEnd,
            colEnd: min(GridDefaults.newZoneEnd, Double(config.cols))
        )
    }

    // Size bindings: read the integer count, write end = start + count.
    private var rowCountBinding: Binding<Int> {
        Binding(get: { zone.rowCount },
                set: { zone.rowEnd = zone.rowStart + Double($0) })
    }
    private var colCountBinding: Binding<Int> {
        Binding(get: { zone.colCount },
                set: { zone.colEnd = zone.colStart + Double($0) })
    }

    /// Picker binding that rehomes the zone into the selected compartment
    /// when the user changes it.
    private var compartmentBinding: Binding<Int> {
        Binding(
            get: {
                bands.firstIndex(where: { $0.id == currentBand.id }) ?? 0
            },
            set: { idx in
                guard idx >= 0, idx < bands.count else { return }
                let target = bands[idx]
                let clampedSize = min(Double(zone.rowCount), Double(target.rowCount))
                zone.rowStart = Double(target.rowStart)
                zone.rowEnd = zone.rowStart + clampedSize
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    LabeledContent("Name") {
                        TextField("Name", text: $zone.label)
                            .fixedSize()
                            .focused($focusedField)
                    }
                    LabeledContent("Color") {
                        ColorPicker("", selection: $zone.color, supportsOpacity: false)
                            .labelsHidden()
                    }
                }

                Section("Rule") {
                    Picker("Rule", selection: $zone.rule) {
                        Text("Free").tag(ZoneRule.free)
                        Text("Locked").tag(ZoneRule.locked)
                        Text("Forbidden").tag(ZoneRule.forbidden)
                        Text("Restricted").tag(ZoneRule.restricted)
                    }
                    #if os(iOS)
                    .pickerStyle(.segmented)
                    #endif

                    if zone.rule == .restricted {
                        TextField("Allowed types (comma-separated)", text: $allowedTypeNames)
                            .font(.caption)
                            .focused($focusedField)
                    }
                }

                if bands.count > 1 {
                    Section("Compartment") {
                        Picker("Compartment", selection: compartmentBinding) {
                            ForEach(Array(bands.enumerated()), id: \.element.id) { idx, band in
                                Text("Rows \(band.rowStart)–\(band.rowEnd)")
                                    .tag(idx)
                            }
                        }
                    }
                }

                Section {
                    let (bandLo, bandHi) = bandRowBounds
                    let rowStartMax = max(bandLo, bandHi - Double(zone.rowCount))
                    let rowCountMax = max(1, Int(bandHi - bandLo) - Int(zone.rowStart - bandLo))
                    positionStepper("Row start", value: $zone.rowStart,
                                    range: bandLo...rowStartMax,
                                    onChange: { zone.rowEnd = $0 + Double(zone.rowCount) })
                    positionStepper("Col start", value: $zone.colStart,
                                    range: 0...max(0, Double(maxCols) - Double(zone.colCount)),
                                    onChange: { zone.colEnd = $0 + Double(zone.colCount) })
                    intStepper("Row count", value: rowCountBinding,
                               range: 1...rowCountMax)
                    intStepper("Col count", value: colCountBinding,
                               range: 1...max(1, maxCols - Int(zone.colStart)))
                } header: {
                    Text("Placement & size")
                } footer: {
                    Text("Position is free; size is an integer. The zone draws its own grid at those dimensions.")
                        .font(.caption2)
                }
            }
            .navigationTitle(isNew ? "New Zone" : "Edit Zone")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(zone)
                        dismiss()
                    }
                    .disabled(zone.label.isEmpty || zone.rowEnd <= zone.rowStart || zone.colEnd <= zone.colStart)
                }
            }
            .onTapGesture { focusedField = false }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    private func positionStepper(_ label: String, value: Binding<Double>,
                                 range: ClosedRange<Double>,
                                 onChange: @escaping (Double) -> Void) -> some View {
        Stepper(
            value: Binding(get: { value.wrappedValue },
                           set: { value.wrappedValue = $0; onChange($0) }),
            in: range, step: GridGesture.halfCell
        ) {
            HStack {
                Text(label)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(0...1)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func intStepper(_ label: String, value: Binding<Int>,
                            range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
