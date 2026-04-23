//
//  ZonesListSection.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Sidebar section listing the zones of the current config with an
//  "Add zone" entry point. Each row is a compact color-dot + name.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ZonesListSection: View {
    @Binding var config: GridCanvasConfig
    var onSelectZone: (GridZoneDefinition?) -> Void

    var body: some View {
        Section {
            ForEach(config.zones) { zone in
                zoneRow(zone)
            }
            .onDelete { idx in config.zones.remove(atOffsets: idx) }

            Button {
                onSelectZone(nil)
            } label: {
                Label("Add zone", systemImage: "plus.circle")
            }
        } header: {
            Text("Zones (\(config.zones.count))")
        } footer: {
            if !config.zones.isEmpty {
                Text("Drag zones directly on the preview to move them. Tap to edit. Use the handles at edges to resize.")
                    .font(.caption2)
            }
        }
    }

    private func zoneRow(_ zone: GridZoneDefinition) -> some View {
        Button {
            onSelectZone(zone)
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
}
