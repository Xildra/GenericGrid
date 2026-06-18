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
    /// When `true`, an item is drawn filling the zone that contains its anchor
    /// (falls back to its own footprint outside any zone). Purely visual — the
    /// item's stored size is unchanged.
    var fillZone: Bool = false
    /// Fill opacity applied to every item block (1 = opaque).
    var opacity: CGFloat = 1

    var body: some View {
        ForEach(items) { item in
            if let t = item.itemType {
                GenericItemBlock(
                    name: t.name,
                    label: t.label,
                    color: t.color,
                    rect: itemRect(for: item),
                    opacity: opacity,
                    dimmed: movingItem === item
                )
                .allowsHitTesting(false)
            }
        }
    }

    /// Pixel rect of an item: the containing zone when `fillZone` is on and the
    /// anchor sits inside a zone, otherwise the item's own footprint. Mirrors
    /// the band-aware maths used by the zone overlay so the two stay aligned.
    private func itemRect(for item: Item) -> CGRect {
        if fillZone,
           let zone = config.zone(at: GridCell(item.anchorRow, c: item.anchorCol)) {
            return config.zoneRect(zone, cellSize: cellSize)
        }
        let band = config.band(forRow: Int(item.anchorRow.rounded(.down)), atCol: item.anchorCol)
        let bandCellW = config.bandCellWidth(band, baseCellSize: cellSize)
        let localCol = item.anchorCol - Double(band.colStart)
        return CGRect(
            x: config.xForBand(band, baseCellSize: cellSize) + CGFloat(localCol) * bandCellW,
            y: config.yForRow(item.anchorRow, cellSize: cellSize),
            width: CGFloat(item.effectiveWidth) * bandCellW,
            height: CGFloat(item.effectiveHeight) * cellSize)
    }
}

// MARK: - Generic block for a single placed item

struct GenericItemBlock: View {
    let name: String
    let label: String
    let color: Color
    /// Final pixel rect (before inset) where the block is drawn.
    let rect: CGRect
    var opacity: CGFloat = 1
    var dimmed: Bool = false

    var body: some View {
        let inset = GridLayout.itemBlockInset
        let w  = rect.width  - inset * 2
        let h  = rect.height - inset * 2
        let ox = rect.minX + inset
        let oy = rect.minY + inset
        let base = fontSize(w, h)

        // Solid colour fill with the item name (and optional secondary label)
        // laid on top in white. `opacity` lets a caller dim the fill so a
        // coloured zone stays readable underneath.
        RoundedRectangle(cornerRadius: GridCornerRadius.item)
            .fill(color.opacity((dimmed ? GridOpacity.itemDimmedFill : 1) * opacity))
            .overlay(
                VStack(spacing: 1) {
                    Text(name)
                        .font(.system(size: base, weight: .semibold))
                    if !label.isEmpty {
                        Text(label)
                            .font(.system(size: base * 0.8, weight: .regular))
                            .opacity(0.9)
                    }
                }
                .foregroundStyle(.white.opacity(dimmed ? GridOpacity.itemTextDimmed : 1))
                .multilineTextAlignment(.center)
                .lineLimit(1)
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
