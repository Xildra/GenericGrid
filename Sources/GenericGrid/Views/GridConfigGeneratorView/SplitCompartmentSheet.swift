//
//  SplitCompartmentSheet.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Modal sheet for splitting a compartment in two. Bands are 2D, so
//  the user picks both the direction (horizontal at a row boundary,
//  vertical at a column boundary) and the position. The selected
//  band id targets the specific compartment being split — when no
//  band id is set the first valid one is chosen.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct SplitCompartmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum Axis: Hashable {
        case horizontal
        case vertical
    }

    let config: GridCanvasConfig
    /// Band targeted by the split. When nil we pick the first splittable
    /// band along the chosen axis.
    let bandID: UUID?

    let onConfirm: (UUID, Axis, Int) -> Void

    @State private var axis: Axis = .horizontal
    @State private var splitPos: Int = 1

    private var bands: [ColumnBand] { config.effectiveBands }

    /// Target band, choosing the largest splittable one along the
    /// current axis when no explicit id was supplied.
    private var targetBand: ColumnBand? {
        if let id = bandID, let band = bands.first(where: { $0.id == id }) {
            return band
        }
        switch axis {
        case .horizontal:
            return bands.filter { $0.rowCount >= 2 }.max(by: { $0.rowCount < $1.rowCount })
        case .vertical:
            return bands.filter { $0.colCount >= 2 }.max(by: { $0.colCount < $1.colCount })
        }
    }

    private var range: ClosedRange<Int> {
        guard let band = targetBand else { return 1...1 }
        switch axis {
        case .horizontal: return (band.rowStart + 1)...band.rowEnd
        case .vertical:   return (band.colStart + 1)...band.colEnd
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Direction", selection: $axis) {
                        Text("Horizontal").tag(Axis.horizontal)
                        Text("Vertical").tag(Axis.vertical)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: axis) { _, _ in resetSplitPos() }
                } footer: {
                    Text(axis == .horizontal
                         ? "Horizontal splits cut the compartment at a row boundary."
                         : "Vertical splits cut the compartment at a column boundary.")
                        .font(.caption2)
                }

                if let band = targetBand {
                    Section {
                        Stepper(value: $splitPos, in: range) {
                            HStack {
                                Text(axis == .horizontal ? "Split at row" : "Split at column")
                                Spacer()
                                Text("\(splitPos + 1)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        Text("Target compartment: \(compartmentDescription(band))")
                            .font(.caption2)
                    }
                } else {
                    Section {
                        Text("No compartment can be split along this axis. Resize the grid or pick the other direction.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Split compartment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Split") {
                        if let band = targetBand {
                            onConfirm(band.id, axis, splitPos)
                            dismiss()
                        }
                    }
                    .disabled(targetBand == nil)
                }
            }
            .onAppear { resetSplitPos() }
        }
    }

    private func resetSplitPos() {
        guard let band = targetBand else { splitPos = 1; return }
        switch axis {
        case .horizontal:
            splitPos = band.rowStart + max(1, band.rowCount / 2)
        case .vertical:
            splitPos = band.colStart + max(1, band.colCount / 2)
        }
        if !range.contains(splitPos) {
            splitPos = range.lowerBound
        }
    }

    private func compartmentDescription(_ band: ColumnBand) -> String {
        "Rows \(band.rowStart + 1)–\(band.rowEnd + 1) · Cols \(band.colStart + 1)–\(band.colEnd + 1)"
    }
}
