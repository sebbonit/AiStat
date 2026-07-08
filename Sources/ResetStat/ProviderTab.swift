import AppKit
import ResetStatCore
import SwiftUI

enum ProviderTab: String, CaseIterable, Identifiable {
    case overview
    case codex
    case cursor
    case devin
    case openCodeGo
    case settings

    static let providerCases: [ProviderTab] = [.codex, .cursor, .devin, .openCodeGo]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .devin: return "Devin"
        case .openCodeGo: return "OpenCode Go"
        case .settings: return "Settings"
        }
    }

    var privateName: String {
        switch self {
        case .overview: return "Overview"
        case .codex: return "Provider 1"
        case .cursor: return "Provider 2"
        case .devin: return "Provider 3"
        case .openCodeGo: return "Provider 4"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "speedometer"
        case .codex: return "terminal"
        case .cursor: return "cursorarrow"
        case .devin: return "sparkles"
        case .openCodeGo: return "chevron.left.forwardslash.chevron.right"
        case .settings: return "gearshape"
        }
    }
}
