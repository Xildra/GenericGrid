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

    @State private var moveOffset: CGSize = .zero
    @State private var resizeDelta: ResizeDelta = .zero

    struct ResizeDelta {
        var top: Double = 0
        var bottom: Double = 0
        var leading: Double = 0
        var trailing: Double = 0
        static let zero = ResizeDelta()
    }

    /// Snaps a value to the nearest half-cell (0, 0.5, 1, 1.5…).
    private func snapHalf(_ v: Double) -> Double {
        (v * 2).rounded() / 2
    }

    // Effective bounds during gesture
    private var eRowStart: Double { clamp(zone.rowStart + resizeDelta.top, lo: 0, hi: eRowEnd - 0.5) }
    private var eRowEnd:   Double { clamp(zone.rowEnd   + resizeDelta.bottom, lo: zone.rowStart + resizeDelta.top + 0.5, hi: Double(maxRows)) }
    private var eColStart: Double { clamp(zone.colStart + resizeDelta.leading, lo: 0, hi: eColEnd - 0.5) }
    private var eColEnd:   Double { clamp(zone.colEnd   + resizeDelta.trailing, lo: zone.colStart + resizeDelta.leading + 0.5, hi: Double(maxCols)) }

    private var x: CGFloat { eColStart * cellSize }
    private var y: CGFloat { eRowStart * cellSize }
    private var w: CGFloat { (eColEnd - eColStart) * cellSize }
    private var h: CGFloat { (eRowEnd - eRowStart) * cellSize }

    private let handleSize: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill((zone.color ?? .gray).opacity(0.15))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(strokeColor, style: strokeStyle)

            VStack(spacing: 2) {
                Text(zone.label)
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
        .offset(x: x + moveOffset.width, y: y + moveOffset.height)
        .gesture(moveGesture)
        .onTapGesture { onTap() }
    }

    // MARK: - Move gesture

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { v in
                moveOffset = v.translation
            }
            .onEnded { v in
                let dc = snapHalf(Double(v.translation.width / cellSize))
                let dr = snapHalf(Double(v.translation.height / cellSize))
                var z = zone
                let colSpan = z.colEnd - z.colStart
                let rowSpan = z.rowEnd - z.rowStart
                let newColStart = clamp(z.colStart + dc, lo: 0, hi: Double(maxCols) - colSpan)
                let newRowStart = clamp(z.rowStart + dr, lo: 0, hi: Double(maxRows) - rowSpan)
                z.colStart = newColStart; z.colEnd = newColStart + colSpan
                z.rowStart = newRowStart; z.rowEnd = newRowStart + rowSpan
                moveOffset = .zero
                onUpdate(z)
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
            .onChanged { v in
                var d = resizeDelta
                switch edge {
                case .top:
                    d.top = Double(v.translation.height / cellSize)
                case .bottom:
                    d.bottom = Double(v.translation.height / cellSize)
                case .leading:
                    d.leading = Double(v.translation.width / cellSize)
                case .trailing:
                    d.trailing = Double(v.translation.width / cellSize)
                }
                resizeDelta = d
            }
            .onEnded { v in
                // Snap only at the end for fluid tracking during the drag.
                var d = ResizeDelta.zero
                switch edge {
                case .top:
                    d.top = snapHalf(Double(v.translation.height / cellSize))
                case .bottom:
                    d.bottom = snapHalf(Double(v.translation.height / cellSize))
                case .leading:
                    d.leading = snapHalf(Double(v.translation.width / cellSize))
                case .trailing:
                    d.trailing = snapHalf(Double(v.translation.width / cellSize))
                }
                resizeDelta = d

                var z = zone
                z.rowStart = eRowStart
                z.rowEnd   = eRowEnd
                z.colStart = eColStart
                z.colEnd   = eColEnd
                resizeDelta = .zero
                onUpdate(z)
            }
    }

    // MARK: - Styling

    private var strokeColor: Color {
        switch zone.rule {
        case .locked:     return .orange.opacity(0.5)
        case .forbidden:  return .red.opacity(0.4)
        case .restricted: return .blue.opacity(0.4)
        case .free:       return (zone.color ?? .gray).opacity(0.3)
        }
    }

    private var strokeStyle: StrokeStyle {
        switch zone.rule {
        case .locked, .forbidden:
            return StrokeStyle(lineWidth: 1.5, dash: [6, 3])
        default:
            return StrokeStyle(lineWidth: 1)
        }
    }

    @ViewBuilder
    private var ruleIcon: some View {
        switch zone.rule {
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
