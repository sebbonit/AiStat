import Foundation
import LimitLensCore
import SwiftUI

enum UsageSeverity: Int, Comparable {
    case unavailable
    case healthy
    case warning
    case critical

    static func < (lhs: UsageSeverity, rhs: UsageSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(percentUsed: Double?) -> UsageSeverity {
        guard let percentUsed else { return .unavailable }
        if percentUsed >= 90 {
            return .critical
        }
        if percentUsed >= 70 {
            return .warning
        }
        return .healthy
    }
}
