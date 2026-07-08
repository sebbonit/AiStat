import Foundation
import ResetStatCore
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        case disabled
    }

    @Published private(set) var snapshot: ResetStatSnapshot?
    @Published private(set) var cursorSnapshot: CursorUsageSnapshot?
    @Published private(set) var desktopQuotaSnapshots: [DesktopQuotaSnapshot] = []
    @Published private(set) var openCodeGoSnapshot: OpenCodeGoUsageSnapshot?
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var cursorState: LoadState = .idle
    @Published private(set) var desktopQuotaState: LoadState = .idle
    @Published private(set) var openCodeGoState: LoadState = .idle
    @Published private(set) var isRefreshing = false
    @Published private(set) var configuration: ResetStatConfiguration
    @Published var now = Date()

    private let configurationStore: ResetStatConfigurationStore?
    private let service: CodexUsageFetching?
    private let cursorService: CursorUsageFetching?
    private let desktopQuotaService: DesktopQuotaFetching?
    private let openCodeGoService: OpenCodeGoUsageFetching?
    private var didStartLoops = false

    convenience init(configurationStore: ResetStatConfigurationStore = ResetStatConfigurationStore()) {
        self.init(
            configurationStore: configurationStore,
            configuration: configurationStore.configuration,
            service: nil,
            cursorService: nil,
            desktopQuotaService: nil,
            openCodeGoService: nil
        )
    }

    init(
        configuration: ResetStatConfiguration = .defaults,
        service: CodexUsageFetching,
        cursorService: CursorUsageFetching,
        desktopQuotaService: DesktopQuotaFetching,
        openCodeGoService: OpenCodeGoUsageFetching
    ) {
        self.configurationStore = nil
        self.configuration = configuration
        self.service = service
        self.cursorService = cursorService
        self.desktopQuotaService = desktopQuotaService
        self.openCodeGoService = openCodeGoService
    }

    private init(
        configurationStore: ResetStatConfigurationStore?,
        configuration: ResetStatConfiguration,
        service: CodexUsageFetching?,
        cursorService: CursorUsageFetching?,
        desktopQuotaService: DesktopQuotaFetching?,
        openCodeGoService: OpenCodeGoUsageFetching?
    ) {
        self.configurationStore = configurationStore
        self.configuration = configuration
        self.service = service
        self.cursorService = cursorService
        self.desktopQuotaService = desktopQuotaService
        self.openCodeGoService = openCodeGoService
    }

    func start() {
        guard !didStartLoops else { return }
        didStartLoops = true

        Task { await refreshLoop() }
        Task { await clockLoop() }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: Void.self) { group in
            if self.configuration.providers.codex.isEnabled {
                group.addTask { await self.refreshCodex() }
            } else {
                state = .disabled
                snapshot = nil
            }

            if self.configuration.providers.cursor.isEnabled {
                group.addTask { await self.refreshCursor() }
            } else {
                cursorState = .disabled
                cursorSnapshot = nil
            }

            if self.configuration.providers.devin.isEnabled {
                group.addTask { await self.refreshDesktopQuotas() }
            } else {
                desktopQuotaState = .disabled
                desktopQuotaSnapshots = []
            }

            if self.configuration.providers.openCodeGo.isEnabled {
                group.addTask { await self.refreshOpenCodeGo() }
            } else {
                openCodeGoState = .disabled
                openCodeGoSnapshot = nil
            }
        }
    }

    func updateConfiguration(_ update: (inout ResetStatConfiguration) -> Void) {
        update(&configuration)
        configurationStore?.configuration = configuration
        configurationStore?.save()
        applyDisabledStates()
    }

    func resetConfigurationToDefaults() {
        configuration = .defaults
        configurationStore?.configuration = configuration
        configurationStore?.save()
        applyDisabledStates()
    }

    private func refreshCodex() async {
        state = snapshot == nil ? .loading : .loaded
        do {
            snapshot = try await codexService().fetchSnapshot()
            state = .loaded
        } catch let error as CodexUsageError {
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed("Usage data is temporarily unavailable.")
        }
    }

    private func refreshCursor() async {
        cursorState = cursorSnapshot == nil ? .loading : .loaded
        do {
            cursorSnapshot = try await cursorUsageService().fetchSnapshot()
            cursorState = .loaded
        } catch let error as CursorUsageError {
            cursorState = .failed(error.localizedDescription)
        } catch {
            cursorState = .failed("Cursor usage is temporarily unavailable.")
        }
    }

    private func refreshDesktopQuotas() async {
        desktopQuotaState = desktopQuotaSnapshots.isEmpty ? .loading : .loaded
        do {
            let snapshots = try await desktopQuotaUsageService().fetchSnapshots()
            desktopQuotaSnapshots = snapshots
            desktopQuotaState = snapshots.isEmpty ? .failed("Devin quota cache unavailable.") : .loaded
        } catch {
            desktopQuotaState = .failed("Devin quotas are temporarily unavailable.")
        }
    }

    private func refreshOpenCodeGo() async {
        openCodeGoState = openCodeGoSnapshot == nil ? .loading : .loaded
        do {
            openCodeGoSnapshot = try await openCodeGoUsageService().fetchSnapshot()
            openCodeGoState = .loaded
        } catch let error as CodexUsageError {
            openCodeGoState = .failed(error.localizedDescription)
        } catch {
            openCodeGoState = .failed("OpenCode Go usage is temporarily unavailable.")
        }
    }

    private func codexService() -> CodexUsageFetching {
        service ?? CodexAppServerClient(executablePath: configuration.providers.codex.executablePath)
    }

    private func cursorUsageService() -> CursorUsageFetching {
        cursorService ?? CursorUsageClient(stateDatabasePath: configuration.providers.cursor.stateDatabasePath)
    }

    private func desktopQuotaUsageService() -> DesktopQuotaFetching {
        if let desktopQuotaService {
            return desktopQuotaService
        }
        let source = DesktopQuotaSource(
            appName: "Devin Desktop",
            databasePath: configuration.providers.devin.stateDatabasePath,
            keyQueries: [
                "SELECT value FROM ItemTable WHERE key='windsurfAuthStatus' LIMIT 1;",
                "SELECT value FROM ItemTable WHERE key LIKE 'windsurf.reactSettings.cachedPlanInfoData:%' ORDER BY key LIMIT 1;",
                "SELECT value FROM ItemTable WHERE key='windsurf.settings.cachedPlanInfo' LIMIT 1;"
            ]
        )
        return DesktopQuotaClient(sources: [source], liveDatabasePath: configuration.providers.devin.stateDatabasePath)
    }

    private func openCodeGoUsageService() -> OpenCodeGoUsageFetching {
        openCodeGoService ?? OpenCodeGoUsageClient(configPath: configuration.providers.openCodeGo.configPath)
    }

    func isProviderEnabled(_ tab: ProviderTab) -> Bool {
        switch tab {
        case .codex:
            return configuration.providers.codex.isEnabled
        case .cursor:
            return configuration.providers.cursor.isEnabled
        case .devin:
            return configuration.providers.devin.isEnabled
        case .openCodeGo:
            return configuration.providers.openCodeGo.isEnabled
        case .overview, .settings:
            return true
        }
    }

    private func applyDisabledStates() {
        if !configuration.providers.codex.isEnabled {
            state = .disabled
            snapshot = nil
        }
        if !configuration.providers.cursor.isEnabled {
            cursorState = .disabled
            cursorSnapshot = nil
        }
        if !configuration.providers.devin.isEnabled {
            desktopQuotaState = .disabled
            desktopQuotaSnapshots = []
        }
        if !configuration.providers.openCodeGo.isEnabled {
            openCodeGoState = .disabled
            openCodeGoSnapshot = nil
        }
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(300))
        }
    }

    private func clockLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            now = Date()
        }
    }
}
