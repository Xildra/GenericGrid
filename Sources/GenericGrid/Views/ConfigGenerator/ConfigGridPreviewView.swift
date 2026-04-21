//
//  ConfigGridPreviewView.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Live grid preview with draggable & resizable zone overlays.
//

import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct ConfigGridPreviewView: View {

    @Binding var config: GridCanvasConfig
    var onEditZone: (GridZoneDefinition) -> Void

    @State private var zoom: CGFloat = GridZoom.default

    var body: some View {
        ZoomableGridScaffold(config: config, zoom: $zoom) { cs in
            ZStack(alignment: .topLeading) {
                GridBackgroundLayer(rows: config.rows, cols: config.cols, cellSize: cs,
                                    showLines: config.showMainGrid)
                GridZoneSubdivisionLayer(zones: config.zones, cellSize: cs)

                ForEach(Array(config.zones.enumerated()), id: \.element.id) { idx, zone in
                    DraggableZoneView(
                        zone: zone,
                        cellSize: cs,
                        maxRows: config.rows,
                        maxCols: config.cols,
                        onUpdate: { updated in config.zones[idx] = updated },
                        onTap:    { onEditZone(zone) }
                    )
                }
            }
        }
        .safeAreaPadding(.bottom, GridLayout.previewBottomInset)
    }
}

// MARK: - Draggable zone overlay

@available(iOS 17.0, macOS 14.0, *)
struct DraggableZoneView: View {

    let zone: GridZoneDefinition
    let cellSize: CGFloat
    let maxRows: Int
    let maxCols: Int
    let onUpdate: (GridZoneDefinition) -> Void
    let onTap: () -> Void

    @State private var draft: GridZoneDefinition
    /// Anchor captured at the start of each drag (reset to nil between drags).
    @GestureState private var anchor: GridZoneDefinition? = nil

    init(zone: GridZoneDefinition, cellSize: CGFloat, maxRows: Int, maxCols: Int,
         onUpdate: @escaping (GridZoneDefinition) -> Void, onTap: @escaping () -> Void) {
        self.zone = zone
        self.cellSize = cellSize
        self.maxRows = maxRows
        self.maxCols = maxCols
        self.onUpdate = onUpdate
        self.onTap = onTap
        self.draft = zone
    }

    /// Snaps a value to the nearest half-cell (0, 0.5, 1, 1.5…).
    private func snapHalf(_ v: Double) -> Double {
        (v * 2).rounded() / 2
    }

    private var x: CGFloat { draft.colStart * cellSize }
    private var y: CGFloat { draft.rowStart * cellSize }
    private var w: CGFloat { (draft.colEnd - draft.colStart) * cellSize }
    private var h: CGFloat { (draft.rowEnd - draft.rowStart) * cellSize }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GridCornerRadius.zone)
                .fill(draft.color.opacity(GridOpacity.zoneFillPreview))
            RoundedRectangle(cornerRadius: GridCornerRadius.zone)
                .strokeBorder(strokeColor, lineWidth: GridLineWidth.zoneDefault)

            VStack(spacing: GridLayout.zoneLabelSpacing) {
                Text(draft.label)
                    .font(.system(size: min(w / GridFont.zoneLabelDivisor, GridFont.zoneLabelMax), weight: .medium))
                    .foregroundStyle(.secondary)
                ruleIcon
            }

            resizeHandle(edge: .top)
            resizeHandle(edge: .bottom)
            resizeHandle(edge: .leading)
            resizeHandle(edge: .trailing)
        }
        .frame(width: w, height: h)
        .offset(x: x, y: y)
        .gesture(moveGesture)
        .onTapGesture { onTap() }
        .onChange(of: zone) { _, newValue in draft = newValue }
    }

    // MARK: - Move gesture

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: GridGesture.moveDragMinimum, coordinateSpace: .global)
            .updating($anchor) { _, state, _ in
                if state == nil { state = draft }
            }
            .onChanged { v in
                guard let start = anchor else { return }
                let dc = Double(v.translation.width / cellSize)
                let dr = Double(v.translation.height / cellSize)
                let colSpan = start.colEnd - start.colStart
                let rowSpan = start.rowEnd - start.rowStart
                let newColStart = clamp(start.colStart + dc, lo: 0, hi: Double(maxCols) - colSpan)
                let newRowStart = clamp(start.rowStart + dr, lo: 0, hi: Double(maxRows) - rowSpan)
                draft.colStart = newColStart
                draft.colEnd   = newColStart + colSpan
                draft.rowStart = newRowStart
                draft.rowEnd   = newRowStart + rowSpan
            }
            .onEnded { _ in
                draft.colStart = snapHalf(draft.colStart)
                draft.colEnd   = snapHalf(draft.colEnd)
                draft.rowStart = snapHalf(draft.rowStart)
                draft.rowEnd   = snapHalf(draft.rowEnd)
                onUpdate(draft)
            }
    }

    // MARK: - Resize handles

    private enum Edge { case top, bottom, leading, trailing }

    @ViewBuilder
    private func resizeHandle(edge: Edge) -> some View {
        let isHorizontal = (edge == .top || edge == .bottom)

        RoundedRectangle(cornerRadius: GridCornerRadius.resizeHandle)
            .fill(Color.accentColor.opacity(GridOpacity.resizeHandle))
            .frame(
                width:  isHorizontal ? min(w * GridHandleFactor.lengthFraction, GridLayout.zoneHandleMaxLength) : GridLayout.zoneHandleSize * GridHandleFactor.thickness,
                height: isHorizontal ? GridLayout.zoneHandleSize * GridHandleFactor.thickness : min(h * GridHandleFactor.lengthFraction, GridLayout.zoneHandleMaxLength)
            )
            .position(handlePosition(edge: edge))
            .gesture(resizeGesture(edge: edge))
    }

    private func handlePosition(edge: Edge) -> CGPoint {
        switch edge {
        case .top:      return CGPoint(x: w / 2, y: 0)
        case .bottom:   return CGPoint(x: w / 2, y: h)
        case .leading:  return CGPoint(x: 0, y: h / 2)
        case .trailing: return CGPoint(x: w, y: h / 2)
        }
    }

    private func resizeGesture(edge: Edge) -> some Gesture {
        DragGesture(minimumDistance: GridGesture.resizeDragMinimum, coordinateSpace: .global)
            .updating($anchor) { _, state, _ in
                if state == nil { state = draft }
            }
            .onChanged { v in
                guard let start = anchor else { return }
                let dx = Double(v.translation.width / cellSize)
                let dy = Double(v.translation.height / cellSize)
                switch edge {
                case .top:
                    draft.rowStart = clamp(start.rowStart + dy, lo: 0, hi: start.rowEnd - GridGesture.minZoneSpan)
                case .bottom:
                    draft.rowEnd   = clamp(start.rowEnd + dy, lo: start.rowStart + GridGesture.minZoneSpan, hi: Double(maxRows))
                case .leading:
                    draft.colStart = clamp(start.colStart + dx, lo: 0, hi: start.colEnd - GridGesture.minZoneSpan)
                case .trailing:
                    draft.colEnd   = clamp(start.colEnd + dx, lo: start.colStart + GridGesture.minZoneSpan, hi: Double(maxCols))
                }
            }
            .onEnded { _ in
                draft.rowStart = snapHalf(draft.rowStart)
                draft.rowEnd   = snapHalf(draft.rowEnd)
                draft.colStart = snapHalf(draft.colStart)
                draft.colEnd   = snapHalf(draft.colEnd)
                onUpdate(draft)
            }
    }

    // MARK: - Styling

    private var strokeColor: Color {
        switch draft.rule {
        case .locked:     return .orange.opacity(GridOpacity.zoneStrokeLocked)
        case .forbidden:  return .red.opacity(GridOpacity.zoneStrokeForbidden)
        case .restricted: return .blue.opacity(GridOpacity.zoneStrokeRestricted)
        case .free:       return draft.color.opacity(GridOpacity.zoneStrokeFree)
        }
    }

    @ViewBuilder
    private var ruleIcon: some View {
        switch draft.rule {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: GridFont.ruleIcon)).foregroundStyle(.secondary.opacity(GridOpacity.ruleIconLock))
        case .forbidden:
            Image(systemName: "nosign")
                .font(.system(size: GridFont.ruleIcon)).foregroundStyle(.red.opacity(GridOpacity.ruleIconForbidden))
        case .restricted:
            Image(systemName: "person.badge.key")
                .font(.system(size: GridFont.ruleIcon)).foregroundStyle(.blue.opacity(GridOpacity.ruleIconRestricted))
        case .free:
            EmptyView()
        }
    }
}

// MARK: - Utility

func clamp(_ value: Double, lo: Double, hi: Double) -> Double {
    Swift.min(hi, Swift.max(lo, value))
}
