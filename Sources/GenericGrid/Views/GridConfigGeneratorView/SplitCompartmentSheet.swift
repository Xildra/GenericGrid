//
//  SplitCompartmentSheet.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Modal sheet for picking a row at which to split the current
//  compartment into two.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct SplitCompartmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var splitRow: Int
    let totalRows: Int
    let onConfirm: (Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $splitRow, in: 1...max(1, totalRows - 1)) {
                        HStack {
                            Text("Split at row")
                            Spacer()
                            Text("\(splitRow + 1)")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Creates a new compartment starting at this row. The current compartment keeps the rows above.")
                        .font(.caption2)
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
                        onConfirm(splitRow)
                        dismiss()
                    }
                }
            }
        }
    }
}
