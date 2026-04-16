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

    @State private var zoom: CGFloat = 1.0

    private var effectiveZoom: CGFloat { zoom }

    private var hasLabels: Bool {
        config.rowLabels != nil || config.colLabels != nil
    }
    private let labelMargin: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = hasLabels ? labelMargin : 0
            let baseCS = baseCellSize(in: geo.size, margin: margin)
            let cs = baseCS * effectiveZoom
            let W  = CGFloat(config.cols) * cs
            let H  = CGFloat(config.rows) * cs
            let totalW = W + margin
            let totalH = H + margin

            ZStack(alignment: .bottomTrailing) {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Column labels (top)
                        if hasLabels {
                            HStack(spacing: 0) {
                                ForEach(0..<config.cols, id: \.self) { c in
                                    Text(config.colLabel(at: c))
                                        .font(.system(size: min(cs * 0.3, 12), weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .frame(width: cs, height: margin)
                                }
                            }
                            .offset(x: margin, y: 0)
                        }

                        // Row labels (left)
                        if hasLabels {
                            VStack(spacing: 0) {
                                ForEach(0..<config.rows, id: \.self) { r in
                                    Text(config.rowLabel(at: r))
                                        .font(.system(size: min(cs * 0.3, 12), weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .frame(width: margin, height: cs)
                                }
                            }
                            .offset(x: 0, y: margin)
                        }

                        // Grid + zones
                        ZStack(alignment: .topLeading) {
                            GridBackgroundLayer(rows: config.rows, cols: config.cols, cellSize: cs)

                            ForEach(Array(config.zones.enumerated()), id: \.element.id) { idx, zone in
                                DraggableZoneView(
                                    zone: zone,
                                    cellSize: cs,
                                    maxRows: config.rows,
                                    maxCols: config.cols,
                                    onUpdate: { updated in
                                        config.zones[idx] = updated
                                    },
                                    onTap: {
                                        onEditZone(zone)
                                    }
                                )
                            }
                        }
                        .frame(width: W, height: H)
                        .offset(x: margin, y: margin)
                    }
                    .frame(width: totalW, height: totalH)
                    .frame(
                        minWidth: geo.size.width,
                        minHeight: geo.size.height
                    )
                }

                // Zoom controls
                zoomControls
                    .padding(12)
            }
        }
        .background(.background.secondary)
    }

    // MARK: - Zoom controls

    private var zoomControls: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { zoom = min(zoom * 1.3, 5.0) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
            }

            Text("\(Int(effectiveZoom * 100))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { zoom = max(zoom / 1.3, 0.2) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
            }

            Divider().frame(width: 20)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { zoom = 1.0 }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
        }
        .buttonStyle(.bordered)
        .background(.ultraThinMaterial)
		.clipShape(.buttonBorder)
    }

    // MARK: - Cell size

    /// Minimum cell width required so the widest column label fits.
    private var minCellWidthForLabels: CGFloat {
        guard config.colLabels != nil else { return 8 }
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: 12, weight: .medium)
        #elseif canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        #endif
        let maxWidth = (0..<config.cols).map { c in
            let label = config.colLabel(at: c)
            return (label as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return maxWidth + 8
    }

    /// Base cell size that fits the grid in the available space at zoom 1×.
    /// Ensures cells are wide enough to display column labels.
    private func baseCellSize(in size: CGSize, margin: CGFloat) -> CGFloat {
        let availW = size.width  - margin
        let availH = size.height - margin
        let byCol = availW / CGFloat(config.cols)
        let byRow = availH / CGFloat(config.rows)
        let fitSize = min(byCol, byRow)
        return max(minCellWidthForLabels, max(8, fitSize))
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

    private let handleSize: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(draft.color.opacity(0.15))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(strokeColor, style: strokeStyle)

            VStack(spacing: 2) {
                Text(draft.label)
                    .font(.system(size: min(w / 8, 11), weight: .medium))
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
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
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

        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.opacity(0.6))
            .frame(
                width:  isHorizontal ? min(w * 0.4, 36) : handleSize * 0.45,
                height: isHorizontal ? handleSize * 0.45 : min(h * 0.4, 36)
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
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .updating($anchor) { _, state, _ in
                if state == nil { state = draft }
            }
            .onChanged { v in
                guard let start = anchor else { return }
                let dx = Double(v.translation.width / cellSize)
                let dy = Double(v.translation.height / cellSize)
                switch edge {
                case .top:
                    draft.rowStart = clamp(start.rowStart + dy, lo: 0, hi: start.rowEnd - 0.5)
                case .bottom:
                    draft.rowEnd   = clamp(start.rowEnd + dy, lo: start.rowStart + 0.5, hi: Double(maxRows))
                case .leading:
                    draft.colStart = clamp(start.colStart + dx, lo: 0, hi: start.colEnd - 0.5)
                case .trailing:
                    draft.colEnd   = clamp(start.colEnd + dx, lo: start.colStart + 0.5, hi: Double(maxCols))
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
        case .locked:     return .orange.opacity(0.5)
        case .forbidden:  return .red.opacity(0.4)
        case .restricted: return .blue.opacity(0.4)
        case .free:       return draft.color.opacity(0.3)
        }
    }

    private var strokeStyle: StrokeStyle {
        switch draft.rule {
        case .locked, .forbidden:
            return StrokeStyle(lineWidth: 1.5, dash: [6, 3])
        default:
            return StrokeStyle(lineWidth: 1)
        }
    }

    @ViewBuilder
    private var ruleIcon: some View {
        switch draft.rule {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 9)).foregroundStyle(.secondary.opacity(0.6))
        case .forbidden:
            Image(systemName: "nosign")
                .font(.system(size: 9)).foregroundStyle(.red.opacity(0.5))
        case .restricted:
            Image(systemName: "person.badge.key")
                .font(.system(size: 9)).foregroundStyle(.blue.opacity(0.5))
        case .free:
            EmptyView()
        }
    }
}

// MARK: - Utility

func clamp(_ value: Double, lo: Double, hi: Double) -> Double {
    Swift.min(hi, Swift.max(lo, value))
}
