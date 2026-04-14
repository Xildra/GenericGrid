//
//  LabelsEditor.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Inline editor for custom row / column labels.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct LabelsEditor: View {
    let kind: String
    let count: Int
    let labels: [String]
    let onChange: ([String]) -> Void

    var body: some View {
        ForEach(0..<min(count, labels.count), id: \.self) { i in
            TextField("\(kind) \(i)", text: Binding(
                get: { i < labels.count ? labels[i] : "" },
                set: { newVal in
                    var copy = labels
                    while copy.count <= i { copy.append("") }
                    copy[i] = newVal
                    onChange(copy)
                }
            ))
            .font(.caption)
        }
    }
}
