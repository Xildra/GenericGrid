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

    private var hasLabels: Bool {
        config.rowLabels != nil || config.colLabels != nil
    }
    private let labelMargin: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let margin: CGFloat = hasLabels ? labelMargin : 0
            let cs = cellSize(in: geo.size, margin: margin)
            let W  = CGFloat(config.cols) * cs
            let H  = CGFloat(config.rows) * cs

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Column labels (top)
                    if hasLabels {
                        HStack(spacing: 0) {
                            ForEach(0..<config.cols, id: \.self) { c in
                                Text(config.colLabel(at: c))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
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
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
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
                .frame(width: W + margin, height: H + margin)
                .frame(
                    minWidth: geo.size.width,
                    minHeight: geo.size.height
                )
            }
        }
        .background(.background.secondary)
    }

    private func cellSize(in size: CGSize, margin: CGFloat) -> CGFloat {
        let byCol = (size.width  - 32 - margin) / CGFloat(config.cols)
        let byRow = (size.height - 32 - margin) / CGFloat(config.rows)
        return min(60, max(20, min(byCol, byRow)))
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
        var top: Int = 0
        var bottom: Int = 0
        var leading: Int = 0
        var trailing: Int = 0
        static let zero = ResizeDelta()
    }

    // Effective bounds during gesture
    private var eRowStart: Int { clamp(zone.rowStart + resizeDelta.top, min: 0, max: eRowEnd - 1) }
    private var eRowEnd:   Int { clamp(zone.rowEnd   + resizeDelta.bottom, min: zone.rowStart + resizeDelta.top + 1, max: maxRows) }
    private var eColStart: Int { clamp(zone.colStart + resizeDelta.leading, min: 0, max: eColEnd - 1) }
    private var eColEnd:   Int { clamp(zone.colEnd   + resizeDelta.trailing, min: zone.colStart + resizeDelta.leading + 1, max: maxCols) }

    private var x: CGFloat { CGFloat(eColStart) * cellSize }
    private var y: CGFloat { CGFloat(eRowStart) * cellSize }
    private var w: CGFloat { CGFloat(eColEnd - eColStart) * cellSize }
    private var h: CGFloat { CGFloat(eRowEnd - eRowStart) * cellSize }

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
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                moveOffset = v.translation
            }
            .onEnded { v in
                let dc = Int((v.translation.width / cellSize).rounded())
                let dr = Int((v.translation.height / cellSize).rounded())
                var z = zone
                let newColStart = clamp(z.colStart + dc, min: 0, max: maxCols - (z.colEnd - z.colStart))
                let newRowStart = clamp(z.rowStart + dr, min: 0, max: maxRows - (z.rowEnd - z.rowStart))
                let colSpan = z.colEnd - z.colStart
                let rowSpan = z.rowEnd - z.rowStart
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
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                var d = resizeDelta
                switch edge {
                case .top:
                    d.top = Int((v.translation.height / cellSize).rounded())
                case .bottom:
                    d.bottom = Int((v.translation.height / cellSize).rounded())
                case .leading:
                    d.leading = Int((v.translation.width / cellSize).rounded())
                case .trailing:
                    d.trailing = Int((v.translation.width / cellSize).rounded())
                }
                resizeDelta = d
            }
            .onEnded { _ in
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

func clamp(_ value: Int, min lo: Int, max hi: Int) -> Int {
    Swift.min(hi, Swift.max(lo, value))
}
