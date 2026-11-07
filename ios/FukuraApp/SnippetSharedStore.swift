import Foundation

final class SnippetSharedStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published var message = "辞書を準備しています。"

    private let appGroupID = "group.com.kaiasai.fukura"
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
        guard let snippetsURL else {
            message = "App Groups の共有コンテナにアクセスできません。署名と App Group を確認してください。"
            return
        }
        if !FileManager.default.fileExists(atPath: snippetsURL.path) {
            do {
                try Data(SnippetValidator.exampleJSON.utf8).write(to: snippetsURL, options: .atomic)
            } catch {
                message = error.localizedDescription
                return
            }
        }
        do {
            let data = try SnippetValidator.readDataCheckingSize(from: snippetsURL)
            let file = try SnippetValidator.decode(data)
            snippets = file.snippets
            message = "読み込み済み: \(snippets.count) 件。Fukura Keyboard を選んでいるときだけ展開できます。標準キーボードでは動作しません。"
        } catch {
            message = error.localizedDescription
        }
    }

    func importJSON(from sourceURL: URL) throws {
        guard let snippetsURL, let backupURL else {
            throw SnippetValidationError.invalidSnippet("App Groups の共有コンテナにアクセスできません。")
        }

        let allowed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if allowed { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let data = try SnippetValidator.readDataCheckingSize(from: sourceURL)
        _ = try SnippetValidator.decode(data)
        if FileManager.default.fileExists(atPath: snippetsURL.path) {
            _ = try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: snippetsURL, to: backupURL)
        }
        try data.write(to: snippetsURL, options: .atomic)
        load()
    }

    func exportData() throws -> Data {
        guard let snippetsURL else {
            throw SnippetValidationError.invalidSnippet("App Groups の共有コンテナにアクセスできません。")
        }
        if !FileManager.default.fileExists(atPath: snippetsURL.path) {
            load()
        }
        let data = try SnippetValidator.readDataCheckingSize(from: snippetsURL)
        _ = try SnippetValidator.decode(data)
        return data
    }

    func save(_ newSnippets: [Snippet]) throws {
        guard let snippetsURL, let backupURL else {
            throw SnippetValidationError.invalidSnippet("App Groups の共有コンテナにアクセスできません。")
        }
        let file = SnippetFile(
            version: 1,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            snippets: newSnippets
        )
        let data = try SnippetValidator.encode(file)
        if FileManager.default.fileExists(atPath: snippetsURL.path) {
            _ = try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: snippetsURL, to: backupURL)
        }
        try data.write(to: snippetsURL, options: .atomic)
        load()
    }
}
