//
//  GenericStatsBlock.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Displays grid occupancy statistics (per cell or per zone) with a
//  colour-coded progress bar.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GenericStatsBlock<Item: GridPlaceable>: View {

    /// What the block counts: individual cells, or whole zones (slots).
    public enum Mode: Sendable { case cells, zones }

    let engine: GridEngine<Item>
    let mode: Mode

    public init(engine: GridEngine<Item>, mode: Mode = .cells) {
        self.engine = engine
        self.mode = mode
    }

    public var body: some View {
        VStack(spacing: GridLayout.statsSpacing) {
            HStack {
                stat("Used",  value: "\(used)")
                Divider()
                stat("Free",  value: "\(free)")
                Divider()
                stat("Total", value: "\(total)")
            }
            .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: fill)
                .tint(fill < GridOpacity.statsFillMedium ? .green : fill < GridOpacity.statsFillHigh ? .orange : .red)
            Text("\(Int(fill * 100))% \(mode == .cells ? "filled" : "zones used")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, GridLayout.statsVerticalPadding)
    }

    // MARK: - Values per mode

    /// Occupied count: filled cells, or placeable zones holding at least one
    /// item (locked / forbidden zones are excluded — they can't be filled).
    private var used: Int {
        switch mode {
        case .cells: engine.usedCells
        case .zones: engine.placeableZones.count(where: { !engine.isZoneEmpty($0) })
        }
    }

    /// Total count: placeable cells, or placeable zones (excludes locked /
    /// forbidden so `free = total - used` is correct).
    private var total: Int {
        mode == .cells ? engine.totalCells : engine.placeableZones.count
    }

    private var free: Int { max(0, total - used) }

    private var fill: Double { total > 0 ? Double(used) / Double(total) : 0 }

    private func stat(_ label: String, value: String) -> some View {
        VStack(spacing: GridLayout.statItemSpacing) {
            Text(value).font(.headline).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
