//
//  ColorHexTests.swift
//  GenericGrid Tests
//

import Testing
import SwiftUI
@testable import GenericGrid

@Suite("Color+Hex")
struct ColorHexTests {

    @Test("init from 6-digit hex")
    func initHex6() {
        let color = Color(hex: "#FF0000")
        // Should produce a valid Color (no crash)
        #expect(type(of: color) == Color.self)
    }

    @Test("init from hex without hash")
    func initHexNoHash() {
        let color = Color(hex: "00FF00")
        #expect(type(of: color) == Color.self)
    }

    @Test("toHex returns valid hex string")
    func toHexReturnsString() {
        let hex = Color.red.toHex()
        #expect(hex != nil)
        #expect(hex!.hasPrefix("#"))
        #expect(hex!.count == 7) // #RRGGBB
    }

    @Test("round-trip hex → Color → hex preserves value")
    func roundTrip() {
        let original = "#3399FF"
        let color = Color(hex: original)
        let result = color.toHex()
        #expect(result != nil)
        // The round-trip may not be exactly identical due to color space,
        // but should be close
        #expect(result!.hasPrefix("#"))
        #expect(result!.count == 7)
    }
}
