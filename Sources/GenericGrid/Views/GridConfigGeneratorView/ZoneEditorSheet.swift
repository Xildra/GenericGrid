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
    private let targetBandID: UUID?
    private let onSave: (GridZoneDefinition) -> Void

    /// Effective column count for the zone's current compartment.
    private var maxCols: Int { config.cols(for: currentBand) }
    private var bands: [ColumnBand] { config.effectiveBands }

    /// Band currently owning the zone — id-based for persisted zones,
    /// fallback to the seed `targetBandID` for new ones, finally to a
    /// row-based lookup so legacy single-band configs keep working.
    private var currentBand: ColumnBand {
        if !isNew, let band = config.band(forZoneID: zone.id) { return band }
        if let id = targetBandID,
           let band = bands.first(where: { $0.id == id }) { return band }
        return config.band(forRow: Int(zone.rowStart.rounded(.down)))
    }

    /// Row-range bounds within the current band (lo inclusive, hi exclusive).
    private var bandRowBounds: (lo: Double, hi: Double) {
        (Double(currentBand.rowStart), Double(currentBand.rowEnd + 1))
    }

    init(zone: GridZoneDefinition?,
         config: GridCanvasConfig,
         targetBandID: UUID? = nil,
         onSave: @escaping (GridZoneDefinition) -> Void) {
        self.config = config
        self.targetBandID = targetBandID
        self.onSave = onSave

        let defaultEnd = min(GridDefaults.newZoneEnd, Double(config.rows))
        let seed = zone ?? GridZoneDefinition(
            rowEnd: defaultEnd,
            colEnd: min(GridDefaults.newZoneEnd, Double(config.cols))
        )
        self.zone = seed
        // "New" means the zone isn't persisted yet — detected by id, so a
        // pre-seeded default zone still shows the "New Zone" title.
        self.isNew = !config.containsZone(id: seed.id)
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
    /// when the user changes it. Both axes are clamped: rows to the
    /// target band's row range, columns to its (possibly different)
    /// column count.
    private var compartmentBinding: Binding<Int> {
        Binding(
            get: {
                bands.firstIndex(where: { $0.id == currentBand.id }) ?? 0
            },
            set: { idx in
                guard idx >= 0, idx < bands.count else { return }
                let target = bands[idx]
                let rowSize = min(Double(zone.rowCount), Double(target.rowCount))
                zone.rowStart = Double(target.rowStart)
                zone.rowEnd = zone.rowStart + rowSize

                let targetCols = target.effectiveCols(default: config.cols)
                let colSize = min(Double(zone.colCount), Double(targetCols))
                zone.colStart = max(0, min(zone.colStart, Double(targetCols) - colSize))
                zone.colEnd = zone.colStart + colSize
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
                                Text(compartmentLabel(band))
                                    .tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
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
                    // Title is optional — saving a zone with an empty
                    // label is fine; only the geometry must be valid.
                    .disabled(zone.rowEnd <= zone.rowStart || zone.colEnd <= zone.colStart)
                }
            }
            .scrollDismissesKeyboard(.interactively)
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

    /// Label for the compartment picker. Shows the row range and adds
    /// the column range when the grid has more than one column-strip
    /// (i.e. some bands were split vertically), so 2D compartments are
    /// distinguishable.
    private func compartmentLabel(_ band: ColumnBand) -> String {
        let rows = "Rows \(band.rowStart + 1)–\(band.rowEnd + 1)"
        let hasVerticalSplits = bands.contains { $0.colStart != 0 || $0.colEnd != config.cols - 1 }
        if hasVerticalSplits {
            return rows + " · Cols \(band.colStart + 1)–\(band.colEnd + 1)"
        }
        return rows
    }
}
