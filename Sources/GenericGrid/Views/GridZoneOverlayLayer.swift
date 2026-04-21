//
//  GridZoneOverlayLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Renders coloured zone overlays with labels and rule icons.
//

import SwiftUI

struct GridZoneOverlayLayer: View {
    let zones: [GridZoneDefinition]
    let cellSize: CGFloat

    var body: some View {
        ForEach(zones) { zone in
            let x = zone.colStart * cellSize
            let y = zone.rowStart * cellSize
            let w = (zone.colEnd - zone.colStart) * cellSize
            let h = (zone.rowEnd - zone.rowStart) * cellSize

            ZStack {
                RoundedRectangle(cornerRadius: GridCornerRadius.zone)
                    .fill(zone.color.opacity(GridOpacity.zoneFill))
                RoundedRectangle(cornerRadius: GridCornerRadius.zone)
                    .strokeBorder(strokeColor(for: zone), lineWidth: GridLineWidth.zoneDefault)

                VStack(spacing: GridLayout.zoneLabelSpacing) {
                    Text(zone.label)
                        .font(.system(size: min(w / GridFont.zoneLabelDivisor, GridFont.zoneLabelMax), weight: .medium))
                        .foregroundStyle(.secondary)
                    if zone.rule == .locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: GridFont.ruleIcon))
                            .foregroundStyle(.secondary.opacity(GridOpacity.ruleIconLock))
                    } else if zone.rule == .forbidden {
                        Image(systemName: "nosign")
                            .font(.system(size: GridFont.ruleIcon))
                            .foregroundStyle(.red.opacity(GridOpacity.ruleIconForbidden))
                    }
                }
            }
            .frame(width: w, height: h)
            .offset(x: x, y: y)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Styling helpers

    private func strokeColor(for zone: GridZoneDefinition) -> Color {
        switch zone.rule {
        case .locked:     return .orange.opacity(GridOpacity.zoneStrokeLocked)
        case .forbidden:  return .red.opacity(GridOpacity.zoneStrokeForbidden)
        case .restricted: return .blue.opacity(GridOpacity.zoneStrokeRestricted)
        case .free:       return zone.color.opacity(GridOpacity.zoneStrokeFree)
        }
    }

}
