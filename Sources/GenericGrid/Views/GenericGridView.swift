//
//  GenericGridView.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Main grid view that composes all layers (background, zones,
//  placed items, preview overlay, gesture handling) on top of the
//  shared `ZoomableGridScaffold`.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GenericGridView<Item: GridPlaceable>: View {

    let engine: GridEngine<Item>
    let items: [Item]

    /// Callback to insert a new item (bridges to SwiftData / your storage).
    /// Anchor coordinates are passed at half-cell precision (0, 0.5, 1, 1.5…).
    let onInsert: (Item.ItemType, Double, Double, Bool) -> Void
    /// Optional callback for long-press deletion.
    var onDelete: ((Item) -> Void)?
    /// Optional callback when placing on an already occupied cell.
    var onConflict: ((GridCell, Item) -> Void)?

    @State private var zoom: CGFloat = GridZoom.default

    public init(engine: GridEngine<Item>,
                items: [Item],
                onInsert: @escaping (Item.ItemType, Double, Double, Bool) -> Void,
                onDelete: ((Item) -> Void)? = nil,
                onConflict: ((GridCell, Item) -> Void)? = nil) {
        self.engine = engine
        self.items = items
        self.onInsert = onInsert
        self.onDelete = onDelete
        self.onConflict = onConflict
    }

    public var body: some View {
        ZoomableGridScaffold(
            config: engine.config,
            zoom: $zoom,
            scrollDisabled: engine.isInteracting
        ) { cs in
            ZStack(alignment: .topLeading) {
                GridBackgroundLayer(rows: engine.rows, cols: engine.cols, cellSize: cs,
                                    showLines: engine.config.showMainGrid)
                GridZoneSubdivisionLayer(zones: engine.config.zones, cellSize: cs)
                GridZoneOverlayLayer(zones: engine.config.zones, cellSize: cs)
                GridItemsLayer(items: items, cellSize: cs, movingItem: engine.movingItem)
                GridPreviewLayer(cells: engine.previewCells, isValid: engine.isPreviewValid, cellSize: cs)
                GridGestureLayer(engine: engine, cellSize: cs, onInsert: onInsert, onConflict: onConflict)
            }
        }
    }
}
