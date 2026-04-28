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
                let band = config.band(forRow: Int(item.anchorRow.rounded(.down)))
                GenericItemBlock(
                    item: item, type: t,
                    bandCellWidth: config.bandCellWidth(band, baseCellSize: cellSize),
                    cellHeight: cellSize,
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
    let bandCellWidth: CGFloat
    let cellHeight: CGFloat
    let yOrigin: CGFloat
    var dimmed: Bool = false

    init<I: GridPlaceable>(item: I, type: T,
                           bandCellWidth: CGFloat,
                           cellHeight: CGFloat,
                           yOrigin: CGFloat,
                           dimmed: Bool = false) where I.ItemType == T {
        self.anchorCol = item.anchorCol
        self.effWidth = item.effectiveWidth
        self.effHeight = item.effectiveHeight
        self.type = type
        self.bandCellWidth = bandCellWidth
        self.cellHeight = cellHeight
        self.yOrigin = yOrigin
        self.dimmed = dimmed
    }

    var body: some View {
        let inset = GridLayout.itemBlockInset
        let w  = CGFloat(effWidth)  * bandCellWidth - inset * 2
        let h  = CGFloat(effHeight) * cellHeight - inset * 2
        let ox = CGFloat(anchorCol) * bandCellWidth + inset
        let oy = yOrigin + inset

        // Sober look: solid colour fill (no border, no secondary line)
        // with the item name laid on top in white. Keeps the colour
        // bold and immediately readable while removing the visual noise
        // of the border + double opacity layers.
        RoundedRectangle(cornerRadius: GridCornerRadius.item)
            .fill(type.color.opacity(dimmed ? GridOpacity.itemDimmedFill : 1))
            .overlay(
                Text(type.name)
                    .font(.system(size: fontSize(w, h), weight: .semibold))
                    .foregroundStyle(.white.opacity(dimmed ? GridOpacity.itemTextDimmed : 1))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .padding(3)
            )
            .frame(width: w, height: h)
            .offset(x: ox, y: oy)
    }

    private func fontSize(_ w: CGFloat, _ h: CGFloat) -> CGFloat {
        min(w / GridFont.itemNameWidthDiv, h / GridFont.itemNameHeightDiv, GridFont.itemNameMax)
    }
}
