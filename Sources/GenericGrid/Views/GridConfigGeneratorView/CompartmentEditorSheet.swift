//
//  CompartmentEditorSheet.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Modal sheet for editing a compartment (column band): its row
//  range (boundaries with its neighbours) and its column titles.
//  Changes apply live to the bound config.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CompartmentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var config: GridCanvasConfig
    let bandID: UUID

    private var bands: [ColumnBand] { config.effectiveBands }
    private var bandIndex: Int? { bands.firstIndex(where: { $0.id == bandID }) }
    private var band: ColumnBand? { bands.first(where: { $0.id == bandID }) }

    var body: some View {
        NavigationStack {
            Form {
                if let band, let idx = bandIndex {
                    rangeSection(band: band, index: idx)
                    columnsSection(band: band, index: idx)
                    labelsSection(band: band)
                }
            }
            .navigationTitle("Compartment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Reset titles", role: .destructive) {
                        config.updateBandLabels(id: bandID, labels: nil)
                    }
                }
            }
        }
    }

    // MARK: - Range

    @ViewBuilder
    private func rangeSection(band: ColumnBand, index: Int) -> some View {
        let canEditStart = index > 0
        let canEditEnd = index < bands.count - 1

        if canEditStart || canEditEnd {
            Section {
                if canEditStart {
                    firstRowStepper(band: band, index: index)
                }
                if canEditEnd {
                    lastRowStepper(band: band, index: index)
                }
            } header: {
                Text("Range")
            } footer: {
                Text("Moving a boundary grows or shrinks the neighbouring compartment accordingly.")
                    .font(.caption2)
            }
        } else {
            Section {
                LabeledContent("Rows") {
                    Text("\(band.rowStart + 1)–\(band.rowEnd + 1)")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
            } header: {
                Text("Range")
            } footer: {
                Text("Split the grid first to create more compartments before resizing.")
                    .font(.caption2)
            }
        }
    }

    private func firstRowStepper(band: ColumnBand, index: Int) -> some View {
        let prev = bands[index - 1]
        let minStart = prev.rowStart + 1          // predecessor keeps ≥ 1 row
        let maxStart = band.rowEnd                 // this band keeps ≥ 1 row
        return Stepper(
            value: Binding(
                get: { band.rowStart + 1 },
                set: { config.setBandStart(at: index, rowStart: $0 - 1) }
            ),
            in: (minStart + 1)...(maxStart + 1)
        ) {
            rangeLabel("First row", value: band.rowStart + 1)
        }
    }

    private func lastRowStepper(band: ColumnBand, index: Int) -> some View {
        let next = bands[index + 1]
        let minEnd = band.rowStart                 // this band keeps ≥ 1 row
        let maxEnd = next.rowEnd - 1               // successor keeps ≥ 1 row
        return Stepper(
            value: Binding(
                get: { band.rowEnd + 1 },
                set: { config.setBandEnd(at: index, rowEnd: $0 - 1) }
            ),
            in: (minEnd + 1)...(maxEnd + 1)
        ) {
            rangeLabel("Last row", value: band.rowEnd + 1)
        }
    }

    private func rangeLabel(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)").monospacedDigit().foregroundStyle(.secondary)
        }
    }

    // MARK: - Columns

    @ViewBuilder
    private func columnsSection(band: ColumnBand, index: Int) -> some View {
        let bandCols = band.effectiveCols(default: config.cols)
        let isOverridden = band.cols != nil
        Section {
            Stepper(
                value: Binding(
                    get: { bandCols },
                    set: { config.setBandCols(at: index, cols: $0) }
                ),
                in: 1...GridDefaults.stepperMax
            ) {
                HStack {
                    Text("Columns")
                    Spacer()
                    Text("\(bandCols)").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if isOverridden {
                Button("Use grid default (\(config.cols))") {
                    config.setBandCols(at: index, cols: nil)
                }
            }
        } header: {
            Text("Columns")
        } footer: {
            Text("Overrides the grid's column count for this compartment only — cells get wider when the count is lower.")
                .font(.caption2)
        }
    }

    // MARK: - Labels

    private func labelsSection(band: ColumnBand) -> some View {
        let bandCols = band.effectiveCols(default: config.cols)
        return Section("Column titles") {
            ForEach(0..<bandCols, id: \.self) { i in
                HStack {
                    Text("\(i + 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    TextField("Title \(i + 1)", text: labelBinding(band: band, index: i))
                }
            }
        }
    }

    private func labelBinding(band: ColumnBand, index: Int) -> Binding<String> {
        let bandCols = band.effectiveCols(default: config.cols)
        return Binding(
            get: {
                if let labels = band.labels, index < labels.count {
                    return labels[index]
                }
                return band.colLabel(at: index)
            },
            set: { newValue in
                var next = band.labels ?? (0..<bandCols).map { band.colLabel(at: $0) }
                while next.count <= index { next.append("") }
                next[index] = newValue
                config.updateBandLabels(id: bandID, labels: next)
            }
        )
    }
}
