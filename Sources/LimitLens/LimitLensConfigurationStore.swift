import Combine
import Foundation

@MainActor
final class LimitLensConfigurationStore: ObservableObject {
    @Published var configuration: LimitLensConfiguration

    let url: URL

    init(url: URL = .defaultLimitLensConfigurationURL) {
        self.url = url
        self.configuration = Self.load(from: url)
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to save LimitLens configuration: \(error)")
        }
    }

    func resetToDefaults() {
        configuration = .defaults
        save()
    }

    private static func load(from url: URL) -> LimitLensConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .detected()
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(LimitLensConfiguration.self, from: data)
        } catch {
            preserveInvalidConfiguration(at: url)
            return .defaults
        }
    }

    private static func preserveInvalidConfiguration(at url: URL) {
        let invalidURL = url.deletingLastPathComponent().appendingPathComponent("config.invalid.json")
        try? FileManager.default.removeItem(at: invalidURL)
        try? FileManager.default.moveItem(at: url, to: invalidURL)
    }
}
