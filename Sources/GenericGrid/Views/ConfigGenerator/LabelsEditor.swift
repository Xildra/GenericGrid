//
//  LabelsEditor.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Sheet editor for custom row / column labels.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct LabelsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let kind: String
    let count: Int
    @State private var labels: [String]
    let onSave: ([String]) -> Void

    init(kind: String, count: Int, labels: [String], onSave: @escaping ([String]) -> Void) {
        self.kind = kind
        self.count = count
        self.onSave = onSave
        // Pad to count if needed
        var padded = labels
        while padded.count < count { padded.append("") }
        self.labels = padded
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<count, id: \.self) { i in
                    HStack {
                        Text("\(i)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        TextField("\(kind) \(i)", text: $labels[i])
                    }
                }
            }
            .navigationTitle("\(kind) Labels")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(labels)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Reset", role: .destructive) {
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}
