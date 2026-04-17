//
//  GridConstantsTests.swift
//  GenericGrid Tests
//

import Testing
@testable import GenericGrid

@Suite("GridConstants")
struct GridConstantsTests {

    @Test("zoom limits are coherent")
    func zoomLimits() {
        #expect(GridZoom.min < GridZoom.default)
        #expect(GridZoom.default < GridZoom.max)
        #expect(GridZoom.step > 1.0)
    }

    @Test("cell size limits are coherent")
    func cellSizeLimits() {
        #expect(GridCellSize.absoluteMin < GridCellSize.min)
        #expect(GridCellSize.min < GridCellSize.max)
        #expect(GridCellSize.default >= GridCellSize.min)
        #expect(GridCellSize.default <= GridCellSize.max)
    }

    @Test("default grid dimensions are positive")
    func defaultDimensions() {
        #expect(GridDefaults.rows > 0)
        #expect(GridDefaults.cols > 0)
        #expect(GridDefaults.stepperMax >= GridDefaults.rows)
        #expect(GridDefaults.stepperMax >= GridDefaults.cols)
    }

    @Test("half-cell constant is 0.5")
    func halfCell() {
        #expect(GridGesture.halfCell == 0.5)
    }

    @Test("animation durations are positive")
    func animationDurations() {
        #expect(GridAnimation.zoomDuration > 0)
        #expect(GridAnimation.saveResetDelay > 0)
    }

    @Test("corner radii are positive")
    func cornerRadii() {
        #expect(GridCornerRadius.grid > 0)
        #expect(GridCornerRadius.zone > 0)
        #expect(GridCornerRadius.item > 0)
        #expect(GridCornerRadius.resizeHandle > 0)
    }

    @Test("opacities are in valid range")
    func opacitiesRange() {
        let opacities: [Double] = [
            GridOpacity.gridLine, GridOpacity.zoneFill, GridOpacity.zoneFillPreview,
            GridOpacity.zoneStrokeFree, GridOpacity.zoneStrokeLocked,
            GridOpacity.previewValidFill, GridOpacity.previewInvalidFill,
            GridOpacity.itemFill, GridOpacity.itemDimmedFill
        ]
        for o in opacities {
            #expect(o > 0 && o <= 1, "Opacity \(o) out of range")
        }
    }
}
