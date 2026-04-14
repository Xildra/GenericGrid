//
//  GenericGridView.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Main grid view that composes all layers: background, zones,
//  placed items, preview overlay, and gesture handling.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GenericGridView<Item: GridPlaceable>: View {

    let engine: GridEngine<Item>
    let items: [Item]

    /// Callback to insert a new item (bridges to SwiftData / your storage).
    let onInsert: (Item.ItemType, Int, Int, Bool) -> Void
    /// Optional callback for long-press deletion.
    var onDelete: ((Item) -> Void)?
    /// Optional callback when placing on an already occupied cell.
    var onConflict: ((GridCell, Item) -> Void)?

    @State private var cs: CGFloat = 44

    // MARK: - Layout helpers

    private var hasLabels: Bool { engine.config.rowLabels != nil || engine.config.colLabels != nil }
    private var labelMargin: CGFloat { hasLabels ? 28 : 0 }
    private var W: CGFloat { CGFloat(engine.cols) * cs }
    private var H: CGFloat { CGFloat(engine.rows) * cs }

    public init(engine: GridEngine<Item>,
                items: [Item],
                onInsert: @escaping (Item.ItemType, Int, Int, Bool) -> Void,
                onDelete: ((Item) -> Void)? = nil,
                onConflict: ((GridCell, Item) -> Void)? = nil) {
        self.engine = engine
        self.items = items
        self.onInsert = onInsert
        self.onDelete = onDelete
        self.onConflict = onConflict
    }

    public var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Column labels (top)
                    if hasLabels {
                        colLabelsView
                            .offset(x: labelMargin, y: 0)
                    }
                    // Row labels (left)
                    if hasLabels {
                        rowLabelsView
                            .offset(x: 0, y: labelMargin)
                    }
                    // Grid shifted past labels
                    ZStack(alignment: .topLeading) {
                        GridBackgroundLayer(rows: engine.rows, cols: engine.cols, cellSize: cs)
                        GridZoneOverlayLayer(zones: engine.config.zones, cellSize: cs)
                        GridItemsLayer(items: items, cellSize: cs, movingItem: engine.movingItem)
                        GridPreviewLayer(cells: engine.previewCells, isValid: engine.isPreviewValid, cellSize: cs)
                        GridGestureLayer(engine: engine, cellSize: cs, onInsert: onInsert, onConflict: onConflict)
                    }
                    .frame(width: W, height: H)
                    .offset(x: labelMargin, y: labelMargin)
                }
                .frame(width: W + labelMargin, height: H + labelMargin)
                .padding(16)
            }
            .onAppear { fitCell(geo) }
            .onChange(of: geo.size)      { _, _ in fitCell(geo) }
            .onChange(of: engine.rows)   { _, _ in fitCell(geo) }
            .onChange(of: engine.cols)   { _, _ in fitCell(geo) }
        }
        .background(.background.secondary)
    }

    // MARK: - Column labels

    private var colLabelsView: some View {
        HStack(spacing: 0) {
            ForEach(0..<engine.cols, id: \.self) { c in
                Text(engine.config.colLabel(at: c))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: cs, height: labelMargin)
            }
        }
    }

    // MARK: - Row labels

    private var rowLabelsView: some View {
        VStack(spacing: 0) {
            ForEach(0..<engine.rows, id: \.self) { r in
                Text(engine.config.rowLabel(at: r))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: labelMargin, height: cs)
            }
        }
    }

    // MARK: - Dynamic cell sizing

    private func fitCell(_ geo: GeometryProxy) {
        let margin = labelMargin + 32
        let byCol = (geo.size.width  - margin) / CGFloat(engine.cols)
        let byRow = (geo.size.height - margin) / CGFloat(engine.rows)
        cs = min(60, max(28, min(byCol, byRow)))
    }
}
