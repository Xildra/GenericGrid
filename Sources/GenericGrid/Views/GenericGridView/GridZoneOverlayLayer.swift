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
    let config: GridCanvasConfig
    let zones: [GridZoneDefinition]
    let cellSize: CGFloat

    var body: some View {
        ForEach(zones) { zone in
            let x = zone.colStart * cellSize
            let y = config.yForRow(zone.rowStart, cellSize: cellSize)
            let w = (zone.colEnd - zone.colStart) * cellSize
            let h = (zone.rowEnd - zone.rowStart) * cellSize
            let shortSide = min(w, h)
            let labelSize = min(shortSide / GridFont.zoneLabelDivisor, GridFont.zoneLabelMax)
            let iconSize = min(shortSide / GridFont.zoneLabelDivisor, GridFont.ruleIcon)

            ZStack {
                RoundedRectangle(cornerRadius: GridCornerRadius.zone)
                    .fill(zone.color.opacity(GridOpacity.zoneFill))
                RoundedRectangle(cornerRadius: GridCornerRadius.zone)
                    .strokeBorder(strokeColor(for: zone), lineWidth: GridLineWidth.zoneDefault)

                VStack(spacing: GridLayout.zoneLabelSpacing) {
                    Text(zone.label)
                        .font(.system(size: labelSize, weight: .medium))
                        .foregroundStyle(.secondary)
                    if zone.rule == .locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: iconSize))
                            .foregroundStyle(.secondary.opacity(GridOpacity.ruleIconLock))
                    } else if zone.rule == .forbidden {
                        Image(systemName: "nosign")
                            .font(.system(size: iconSize))
                            .foregroundStyle(.red.opacity(GridOpacity.ruleIconForbidden))
                    }
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: GridCornerRadius.zone))
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
