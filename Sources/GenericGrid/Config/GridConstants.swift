//
//  GridConstants.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Centralised design tokens and layout constants used
//  throughout the grid views. Keeps magic numbers in one place.
//

import SwiftUI

// MARK: - Layout

public enum GridLayout {
    /// Margin reserved for row / column labels.
    static let labelMargin: CGFloat = 28
    /// Outer padding around the grid inside its scroll view.
    static let gridPadding: CGFloat = 16
    /// Safe-area bottom spacing below the preview.
    static let previewBottomInset: CGFloat = 30
    /// Padding around zoom controls overlay.
    static let zoomControlsPadding: CGFloat = 12
    /// Inset applied to each item block (offset & frame shrink).
    static let itemBlockInset: CGFloat = 2
    /// Inset applied to the preview highlight rectangle.
    static let previewInset: CGFloat = 1
    /// Size (width & height) of zoom control buttons.
    static let zoomButtonSize: CGFloat = 32
    /// Width of the divider inside zoom controls.
    static let zoomDividerWidth: CGFloat = 20
    /// Size of the colour indicator circle in zone rows.
    static let colorCircleSize: CGFloat = 12
    /// Size of the drag handle on draggable zone edges.
    static let zoneHandleSize: CGFloat = 14
    /// Maximum handle visual length (clamped).
    static let zoneHandleMaxLength: CGFloat = 36
    /// Spacing inside zone label stacks.
    static let zoneLabelSpacing: CGFloat = 2
    /// Spacing between VStack items in stats block.
    static let statsSpacing: CGFloat = 8
    /// Vertical padding of the stats block.
    static let statsVerticalPadding: CGFloat = 4
    /// Spacing between stat items.
    static let statItemSpacing: CGFloat = 2
}

// MARK: - Corner radii

public enum GridCornerRadius {
    /// Grid background outer border.
    static let grid: CGFloat = 10
    /// Zone overlays and preview highlight.
    static let zone: CGFloat = 4
    /// Placed item blocks.
    static let item: CGFloat = 7
    /// Resize handle pills.
    static let resizeHandle: CGFloat = 2
}

// MARK: - Line widths

public enum GridLineWidth {
    /// Grid background lines and outer border.
    static let gridLine: CGFloat = 0.5
    /// Default zone stroke (free / restricted).
    static let zoneDefault: CGFloat = 1
    /// Dashed zone stroke (locked / forbidden).
    static let zoneDashed: CGFloat = 1.5
    /// Preview overlay border.
    static let preview: CGFloat = 1.2
    /// Placed item border (normal).
    static let item: CGFloat = 1.5
    /// Placed item border (dimmed / moving).
    static let itemDimmed: CGFloat = 1
}

// MARK: - Dash patterns

public enum GridDash {
    /// Dash pattern for locked / forbidden zones.
    static let zoneLocked: [CGFloat] = [6, 3]
}

// MARK: - Opacities

public enum GridOpacity {
    // Grid
    static let gridLine: Double = 0.3

    // Zone fill
    static let zoneFill: Double = 0.12
    static let zoneFillPreview: Double = 0.15

    // Zone stroke by rule
    static let zoneStrokeFree: Double = 0.3
    static let zoneStrokeLocked: Double = 0.5
    static let zoneStrokeForbidden: Double = 0.4
    static let zoneStrokeRestricted: Double = 0.4

    // Preview overlay
    static let previewValidFill: Double = 0.22
    static let previewInvalidFill: Double = 0.2
    static let previewValidStroke: Double = 0.7
    static let previewInvalidStroke: Double = 0.6

    // Placed items
    static let itemFill: Double = 0.16
    static let itemDimmedFill: Double = 0.08
    static let itemStrokeDimmed: Double = 0.3
    static let itemTextDimmed: Double = 0.4
    static let itemSubtextDimmed: Double = 0.3
    static let itemSubtext: Double = 0.6

    // Rule icons
    static let ruleIconLock: Double = 0.6
    static let ruleIconForbidden: Double = 0.5
    static let ruleIconRestricted: Double = 0.5

    // Resize handle
    static let resizeHandle: Double = 0.6

    // Stats thresholds
    static let statsFillMedium: Double = 0.5
    static let statsFillHigh: Double = 0.8
}

// MARK: - Font sizes

public enum GridFont {
    /// Rule icon size inside zones.
    static let ruleIcon: CGFloat = 9
    /// Label font size in the main grid view.
    static let gridLabel: CGFloat = 10
    /// Maximum zone label font size.
    static let zoneLabelMax: CGFloat = 11
    /// Divisor for zone label font: `min(width / zoneLabelDivisor, zoneLabelMax)`.
    static let zoneLabelDivisor: CGFloat = 8
    /// Maximum column label size in the config preview.
    static let colLabelMax: CGFloat = 12
    /// Column label scale factor relative to cell size.
    static let colLabelScale: CGFloat = 0.3
    /// Maximum item name font size.
    static let itemNameMax: CGFloat = 12
    /// Item name width divisor: `min(w / itemNameWidthDiv, …)`.
    static let itemNameWidthDiv: CGFloat = 4
    /// Item name height divisor.
    static let itemNameHeightDiv: CGFloat = 2.5
    /// Minimum item subtitle font size.
    static let itemSubtitleMin: CGFloat = 7
    /// Item subtitle offset from name size.
    static let itemSubtitleOffset: CGFloat = 2
    /// Zoom percentage display.
    static let zoomPercent: CGFloat = 10
    /// Zoom button icon size.
    static let zoomIcon: CGFloat = 14
    /// Zoom reset icon size.
    static let zoomResetIcon: CGFloat = 12
}

// MARK: - Cell size limits

public enum GridCellSize {
    /// Default cell size before fitting.
    static let `default`: CGFloat = 44
    /// Minimum cell size in the main grid view.
    static let min: CGFloat = 28
    /// Maximum cell size in the main grid view.
    static let max: CGFloat = 60
    /// Absolute minimum cell size in the config preview.
    static let absoluteMin: CGFloat = 8
    /// Extra padding around labels for minimum width.
    static let labelPadding: CGFloat = 8
    /// Margin used in GenericGridView fitCell (labels + padding × 2).
    static let fitMargin: CGFloat = 32
}

// MARK: - Zoom

public enum GridZoom {
    /// Minimum zoom factor.
    static let min: CGFloat = 0.2
    /// Maximum zoom factor.
    static let max: CGFloat = 5.0
    /// Multiplicative zoom step per tap.
    static let step: CGFloat = 1.3
    /// Default zoom level.
    static let `default`: CGFloat = 1.0
}

// MARK: - Animation

public enum GridAnimation {
    /// Duration for zoom in/out transitions.
    static let zoomDuration: Double = 0.2
    /// Delay before "Saved" badge resets.
    static let saveResetDelay: Double = 1.5
}

// MARK: - Gestures

public enum GridGesture {
    /// Minimum drag distance for move gesture.
    static let moveDragMinimum: CGFloat = 4
    /// Minimum drag distance for resize gesture.
    static let resizeDragMinimum: CGFloat = 2
    /// Minimum zone span after resize (half-cell).
    static let minZoneSpan: Double = 0.5
    /// Half-cell size for sub-cell calculations.
    static let halfCell: Double = 0.5
    /// Minimum duration (seconds) of the long-press before a grid drag activates.
    /// Short enough to stay responsive, long enough to let ScrollView capture quick swipes.
    static let longPressDuration: Double = 0.18
}

// MARK: - Config defaults

public enum GridDefaults {
    /// Default grid rows.
    public static let rows: Int = 10
    /// Default grid columns.
    public static let cols: Int = 14
    /// Stepper maximum for rows / columns.
    static let stepperMax: Int = 999
    /// Default new zone end (clamped to grid).
    static let newZoneEnd: Double = 3
    /// Font size for the label measuring (minCellWidthForLabels).
    static let labelMeasureFontSize: CGFloat = 12
}

// MARK: - Resize handle thickness factor

public enum GridHandleFactor {
    /// Fraction of zone dimension used for handle length.
    static let lengthFraction: CGFloat = 0.4
    /// Thickness factor for the handle pill.
    static let thickness: CGFloat = 0.45
}
