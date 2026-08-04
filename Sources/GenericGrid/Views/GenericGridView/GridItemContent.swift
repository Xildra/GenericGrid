//
//  GridItemContent.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Public surface for rendering a placed item: the context handed to a
//  caller-supplied item view, and the default block used when the caller
//  doesn't supply one.
//

import SwiftUI

// MARK: - Render context

/// Everything the grid knows about a block when it asks the caller to draw it.
/// The module owns the *position* of the block; the view owns its *content*.
public struct GridItemContext {
    /// Pixel size of the block. Depends on the item footprint, the current
    /// zoom and `itemsFillZone` — use it to scale text or artwork.
    public let size: CGSize
    /// `true` while this item is being dragged (draw it dimmed if you like).
    public let isMoving: Bool
    /// Fill opacity requested through `itemOpacity` (1 = opaque).
    public let opacity: CGFloat

    public init(size: CGSize, isMoving: Bool, opacity: CGFloat) {
        self.size = size
        self.isMoving = isMoving
        self.opacity = opacity
    }
}

// MARK: - Default block

/// Default item rendering: a solid rounded rectangle in the type's colour with
/// the type name (and optional secondary label) laid on top in white, sized
/// from the block geometry.
///
/// Used automatically when no `itemContent` is given to `GenericGridView`, and
/// available publicly so a caller can reuse or decorate it.
@available(iOS 17.0, macOS 14.0, *)
public struct GridDefaultItemView<Item: GridPlaceable>: View {
    let item: Item
    let context: GridItemContext

    public init(item: Item, context: GridItemContext) {
        self.item = item
        self.context = context
    }

    public var body: some View {
        if let t = item.itemType {
            let base = fontSize(context.size)
            RoundedRectangle(cornerRadius: GridCornerRadius.item)
                .fill(t.color.opacity((context.isMoving ? GridOpacity.itemDimmedFill : 1) * context.opacity))
                .overlay(
                    VStack(spacing: 1) {
                        Text(t.name)
                            .font(.system(size: base, weight: .semibold))
                        if !t.label.isEmpty {
                            Text(t.label)
                                .font(.system(size: base * 0.8, weight: .regular))
                                .opacity(0.9)
                        }
                    }
                    .foregroundStyle(.white.opacity(context.isMoving ? GridOpacity.itemTextDimmed : 1))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(3)
                )
        }
    }

    private func fontSize(_ size: CGSize) -> CGFloat {
        min(size.width / GridFont.itemNameWidthDiv,
            size.height / GridFont.itemNameHeightDiv,
            GridFont.itemNameMax)
    }
}
