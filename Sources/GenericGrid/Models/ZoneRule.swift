//
//  ZoneRule.swift
//  GenericGrid Module
//
//  Defines the drag & drop behaviour of a grid zone.
//

import Foundation

public enum ZoneRule: String, Codable, Hashable, Sendable {
    /// Any item can be placed freely.
    case free
    /// Items cannot be placed in or removed from this zone.
    case locked
    /// No item can be placed here at all.
    case forbidden
    /// Only specific item types (listed in `allowedTypeNames`) are accepted.
    case restricted
}
