//
//  GenericGridViewAPITests.swift
//  GenericGrid Tests
//
//  Compile-level checks on the public `GenericGridView` surface: the default
//  initialiser must still infer its item view, and a caller-supplied item view
//  must type-check through the trailing closure.
//

import Testing
import SwiftUI
@testable import GenericGrid

@Suite("GenericGridView API")
struct GenericGridViewAPITests {

    @Test("default initialiser infers the built-in item view")
    @MainActor
    func defaultItemView() {
        let engine = GridEngine<MockItem>(config: .default)
        let view = GenericGridView(engine: engine, items: []) { _, _, _, _ in }
        #expect(type(of: view) == GenericGridView<MockItem, GridDefaultItemView<MockItem>>.self)
    }

    @Test("caller can supply its own item view")
    @MainActor
    func customItemView() {
        let engine = GridEngine<MockItem>(config: .default)
        let view = GenericGridView(engine: engine,
                                   items: [],
                                   showZoomControls: false,
                                   onInsert: { _, _, _, _ in }) { item, ctx in
            Text(item.itemType?.name ?? "")
                .font(.system(size: ctx.size.height / 3))
                .opacity(ctx.isMoving ? 0.4 : 1)
        }
        #expect(type(of: view) != GenericGridView<MockItem, GridDefaultItemView<MockItem>>.self)
    }
}
