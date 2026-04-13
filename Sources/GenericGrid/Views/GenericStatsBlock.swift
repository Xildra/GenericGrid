//
//  GenericStatsBlock.swift
//  GenericGrid Module
//
//  Displays grid occupancy statistics with a colour-coded progress bar.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GenericStatsBlock<Item: GridPlaceable>: View {
    let engine: GridEngine<Item>

    public init(engine: GridEngine<Item>) { self.engine = engine }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                stat("Used",  value: "\(engine.usedCells)")
                Divider()
                stat("Free",  value: "\(engine.freeCells)")
                Divider()
                stat("Total", value: "\(engine.totalCells)")
            }
            .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: engine.fillPct)
                .tint(engine.fillPct < 0.5 ? .green : engine.fillPct < 0.8 ? .orange : .red)
            Text("\(Int(engine.fillPct * 100))% filled")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
