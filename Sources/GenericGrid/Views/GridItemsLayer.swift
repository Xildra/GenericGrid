//
//  GridItemsLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Renders all placed items on the grid.
//  Items currently being moved are displayed dimmed.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridItemsLayer<Item: GridPlaceable>: View {
    let items: [Item]
    let cellSize: CGFloat
    let movingItem: Item?

    var body: some View {
        ForEach(items) { item in
            if let t = item.itemType {
                GenericItemBlock(
                    item: item, type: t, cellSize: cellSize,
                    dimmed: movingItem === item
                )
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Generic block for a single placed item

struct GenericItemBlock<T: GridItemType>: View {
    let anchorRow: Int
    let anchorCol: Int
    let effWidth: Int
    let effHeight: Int
    let type: T
    let cellSize: CGFloat
    var dimmed: Bool = false

    init<I: GridPlaceable>(item: I, type: T, cellSize: CGFloat, dimmed: Bool = false) where I.ItemType == T {
        self.anchorRow = item.anchorRow
        self.anchorCol = item.anchorCol
        self.effWidth = item.effectiveWidth
        self.effHeight = item.effectiveHeight
        self.type = type
        self.cellSize = cellSize
        self.dimmed = dimmed
    }

    var body: some View {
        let w  = CGFloat(effWidth)  * cellSize - 4
        let h  = CGFloat(effHeight) * cellSize - 4
        let ox = CGFloat(anchorCol) * cellSize + 2
        let oy = CGFloat(anchorRow) * cellSize + 2

        RoundedRectangle(cornerRadius: 7)
            .fill(type.color.opacity(dimmed ? 0.08 : 0.16))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(type.color.opacity(dimmed ? 0.3 : 1), lineWidth: dimmed ? 1 : 1.5)
            )
            .overlay(
                VStack(spacing: 1) {
                    Text(type.name)
                        .font(.system(size: fontSize(w, h), weight: .semibold))
                        .foregroundStyle(type.color.opacity(dimmed ? 0.4 : 1))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                    Text(type.label)
                        .font(.system(size: max(fontSize(w, h) - 2, 7), weight: .regular, design: .monospaced))
                        .foregroundStyle(type.color.opacity(dimmed ? 0.3 : 0.6))
                }
                .padding(3)
            )
            .frame(width: w, height: h)
            .offset(x: ox, y: oy)
    }

    private func fontSize(_ w: CGFloat, _ h: CGFloat) -> CGFloat {
        min(w / 4, h / 2.5, 12)
    }
}
