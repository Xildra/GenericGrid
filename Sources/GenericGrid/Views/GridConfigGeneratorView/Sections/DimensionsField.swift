//
//  DimensionsField.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Compact 3-row control for the grid dimensions:
//  labels / values with `×` separator / paired steppers.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DimensionsField: View {
    @Binding var rows: Int
    @Binding var cols: Int
    @FocusState.Binding var focusedField: Bool

    private let separatorWidth: CGFloat = 24

    var body: some View {
        VStack(spacing: 6) {
            labelsRow
            valuesRow
            steppersRow
        }
    }

    private var labelsRow: some View {
        HStack(spacing: 0) {
            Text("Rows")
                .frame(maxWidth: .infinity)
                .font(.caption).foregroundStyle(.secondary)
            Color.clear.frame(width: separatorWidth)
            Text("Columns")
                .frame(maxWidth: .infinity)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var valuesRow: some View {
        HStack(spacing: 0) {
            countField(value: $rows)
            Text("×")
                .frame(width: separatorWidth)
                .foregroundStyle(.secondary)
            countField(value: $cols)
        }
        .font(.title3.monospacedDigit())
    }

    private var steppersRow: some View {
        HStack(spacing: 0) {
            Stepper("", value: $rows, in: 1...GridDefaults.stepperMax)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: separatorWidth)
            Stepper("", value: $cols, in: 1...GridDefaults.stepperMax)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private func countField(value: Binding<Int>) -> some View {
        TextField("", value: value, format: .number)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .focused($focusedField)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
    }
}
