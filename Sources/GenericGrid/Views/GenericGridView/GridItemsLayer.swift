//
//  GridItemsLayer.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Positions all placed items on the grid. The block's *content* is supplied
//  by the caller (`GridDefaultItemView` when it doesn't); this layer only
//  computes where each block goes and how big it is.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GridItemsLayer<Item: GridPlaceable, ItemContent: View>: View {
    let config: GridCanvasConfig
    let items: [Item]
    let cellSize: CGFloat
    let movingItem: Item?
    /// When `true`, an item is drawn filling the zone that contains its anchor
    /// (falls back to its own footprint outside any zone). Purely visual — the
    /// item's stored size is unchanged.
    var fillZone: Bool = false
    /// Fill opacity forwarded to the item view (1 = opaque).
    var opacity: CGFloat = 1
    /// Draws one item inside the rect computed for it.
    @ViewBuilder let content: (Item, GridItemContext) -> ItemContent

    var body: some View {
        ForEach(items) { item in
            let rect = itemRect(for: item)
            let inset = GridLayout.itemBlockInset
            let size = CGSize(width: rect.width - inset * 2, height: rect.height - inset * 2)
            content(item, GridItemContext(size: size,
                                          isMoving: movingItem === item,
                                          opacity: opacity))
                .frame(width: size.width, height: size.height)
                .offset(x: rect.minX + inset, y: rect.minY + inset)
                .allowsHitTesting(false)
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
