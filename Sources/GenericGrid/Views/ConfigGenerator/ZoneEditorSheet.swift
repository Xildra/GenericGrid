//
//  ZoneEditorSheet.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Modal sheet for creating or editing a GridZoneDefinition.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ZoneEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var id: UUID
    @State private var label: String
    @State private var rule: ZoneRule
    @State private var rowStart: Double
    @State private var rowEnd: Double
    @State private var colStart: Double
    @State private var colEnd: Double
    @State private var zoneColor: Color
    @State private var hasColor: Bool
    @State private var allowedTypeNames: String
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

        let z = zone ?? GridZoneDefinition(rowEnd: min(3, Double(maxRows)), colEnd: min(3, Double(maxCols)))
        id       = z.id
        label    = z.label
        rule     = z.rule
        rowStart = z.rowStart
        rowEnd   = z.rowEnd
        colStart = z.colStart
        colEnd   = z.colEnd
        hasColor = z.colorHex != nil
        zoneColor = z.color ?? .gray
        allowedTypeNames = (z.allowedTypeNames ?? []).joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
					LabeledContent("Name") {
						TextField("Name", text: $label)
							.fixedSize()
							.focused($focusedField)
					}
					LabeledContent("Color") {
						ColorPicker("", selection: $zoneColor, supportsOpacity: false)
							.labelsHidden()
					}
                }

                Section("Rule") {
                    Picker("Rule", selection: $rule) {
                        Text("Free").tag(ZoneRule.free)
                        Text("Locked").tag(ZoneRule.locked)
                        Text("Forbidden").tag(ZoneRule.forbidden)
                        Text("Restricted").tag(ZoneRule.restricted)
                    }
                    #if os(iOS)
                    .pickerStyle(.segmented)
                    #endif

                    if rule == .restricted {
                        TextField("Allowed types (comma-separated)", text: $allowedTypeNames)
                            .font(.caption)
                            .focused($focusedField)
                    }
                }

                Section("Bounds (supports half-cells: 0, 0.5, 1…)") {
                    stepperWithField("Row start", value: $rowStart, range: 0...Double(maxRows) - 0.5)
                    stepperWithField("Row end", value: $rowEnd, range: 0.5...Double(maxRows))
                    stepperWithField("Col start", value: $colStart, range: 0...Double(maxCols) - 0.5)
                    stepperWithField("Col end", value: $colEnd, range: 0.5...Double(maxCols))
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
                        let types = allowedTypeNames
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }

                        let hex: String? = hasColor ? zoneColor.toHex() : nil

                        var zone = GridZoneDefinition(
                            label: label,
                            rule: rule,
                            rowStart: rowStart,
                            rowEnd: rowEnd,
                            colStart: colStart,
                            colEnd: colEnd,
                            colorHex: hex,
                            allowedTypeNames: types.isEmpty ? nil : types
                        )
                        zone.id = id
                        onSave(zone)
                        dismiss()
                    }
                    .disabled(label.isEmpty || rowEnd <= rowStart || colEnd <= colStart)
                }
            }
            .onTapGesture {
                focusedField = false
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    private func stepperWithField(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 0.5) {
            HStack {
                Text(label)
                Spacer()
                TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .focused($focusedField)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
        }
    }
}
