import Foundation

struct SnippetFile: Codable {
    let version: Int
    let updatedAt: String?
    let snippets: [Snippet]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case snippets
    }
}

struct Snippet: Codable {
    let id: String
    let trigger: String
    let body: String
    let enabled: Bool?
    let tags: [String]?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case trigger
        case body
        case enabled
        case tags
        case updatedAt = "updated_at"
    }
}

enum SnippetStoreError: LocalizedError {
    case unsupportedVersion
    case duplicateTrigger(String)
    case invalidSnippet(String)
    case fileTooLarge(Int64)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return "version は 1 のみ対応しています。"
        case .duplicateTrigger(let trigger):
            return "trigger が重複しています: \(trigger)"
        case .invalidSnippet(let message):
            return message
        case .fileTooLarge(let maxBytes):
            return "snippets.json は \(maxBytes) bytes 以下にしてください。"
        }
    }
}

final class SnippetStore {
    private(set) var snippets: [Snippet] = []
    private(set) var document = SnippetFile(version: 1, updatedAt: nil, snippets: [])
    let fileURL: URL
    let backupURL: URL
    private let legacyFileURLs: [URL]

    init(
        fileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/fukura/snippets.json"),
        backupURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/fukura/snippets.backup.json"),
        legacyFileURLs: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/bon/snippets.json"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/SnippetExpander/snippets.json")
        ]
    ) {
        self.fileURL = fileURL
        self.backupURL = backupURL
        self.legacyFileURLs = legacyFileURLs
    }

    func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    func load() throws {
        try ensureDirectory()
        try migrateLegacyDataIfNeeded()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try Self.exampleJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let data = try Self.readDataCheckingSize(from: fileURL)
        let file = try JSONDecoder().decode(SnippetFile.self, from: data)
        snippets = try Self.validate(file)
        document = file
    }

    private func migrateLegacyDataIfNeeded() throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }

        for legacyFileURL in legacyFileURLs where fileManager.fileExists(atPath: legacyFileURL.path) {
            try fileManager.copyItem(at: legacyFileURL, to: fileURL)
            let legacyBackupURL = legacyFileURL
                .deletingLastPathComponent()
                .appendingPathComponent("snippets.backup.json")
            if fileManager.fileExists(atPath: legacyBackupURL.path) {
                _ = try? fileManager.removeItem(at: backupURL)
                try fileManager.copyItem(at: legacyBackupURL, to: backupURL)
            }
            return
        }
    }

    func importJSON(from sourceURL: URL) throws {
        try ensureDirectory()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: fileURL, to: backupURL)
        }

        let data = try Self.readDataCheckingSize(from: sourceURL)
        let file = try JSONDecoder().decode(SnippetFile.self, from: data)
        _ = try Self.validate(file)
        try data.write(to: fileURL, options: .atomic)
        try load()
    }

    func save(snippets newSnippets: [Snippet]) throws {
        try ensureDirectory()
        let formatter = ISO8601DateFormatter()
        let file = SnippetFile(
            version: 1,
            updatedAt: formatter.string(from: Date()),
            snippets: newSnippets
        )
        _ = try Self.validate(file)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: fileURL, to: backupURL)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(file)
        guard Int64(data.count) <= Self.maxJSONBytes else {
            throw SnippetStoreError.fileTooLarge(Self.maxJSONBytes)
        }
        try data.write(to: fileURL, options: .atomic)
        try load()
    }

    static func validate(_ file: SnippetFile) throws -> [Snippet] {
        guard file.version == 1 else {
            throw SnippetStoreError.unsupportedVersion
        }
        guard file.snippets.count <= maxSnippetCount else {
            throw SnippetStoreError.invalidSnippet("snippets は \(maxSnippetCount) 件以下にしてください。")
        }

        var triggers = Set<String>()
        for snippet in file.snippets {
            guard !snippet.id.isEmpty else {
                throw SnippetStoreError.invalidSnippet("id は必須です。")
            }
            guard !snippet.trigger.isEmpty else {
                throw SnippetStoreError.invalidSnippet("trigger は必須です。")
            }
            guard snippet.trigger.count <= maxTriggerLength else {
                throw SnippetStoreError.invalidSnippet("trigger は \(maxTriggerLength) 文字以下にしてください。")
            }
            guard !snippet.body.isEmpty else {
                throw SnippetStoreError.invalidSnippet("body は必須です。")
            }
            guard snippet.body.count <= maxBodyLength else {
                throw SnippetStoreError.invalidSnippet("body は \(maxBodyLength) 文字以下にしてください。")
            }
            guard !triggers.contains(snippet.trigger) else {
                throw SnippetStoreError.duplicateTrigger(snippet.trigger)
            }
            triggers.insert(snippet.trigger)
        }

        return file.snippets
            .filter { $0.enabled ?? true }
            .sorted { left, right in
                if left.trigger.count == right.trigger.count {
                    return left.trigger < right.trigger
                }
                return left.trigger.count > right.trigger.count
            }
    }

    static let maxJSONBytes: Int64 = 512 * 1024
    static let maxSnippetCount = 500
    static let maxTriggerLength = 64
    static let maxBodyLength = 8_000

    private static func readDataCheckingSize(from url: URL) throws -> Data {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values?.fileSize, Int64(fileSize) > maxJSONBytes {
            throw SnippetStoreError.fileTooLarge(maxJSONBytes)
        }

        let data = try Data(contentsOf: url)
        if Int64(data.count) > maxJSONBytes {
            throw SnippetStoreError.fileTooLarge(maxJSONBytes)
        }
        return data
    }

    static let exampleJSON = """
    {
      "version": 1,
      "updated_at": "2026-06-20T10:00:00+09:00",
      "snippets": [
        { "id": "mail", "trigger": ";mail", "body": "your.name@example.com", "enabled": true },
        { "id": "thanks", "trigger": ";thx", "body": "ありがとうございます。確認いたします。", "enabled": true },
        { "id": "address", "trigger": ";addr", "body": "住所を入力してください", "enabled": false }
      ]
    }
    """
}
