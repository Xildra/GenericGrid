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
    @State private var rowStart: Int
    @State private var rowEnd: Int
    @State private var colStart: Int
    @State private var colEnd: Int
    @State private var zoneColor: Color
    @State private var hasColor: Bool
    @State private var allowedTypeNames: String

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

        let z = zone ?? GridZoneDefinition(rowEnd: min(3, maxRows), colEnd: min(3, maxCols))
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
                Section("Identity") {
                    TextField("Label", text: $label)
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
                    }
                }

                Section("Bounds (0-indexed, end exclusive)") {
                    Stepper("Row start: \(rowStart)", value: $rowStart, in: 0...(maxRows - 1))
                    Stepper("Row end: \(rowEnd)", value: $rowEnd, in: 1...maxRows)
                    Stepper("Col start: \(colStart)", value: $colStart, in: 0...(maxCols - 1))
                    Stepper("Col end: \(colEnd)", value: $colEnd, in: 1...maxCols)
                }

                Section("Appearance") {
                    HStack {
                        Text("Zone color")
                        Spacer()
                        if hasColor {
                            ColorPicker("", selection: $zoneColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 32, height: 32)
                        }
                        Button {
                            withAnimation {
                                if hasColor {
                                    hasColor = false
                                } else {
                                    hasColor = true
                                    zoneColor = .gray
                                }
                            }
                        } label: {
                            Image(systemName: hasColor ? "circle.slash" : "circle.slash.fill")
                                .font(.title3)
                                .foregroundStyle(hasColor ? Color.secondary : Color.red)
                        }
                        .buttonStyle(.plain)
                    }
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
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }
}
