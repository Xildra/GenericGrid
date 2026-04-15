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
                RoundedRectangle(cornerRadius: 4)
                    .fill((zone.color ?? .gray).opacity(0.12))
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(strokeColor(for: zone), style: strokeStyle(for: zone))

                VStack(spacing: 2) {
                    Text(zone.label)
                        .font(.system(size: min(w / 8, 11), weight: .medium))
                        .foregroundStyle(.secondary)
                    if zone.rule == .locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary.opacity(0.6))
                    } else if zone.rule == .forbidden {
                        Image(systemName: "nosign")
                            .font(.system(size: 9))
                            .foregroundStyle(.red.opacity(0.5))
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
        case .locked:     return .orange.opacity(0.5)
        case .forbidden:  return .red.opacity(0.4)
        case .restricted: return .blue.opacity(0.4)
        case .free:       return (zone.color ?? .gray).opacity(0.3)
        }
    }

    private func strokeStyle(for zone: GridZoneDefinition) -> StrokeStyle {
        switch zone.rule {
        case .locked, .forbidden:
            return StrokeStyle(lineWidth: 1.5, dash: [6, 3])
        default:
            return StrokeStyle(lineWidth: 1)
        }
    }
}
