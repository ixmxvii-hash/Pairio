// DeviceFavorite.swift
// Model representing a saved device combination (favorite)

import Foundation

/// Represents a saved combination of devices for quick pairing
public struct DeviceFavorite: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var deviceUIDs: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        deviceUIDs: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.deviceUIDs = deviceUIDs
        self.createdAt = createdAt
    }
}
