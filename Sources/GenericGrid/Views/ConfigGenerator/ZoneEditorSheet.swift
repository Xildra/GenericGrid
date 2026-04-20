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
		
		self.zone = zone ?? GridZoneDefinition(rowEnd: min(GridDefaults.newZoneEnd, Double(maxRows)), colEnd: min(GridDefaults.newZoneEnd, Double(maxCols)))
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

                Section("Bounds (supports half-cells: 0, 0.5, 1…)") {
					stepperWithField("Row start", value: $zone.rowStart, range: 0...Double(maxRows) - 0.5)
					stepperWithField("Row end", value: $zone.rowEnd, range: 0.5...Double(maxRows))
					stepperWithField("Col start", value: $zone.colStart, range: 0...Double(maxCols) - 0.5)
					stepperWithField("Col end", value: $zone.colEnd, range: 0.5...Double(maxCols))
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
						_ = allowedTypeNames
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }

                        onSave(zone)
                        dismiss()
                    }
					.disabled(zone.label.isEmpty || zone.rowEnd <= zone.rowStart || zone.colEnd <= zone.colStart)
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
        Stepper(value: value, in: range, step: GridGesture.halfCell) {
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
