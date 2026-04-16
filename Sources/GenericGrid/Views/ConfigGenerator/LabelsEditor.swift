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
    let onReset: (() -> Void)?

    init(kind: String, count: Int, labels: [String],
         onSave: @escaping ([String]) -> Void,
         onReset: (() -> Void)? = nil) {
        self.kind = kind
        self.count = count
        self.onSave = onSave
        self.onReset = onReset
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
						var index = i + 1
						
						Text(index.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
							.fixedSize()
                            .frame(alignment: .trailing)
                        TextField("\(kind) \(index)", text: $labels[i])
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
                        onReset?()
                        dismiss()
                    }
                }
            }
        }
    }
}
