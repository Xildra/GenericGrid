//
//  CompartmentEditorSheet.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Modal sheet for editing a 2D compartment: its row range AND its
//  column range (boundaries with its neighbours along each axis),
//  its subdivision count override, and its column titles. Buttons
//  also expose horizontal / vertical splits directly from the band.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CompartmentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var config: GridCanvasConfig
    let bandID: UUID

    private var bands: [ColumnBand] { config.effectiveBands }
    private var band: ColumnBand? { bands.first(where: { $0.id == bandID }) }

    var body: some View {
        NavigationStack {
            Form {
                if let band {
                    rangeSection(band: band)
                    splitsSection(band: band)
                    columnsSection(band: band)
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
    private func rangeSection(band: ColumnBand) -> some View {
        let canResizeTop    = config.canResizeRowStart(bandID: band.id)
        let canResizeBot    = config.canResizeRowEnd(bandID: band.id)
        let canResizeLeft   = config.canResizeColStart(bandID: band.id)
        let canResizeRight  = config.canResizeColEnd(bandID: band.id)
        let canResizeAny    = canResizeTop || canResizeBot || canResizeLeft || canResizeRight

        if canResizeAny {
            Section {
                if canResizeTop    { firstRowStepper(band: band) }
                if canResizeBot    { lastRowStepper(band: band) }
                if canResizeLeft   { firstColStepper(band: band) }
                if canResizeRight  { lastColStepper(band: band) }
            } header: {
                Text("Range")
            } footer: {
                Text("Moving a boundary grows or shrinks the neighbouring compartment along that edge.")
                    .font(.caption2)
            }
        } else {
            Section {
                LabeledContent("Rows") {
                    Text("\(band.rowStart + 1)–\(band.rowEnd + 1)")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                LabeledContent("Columns") {
                    Text("\(band.colStart + 1)–\(band.colEnd + 1)")
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

    private func firstRowStepper(band: ColumnBand) -> some View {
        Stepper(
            value: Binding(
                get: { band.rowStart + 1 },
                set: { config.setBandRowStart(id: band.id, newStart: $0 - 1) }
            ),
            in: 2...(band.rowEnd + 1)
        ) {
            rangeLabel("First row", value: band.rowStart + 1)
        }
    }

    private func lastRowStepper(band: ColumnBand) -> some View {
        Stepper(
            value: Binding(
                get: { band.rowEnd + 1 },
                set: { config.setBandRowEnd(id: band.id, newEnd: $0 - 1) }
            ),
            in: (band.rowStart + 1)...config.rows
        ) {
            rangeLabel("Last row", value: band.rowEnd + 1)
        }
    }

    private func firstColStepper(band: ColumnBand) -> some View {
        Stepper(
            value: Binding(
                get: { band.colStart + 1 },
                set: { config.setBandColStart(id: band.id, newStart: $0 - 1) }
            ),
            in: 2...(band.colEnd + 1)
        ) {
            rangeLabel("First column", value: band.colStart + 1)
        }
    }

    private func lastColStepper(band: ColumnBand) -> some View {
        Stepper(
            value: Binding(
                get: { band.colEnd + 1 },
                set: { config.setBandColEnd(id: band.id, newEnd: $0 - 1) }
            ),
            in: (band.colStart + 1)...config.cols
        ) {
            rangeLabel("Last column", value: band.colEnd + 1)
        }
    }

    private func rangeLabel(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)").monospacedDigit().foregroundStyle(.secondary)
        }
    }

    // MARK: - Splits

    @ViewBuilder
    private func splitsSection(band: ColumnBand) -> some View {
        let canSplitH = band.rowCount >= 2
        let canSplitV = band.colCount >= 2
        if canSplitH || canSplitV {
            Section {
                if canSplitH {
                    Button {
                        let row = band.rowStart + max(1, band.rowCount / 2)
                        config.splitBand(id: band.id, atRow: row)
                    } label: {
                        Label("Split horizontally", systemImage: "rectangle.split.1x2")
                    }
                }
                if canSplitV {
                    Button {
                        let col = band.colStart + max(1, band.colCount / 2)
                        config.splitBand(id: band.id, atCol: col)
                    } label: {
                        Label("Split vertically", systemImage: "rectangle.split.2x1")
                    }
                }
            } header: {
                Text("Split")
            } footer: {
                Text("Splits cut this compartment in half along the chosen axis. Use the range steppers above to fine-tune the boundary.")
                    .font(.caption2)
            }
        }
    }

    // MARK: - Columns

    @ViewBuilder
    private func columnsSection(band: ColumnBand) -> some View {
        let bandCols = band.effectiveCols(default: config.cols)
        let natural = max(1, band.colCount)
        let isOverridden = band.cols != nil
        Section {
            Stepper(
                value: Binding(
                    get: { bandCols },
                    set: { config.setBandCols(id: band.id, cols: $0) }
                ),
                in: 1...GridDefaults.stepperMax
            ) {
                HStack {
                    Text("Subdivisions")
                    Spacer()
                    Text("\(bandCols)").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if isOverridden {
                Button("Use natural width (\(natural))") {
                    config.setBandCols(id: band.id, cols: nil)
                }
            }
        } header: {
            Text("Subdivisions")
        } footer: {
            Text("Overrides how the compartment's horizontal extent is divided — cells get wider when the count is lower than the natural width.")
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
