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
    /// Optional callback when a free cell becomes runtime-locked via tap.
    /// The cell carries whole-cell anchor coordinates.
    var onLock: ((GridCell) -> Void)?
    /// Optional callback when a previously tap-locked cell is unlocked.
    /// The cell carries whole-cell anchor coordinates.
    var onUnlock: ((GridCell) -> Void)?

    /// When `true`, each placed item is drawn filling the zone that contains
    /// its anchor (falls back to its own footprint when outside any zone).
    /// Purely visual — the item's stored size is unchanged.
    var itemsFillZone: Bool = false
    /// Fill opacity for placed items (1 = opaque). Lets a caller dim items so
    /// the zone colour stays readable underneath.
    var itemOpacity: CGFloat = 1
    /// Optional business hook: zones for which this returns `true` are greyed
    /// out (unavailable). The module stays domain-agnostic. `nil` = none.
    var zoneDisabled: ((GridZoneDefinition) -> Bool)?

    @State private var zoom: CGFloat = GridZoom.default

    public init(engine: GridEngine<Item>,
                items: [Item],
                itemsFillZone: Bool = false,
                itemOpacity: CGFloat = 1,
                zoneDisabled: ((GridZoneDefinition) -> Bool)? = nil,
                onInsert: @escaping (Item.ItemType, Double, Double, Bool) -> Void,
                onDelete: ((Item) -> Void)? = nil,
                onConflict: ((GridCell, Item) -> Void)? = nil,
                onLock: ((GridCell) -> Void)? = nil,
                onUnlock: ((GridCell) -> Void)? = nil) {
        self.engine = engine
        self.items = items
        self.itemsFillZone = itemsFillZone
        self.itemOpacity = itemOpacity
        self.zoneDisabled = zoneDisabled
        self.onInsert = onInsert
        self.onDelete = onDelete
        self.onConflict = onConflict
        self.onLock = onLock
        self.onUnlock = onUnlock
    }

    public var body: some View {
        ZoomableGridScaffold(
            config: engine.config,
            zoom: $zoom,
            scrollDisabled: engine.isInteracting
        ) { cs in
            ZStack(alignment: .topLeading) {
                GridBackgroundLayer(config: engine.config, cellSize: cs,
                                    showLines: engine.config.showMainGrid)
                GridZoneSubdivisionLayer(config: engine.config, zones: engine.config.zones, cellSize: cs)
                GridZoneOverlayLayer(config: engine.config, zones: engine.config.zones, cellSize: cs,
                                     isDisabled: zoneDisabled)
                GridCompartmentBordersLayer(config: engine.config, cellSize: cs)
                GridItemsLayer(config: engine.config, items: items, cellSize: cs,
                               movingItem: engine.movingItem,
                               fillZone: itemsFillZone, opacity: itemOpacity)
                GridPreviewLayer(config: engine.config, cells: engine.previewCells,
                                 isValid: engine.isPreviewValid, cellSize: cs,
                                 fillZone: itemsFillZone)
                GridGestureLayer(engine: engine, cellSize: cs,
                                 onInsert: onInsert, onConflict: onConflict,
                                 onLock: onLock, onUnlock: onUnlock)
            }
        }
    }
}
