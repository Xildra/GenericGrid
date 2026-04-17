//
//  ZoneRuleTests.swift
//  GenericGrid Tests
//

import Testing
import Foundation
@testable import GenericGrid

@Suite("ZoneRule")
struct ZoneRuleTests {

    @Test("raw values are correct")
    func rawValues() {
        #expect(ZoneRule.free.rawValue       == "free")
        #expect(ZoneRule.locked.rawValue     == "locked")
        #expect(ZoneRule.forbidden.rawValue  == "forbidden")
        #expect(ZoneRule.restricted.rawValue == "restricted")
    }

    @Test("encodes and decodes as JSON string")
    func codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for rule in [ZoneRule.free, .locked, .forbidden, .restricted] {
            let data = try encoder.encode(rule)
            let decoded = try decoder.decode(ZoneRule.self, from: data)
            #expect(decoded == rule)
        }
    }

    @Test("decodes from raw string")
    func decodeFromString() throws {
        let json = Data(#""restricted""#.utf8)
        let decoded = try JSONDecoder().decode(ZoneRule.self, from: json)
        #expect(decoded == .restricted)
    }
}
