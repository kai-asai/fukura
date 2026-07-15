import Foundation

final class SnippetSharedStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published var message = "snippets.json をインポートしてください。"

    private let appGroupID = "group.com.kaiasai.fukura"
    private let legacyAppGroupIDs = [
        "group.com.kaiasai.bon",
        "group.dev.fsc.snippetexpander"
    ]
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    private var snippetsURL: URL? {
        containerURL?.appendingPathComponent("snippets.json")
    }
    private var backupURL: URL? {
        containerURL?.appendingPathComponent("snippets.backup.json")
    }

    func load() {
        migrateLegacyDataIfNeeded()
        guard let snippetsURL, FileManager.default.fileExists(atPath: snippetsURL.path) else {
            return
        }
        do {
            let data = try SnippetValidator.readDataCheckingSize(from: snippetsURL)
            let file = try JSONDecoder().decode(SnippetFile.self, from: data)
            snippets = try SnippetValidator.validate(file)
            message = "読み込み済み: \(snippets.count) 件。設定アプリでキーボードを有効化してください。"
        } catch {
            message = error.localizedDescription
        }
    }

    private func migrateLegacyDataIfNeeded() {
        guard let snippetsURL,
              !FileManager.default.fileExists(atPath: snippetsURL.path) else {
            return
        }

        for legacyAppGroupID in legacyAppGroupIDs {
            guard let legacyContainerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: legacyAppGroupID
            ) else {
                continue
            }
            let legacySnippetsURL = legacyContainerURL.appendingPathComponent("snippets.json")
            guard FileManager.default.fileExists(atPath: legacySnippetsURL.path) else {
                continue
            }

            do {
                try FileManager.default.copyItem(at: legacySnippetsURL, to: snippetsURL)
                if let backupURL {
                    let legacyBackupURL = legacyContainerURL.appendingPathComponent("snippets.backup.json")
                    if FileManager.default.fileExists(atPath: legacyBackupURL.path) {
                        _ = try? FileManager.default.removeItem(at: backupURL)
                        try FileManager.default.copyItem(at: legacyBackupURL, to: backupURL)
                    }
                }
            } catch {
                message = "旧版からの辞書移行に失敗しました: \(error.localizedDescription)"
            }
            return
        }
    }

    func importJSON(from sourceURL: URL) {
        guard let snippetsURL, let backupURL else {
            message = "App Groups の共有コンテナにアクセスできません。"
            return
        }

        do {
            let allowed = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if allowed { sourceURL.stopAccessingSecurityScopedResource() }
            }

            let data = try SnippetValidator.readDataCheckingSize(from: sourceURL)
            let file = try JSONDecoder().decode(SnippetFile.self, from: data)
            _ = try SnippetValidator.validate(file)

            if FileManager.default.fileExists(atPath: snippetsURL.path) {
                _ = try? FileManager.default.removeItem(at: backupURL)
                try FileManager.default.copyItem(at: snippetsURL, to: backupURL)
            }
            try data.write(to: snippetsURL, options: .atomic)
            load()
        } catch {
            message = error.localizedDescription
        }
    }

    func save(_ newSnippets: [Snippet]) throws {
        guard let snippetsURL, let backupURL else {
            throw SnippetValidationError.invalidSnippet("App Groups の共有コンテナにアクセスできません。")
        }
        let file = SnippetFile(version: 1, updatedAt: ISO8601DateFormatter().string(from: Date()), snippets: newSnippets)
        _ = try SnippetValidator.validate(file)
        if FileManager.default.fileExists(atPath: snippetsURL.path) {
            _ = try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: snippetsURL, to: backupURL)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(file).write(to: snippetsURL, options: .atomic)
        load()
    }
}
