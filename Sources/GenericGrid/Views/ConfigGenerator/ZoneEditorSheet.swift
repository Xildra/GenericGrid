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
    private let maxRows: Int
    private let maxCols: Int
    private let onSave: (GridZoneDefinition) -> Void

    init(zone: GridZoneDefinition?, maxRows: Int, maxCols: Int,
         onSave: @escaping (GridZoneDefinition) -> Void) {
        self.maxRows = maxRows
        self.maxCols = maxCols
        self.onSave = onSave
        self.isNew = zone == nil

        self.zone = zone ?? GridZoneDefinition(
            rowEnd: min(GridDefaults.newZoneEnd, Double(maxRows)),
            colEnd: min(GridDefaults.newZoneEnd, Double(maxCols))
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

                Section {
                    positionStepper("Row start", value: $zone.rowStart,
                                    range: 0...max(0, Double(maxRows) - Double(zone.rowCount)),
                                    onChange: { zone.rowEnd = $0 + Double(zone.rowCount) })
                    positionStepper("Col start", value: $zone.colStart,
                                    range: 0...max(0, Double(maxCols) - Double(zone.colCount)),
                                    onChange: { zone.colEnd = $0 + Double(zone.colCount) })
                    intStepper("Row count", value: rowCountBinding,
                               range: 1...max(1, maxRows - Int(zone.rowStart)))
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
