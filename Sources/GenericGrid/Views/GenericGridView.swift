//
//  GenericGridView.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Main grid view that composes all layers: background, zones,
//  placed items, preview overlay, and gesture handling.
//  Provides pinch-friendly zoom controls and scroll-compatible
//  gesture handling.
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

    // MARK: - Layout helpers

    private var effectiveZoom: CGFloat { zoom }
    private var hasLabels: Bool { engine.config.rowLabels != nil || engine.config.colLabels != nil }

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
        GeometryReader { geo in
            let margin: CGFloat = hasLabels ? GridLayout.labelMargin : 0
            let baseCS = baseCellSize(in: geo.size, margin: margin)
            let cs = baseCS * effectiveZoom
            let W  = CGFloat(engine.cols) * cs
            let H  = CGFloat(engine.rows) * cs
            let totalW = W + margin
            let totalH = H + margin

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Column labels (top)
                    if hasLabels {
                        HStack(spacing: 0) {
                            ForEach(0..<engine.cols, id: \.self) { c in
                                Text(engine.config.colLabel(at: c))
                                    .font(.system(size: min(cs * GridFont.colLabelScale, GridFont.colLabelMax), weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(width: cs, height: margin)
                            }
                        }
                        .offset(x: margin, y: 0)
                    }

                    // Row labels (left)
                    if hasLabels {
                        VStack(spacing: 0) {
                            ForEach(0..<engine.rows, id: \.self) { r in
                                Text(engine.config.rowLabel(at: r))
                                    .font(.system(size: min(cs * GridFont.colLabelScale, GridFont.colLabelMax), weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(width: margin, height: cs)
                            }
                        }
                        .offset(x: 0, y: margin)
                    }

                    // Grid + layers
                    ZStack(alignment: .topLeading) {
                        GridBackgroundLayer(rows: engine.rows, cols: engine.cols, cellSize: cs)
                        GridZoneOverlayLayer(zones: engine.config.zones, cellSize: cs)
                        GridItemsLayer(items: items, cellSize: cs, movingItem: engine.movingItem)
                        GridPreviewLayer(cells: engine.previewCells, isValid: engine.isPreviewValid, cellSize: cs)
                        GridGestureLayer(engine: engine, cellSize: cs, onInsert: onInsert, onConflict: onConflict)
                    }
                    .frame(width: W, height: H)
                    .offset(x: margin, y: margin)
                }
                .frame(width: totalW, height: totalH)
                .frame(
                    minWidth: geo.size.width,
                    minHeight: geo.size.height,
                    alignment: .center
                )
                .padding(GridLayout.gridPadding)
            }
            .overlay(alignment: .bottomTrailing) {
                zoomControls.padding(GridLayout.zoomControlsPadding)
            }
        }
        .background(.background.secondary)
    }

    // MARK: - Zoom controls

    private var zoomControls: some View {
        VStack(spacing: GridLayout.statsSpacing) {
            Button {
                withAnimation(.easeInOut(duration: GridAnimation.zoomDuration)) {
                    zoom = min(zoom * GridZoom.step, GridZoom.max)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: GridFont.zoomIcon, weight: .semibold))
                    .frame(width: GridLayout.zoomButtonSize, height: GridLayout.zoomButtonSize)
            }

            Text("\(Int(effectiveZoom * 100))%")
                .font(.system(size: GridFont.zoomPercent, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.easeInOut(duration: GridAnimation.zoomDuration)) {
                    zoom = max(zoom / GridZoom.step, GridZoom.min)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: GridFont.zoomIcon, weight: .semibold))
                    .frame(width: GridLayout.zoomButtonSize, height: GridLayout.zoomButtonSize)
            }

            Divider().frame(width: GridLayout.zoomDividerWidth)

            Button {
                withAnimation(.easeInOut(duration: GridAnimation.zoomDuration)) {
                    zoom = GridZoom.default
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: GridFont.zoomResetIcon, weight: .semibold))
                    .frame(width: GridLayout.zoomButtonSize, height: GridLayout.zoomButtonSize)
            }
        }
        .buttonStyle(.bordered)
        .background(.ultraThinMaterial)
        .clipShape(.buttonBorder)
    }

    // MARK: - Cell size

    /// Minimum cell width so the widest column label still fits.
    private var minCellWidthForLabels: CGFloat {
        guard engine.config.colLabels != nil else { return GridCellSize.absoluteMin }
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: GridDefaults.labelMeasureFontSize, weight: .medium)
        #elseif canImport(AppKit)
        let font = NSFont.systemFont(ofSize: GridDefaults.labelMeasureFontSize, weight: .medium)
        #endif
        let maxWidth = (0..<engine.cols).map { c in
            let label = engine.config.colLabel(at: c)
            return (label as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return maxWidth + GridCellSize.labelPadding
    }

    /// Base cell size that fits the grid in the available space at zoom 1×.
    private func baseCellSize(in size: CGSize, margin: CGFloat) -> CGFloat {
        let availW = size.width  - margin
        let availH = size.height - margin
        let byCol = availW / CGFloat(engine.cols)
        let byRow = availH / CGFloat(engine.rows)
        let fitSize = min(byCol, byRow)
        return max(minCellWidthForLabels, max(GridCellSize.absoluteMin, fitSize))
    }
}
