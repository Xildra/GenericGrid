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
    let config: GridCanvasConfig
    let items: [Item]
    let cellSize: CGFloat
    let movingItem: Item?

    var body: some View {
        ForEach(items) { item in
            if let t = item.itemType {
                GenericItemBlock(
                    item: item, type: t, cellSize: cellSize,
                    yOrigin: config.yForRow(item.anchorRow, cellSize: cellSize),
                    dimmed: movingItem === item
                )
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Generic block for a single placed item

struct GenericItemBlock<T: GridItemType>: View {
    let anchorCol: Double
    let effWidth: Int
    let effHeight: Int
    let type: T
    let cellSize: CGFloat
    let yOrigin: CGFloat
    var dimmed: Bool = false

    init<I: GridPlaceable>(item: I, type: T, cellSize: CGFloat,
                           yOrigin: CGFloat,
                           dimmed: Bool = false) where I.ItemType == T {
        self.anchorCol = item.anchorCol
        self.effWidth = item.effectiveWidth
        self.effHeight = item.effectiveHeight
        self.type = type
        self.cellSize = cellSize
        self.yOrigin = yOrigin
        self.dimmed = dimmed
    }

    var body: some View {
        let inset = GridLayout.itemBlockInset
        let w  = CGFloat(effWidth)  * cellSize - inset * 2
        let h  = CGFloat(effHeight) * cellSize - inset * 2
        let ox = anchorCol * cellSize + inset
        let oy = yOrigin + inset

        RoundedRectangle(cornerRadius: GridCornerRadius.item)
            .fill(type.color.opacity(dimmed ? GridOpacity.itemDimmedFill : GridOpacity.itemFill))
            .overlay(
                RoundedRectangle(cornerRadius: GridCornerRadius.item)
                    .stroke(type.color.opacity(dimmed ? GridOpacity.itemStrokeDimmed : 1),
                            lineWidth: dimmed ? GridLineWidth.itemDimmed : GridLineWidth.item)
            )
            .overlay(
                VStack(spacing: 1) {
                    Text(type.name)
                        .font(.system(size: fontSize(w, h), weight: .semibold))
                        .foregroundStyle(type.color.opacity(dimmed ? GridOpacity.itemTextDimmed : 1))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                    Text(type.label)
                        .font(.system(size: max(fontSize(w, h) - GridFont.itemSubtitleOffset, GridFont.itemSubtitleMin), weight: .regular, design: .monospaced))
                        .foregroundStyle(type.color.opacity(dimmed ? GridOpacity.itemSubtextDimmed : GridOpacity.itemSubtext))
                }
                .padding(3)
            )
            .frame(width: w, height: h)
            .offset(x: ox, y: oy)
    }

    private func fontSize(_ w: CGFloat, _ h: CGFloat) -> CGFloat {
        min(w / GridFont.itemNameWidthDiv, h / GridFont.itemNameHeightDiv, GridFont.itemNameMax)
    }
}
