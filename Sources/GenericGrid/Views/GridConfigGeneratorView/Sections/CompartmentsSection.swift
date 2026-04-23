//
//  CompartmentsSection.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Sidebar section listing the grid's compartments (column bands).
//  Tap a row to edit its titles; swipe to merge into a neighbour;
//  use the Split button to open the split sheet.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CompartmentsSection: View {
    @Binding var config: GridCanvasConfig
    @Binding var editingBandID: UUID?
    @Binding var showBandLabelsSheet: Bool
    @Binding var showSplitSheet: Bool
    @Binding var splitRow: Int

    var body: some View {
        Section {
            ForEach(config.effectiveBands) { band in
                compartmentRow(band)
                    .deleteDisabled(config.effectiveBands.count <= 1)
            }
            .onDelete { offsets in
                config.mergeBands(at: offsets)
            }

            Button {
                splitRow = defaultSplitRow()
                showSplitSheet = true
            } label: {
                Label("Split compartment", systemImage: "rectangle.split.1x2")
            }
            .disabled(config.rows < 2)
        } header: {
            header
        }
    }

    private var header: some View {
        let count = config.effectiveBands.count
        return HStack {
            Text("Columns")
            Spacer()
            if count > 1 {
                Text("\(count) compartments")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func compartmentRow(_ band: ColumnBand) -> some View {
        Button {
            editingBandID = band.id
            config.promoteToColumnBandsIfNeeded()
            showBandLabelsSheet = true
        } label: {
            HStack(spacing: 10) {
                Text("Rows \(band.rowStart + 1)–\(band.rowEnd + 1)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .layoutPriority(1)
                Text(labelPreview(for: band))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }

    private func labelPreview(for band: ColumnBand) -> String {
        (0..<min(config.cols, 8))
            .map { band.colLabel(at: $0) }
            .joined(separator: " ")
    }

    /// Middle of the largest existing band, clamped to a valid split row.
    private func defaultSplitRow() -> Int {
        let bands = config.effectiveBands
        let target = bands.max(by: { $0.rowCount < $1.rowCount }) ?? bands[0]
        let mid = target.rowStart + max(1, target.rowCount / 2)
        return min(max(1, mid), config.rows - 1)
    }
}
