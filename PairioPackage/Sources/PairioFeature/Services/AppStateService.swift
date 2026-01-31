// AppStateService.swift
// Shared application state service for cross-view communication

import SwiftUI

/// Service for managing shared application state
/// Used for communicating sharing status to the app level for dynamic menu bar icon
@Observable
@MainActor
public final class AppStateService {

    /// Shared singleton instance
    public static let shared = AppStateService()

    /// Whether audio sharing is currently active
    public var isSharingActive: Bool = false

    private init() {}
}
