// PaywallService.swift
// Manages trial and unlock state

import Foundation
import SwiftUI

@Observable
@MainActor
public final class PaywallService {
    public static let shared = PaywallService()

    private enum Keys {
        static let trialStartDate = "paywall.trialStartDate"
        static let isUnlocked = "paywall.isUnlocked"
    }

    private let defaults: UserDefaults
    private let trialLengthDays: Int = 3

    public var isUnlocked: Bool {
        get { defaults.bool(forKey: Keys.isUnlocked) }
        set { defaults.set(newValue, forKey: Keys.isUnlocked) }
    }

    public var trialStartDate: Date {
        get {
            if let storedDate = defaults.object(forKey: Keys.trialStartDate) as? Date {
                return storedDate
            }
            let now = Date()
            defaults.set(now, forKey: Keys.trialStartDate)
            return now
        }
        set { defaults.set(newValue, forKey: Keys.trialStartDate) }
    }

    public var trialEndDate: Date {
        Calendar.current.date(byAdding: .day, value: trialLengthDays, to: trialStartDate) ?? trialStartDate
    }

    public var isTrialExpired: Bool {
        Date() >= trialEndDate
    }

    public var isAccessAllowed: Bool {
        isUnlocked || !isTrialExpired
    }

    public var daysRemaining: Int {
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: trialEndDate).day ?? 0
        return max(0, remaining)
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        _ = trialStartDate
    }
}
