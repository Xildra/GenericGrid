//
//  CompartmentsSection.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Sidebar section mirroring the grid hierarchy:
//  Grid → Compartments → Zones. Each compartment is a DisclosureGroup
//  whose content lists the zones it contains, with per-compartment
//  "Edit compartment" and "Add zone" affordances. Swipe a compartment
//  to merge it with a neighbour; swipe a zone to delete it.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CompartmentsSection: View {
    @Binding var config: GridCanvasConfig
    @Binding var editingBand: EditingBandRef?
    @Binding var showSplitSheet: Bool
    @Binding var splitRow: Int

    /// Expanded compartment ids — ephemeral UI state, not persisted.
    @State private var expanded: Set<UUID> = []

    var onEditZone: (GridZoneDefinition) -> Void
    var onAddZone: (ColumnBand) -> Void

    var body: some View {
        Section {
            ForEach(config.effectiveBands) { band in
                compartmentDisclosure(band)
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

    // MARK: - Header

    private var header: some View {
        let count = config.effectiveBands.count
        return HStack {
            Text("Compartments")
            Spacer()
            if count > 1 {
                Text("\(count) compartments")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Compartment disclosure

    private func compartmentDisclosure(_ band: ColumnBand) -> some View {
        DisclosureGroup(isExpanded: expandBinding(for: band.id)) {
            Button {
                config.promoteToColumnBandsIfNeeded()
                editingBand = EditingBandRef(id: band.id)
            } label: {
                Label("Edit compartment", systemImage: "slider.horizontal.3")
            }
            .tint(.primary)

            let zones = zones(in: band)
            ForEach(zones) { zone in
                zoneRow(zone)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteZone(zone)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            if zones.isEmpty {
                Text("No zones yet")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Button {
                onAddZone(band)
            } label: {
                Label("Add zone", systemImage: "plus.circle")
            }
        } label: {
            compartmentLabel(band)
        }
    }

    private func compartmentLabel(_ band: ColumnBand) -> some View {
        let zoneCount = zones(in: band).count
        return HStack(spacing: 10) {
            Text("Rows \(band.rowStart + 1)–\(band.rowEnd + 1)")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .layoutPriority(1)
            Text(labelPreview(for: band))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            if zoneCount > 0 {
                Text("\(zoneCount)")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func zoneRow(_ zone: GridZoneDefinition) -> some View {
        Button {
            onEditZone(zone)
        } label: {
            HStack(spacing: 10) {
                Circle().fill(zone.color)
                    .frame(width: GridLayout.colorCircleSize, height: GridLayout.colorCircleSize)
                Text(zone.label).font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }

    // MARK: - Data helpers

    /// Zones belonging to the given compartment. Reads straight from
    /// the band's nested storage — the model enforces the invariant.
    private func zones(in band: ColumnBand) -> [GridZoneDefinition] {
        band.zones
    }

    private func deleteZone(_ zone: GridZoneDefinition) {
        config.removeZone(id: zone.id)
    }

    private func expandBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { isOn in
                if isOn { expanded.insert(id) } else { expanded.remove(id) }
            }
        )
    }

    /// All column titles of the band on one line — truncation at the
    /// row level handles overflow. Uses the band's own column count.
    private func labelPreview(for band: ColumnBand) -> String {
        let bandCols = band.effectiveCols(default: config.cols)
        return (0..<bandCols)
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
