//
//  ConfigGridPreviewView.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Live grid preview for the config generator. Layers the background,
//  zone subdivisions, and one `DraggableZoneView` per zone on top of
//  the shared `ZoomableGridScaffold`.
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
                GridBackgroundLayer(config: config, cellSize: cs,
                                    showLines: config.showMainGrid)
                GridZoneSubdivisionLayer(config: config, zones: config.zones, cellSize: cs)

                ForEach(config.zones) { zone in
                    DraggableZoneView(
                        zone: zone,
                        config: config,
                        cellSize: cs,
                        onUpdate: { updated in config.updateZone(updated) },
                        onTap:    { onEditZone(zone) }
                    )
                }
            }
        }
        .safeAreaPadding(.bottom, GridLayout.previewBottomInset)
    }
}
