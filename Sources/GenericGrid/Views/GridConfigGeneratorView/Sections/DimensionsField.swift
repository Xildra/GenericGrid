//
//  DimensionsField.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Compact 3-row control for the grid dimensions:
//  labels / values with `×` separator / paired steppers.
//  TextField edits are buffered and committed on submit/blur so
//  intermediate partial values (e.g. "1" while typing "12") don't
//  trigger destructive resizes of compartments and zones.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DimensionsField: View {
    @Binding var rows: Int
    @Binding var cols: Int
    @FocusState.Binding var focusedField: Bool

    @State private var rowsText: String = ""
    @State private var colsText: String = ""
    @FocusState private var rowsFocused: Bool
    @FocusState private var colsFocused: Bool

    private let separatorWidth: CGFloat = 24

    var body: some View {
        VStack(spacing: 6) {
            labelsRow
            valuesRow
            steppersRow
        }
        .onAppear { syncText() }
        .onChange(of: rows) { _, _ in if !rowsFocused { syncText() } }
        .onChange(of: cols) { _, _ in if !colsFocused { syncText() } }
        .onChange(of: rowsFocused) { _, isFocused in
            if !isFocused { commitRows() }
        }
        .onChange(of: colsFocused) { _, isFocused in
            if !isFocused { commitCols() }
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
            rowsField
            Text("×")
                .frame(width: separatorWidth)
                .foregroundStyle(.secondary)
            colsField
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

    private var rowsField: some View {
        TextField("", text: $rowsText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .focused($rowsFocused)
            .focused($focusedField)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onSubmit { commitRows() }
    }

    private var colsField: some View {
        TextField("", text: $colsText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .focused($colsFocused)
            .focused($focusedField)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onSubmit { commitCols() }
    }

    private func syncText() {
        rowsText = "\(rows)"
        colsText = "\(cols)"
    }

    private func commitRows() {
        if let parsed = Int(rowsText.trimmingCharacters(in: .whitespaces)), parsed > 0 {
            rows = parsed
        }
        rowsText = "\(rows)"
    }

    private func commitCols() {
        if let parsed = Int(colsText.trimmingCharacters(in: .whitespaces)), parsed > 0 {
            cols = parsed
        }
        colsText = "\(cols)"
    }
}
