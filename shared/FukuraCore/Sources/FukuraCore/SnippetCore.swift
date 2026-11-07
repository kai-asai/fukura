import Foundation

public struct SnippetFile: Codable, Equatable {
    public let version: Int
    public let updatedAt: String?
    public let snippets: [Snippet]

    public init(version: Int, updatedAt: String?, snippets: [Snippet]) {
        self.version = version
        self.updatedAt = updatedAt
        self.snippets = snippets
    }

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case snippets
    }
}

public struct Snippet: Codable, Equatable, Identifiable {
    public let id: String
    public let trigger: String
    public let body: String
    public let enabled: Bool?
    public let tags: [String]?
    public let updatedAt: String?

    public init(
        id: String,
        trigger: String,
        body: String,
        enabled: Bool? = nil,
        tags: [String]? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.body = body
        self.enabled = enabled
        self.tags = tags
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case trigger
        case body
        case enabled
        case tags
        case updatedAt = "updated_at"
    }
}

public enum SnippetValidationError: LocalizedError, Equatable {
    case unsupportedVersion
    case invalidSnippet(String)
    case duplicateTrigger(String)
    case fileTooLarge(Int64)

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return "version は 1 のみ対応しています。"
        case .invalidSnippet(let message):
            return message
        case .duplicateTrigger(let trigger):
            return "trigger が重複しています: \(trigger)"
        case .fileTooLarge(let maxBytes):
            return "snippets.json は \(maxBytes) bytes 以下にしてください。"
        }
    }
}

public enum SnippetValidator {
    public static let maxJSONBytes: Int64 = 512 * 1024
    public static let maxSnippetCount = 500
    public static let maxTriggerLength = 64
    public static let maxBodyLength = 8_000

    public static let exampleJSON = """
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

    public static func readDataCheckingSize(from url: URL) throws -> Data {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values?.fileSize, Int64(fileSize) > maxJSONBytes {
            throw SnippetValidationError.fileTooLarge(maxJSONBytes)
        }

        let data = try Data(contentsOf: url)
        if Int64(data.count) > maxJSONBytes {
            throw SnippetValidationError.fileTooLarge(maxJSONBytes)
        }
        return data
    }

    public static func decode(_ data: Data) throws -> SnippetFile {
        if Int64(data.count) > maxJSONBytes {
            throw SnippetValidationError.fileTooLarge(maxJSONBytes)
        }
        do {
            let file = try JSONDecoder().decode(SnippetFile.self, from: data)
            _ = try validate(file)
            return file
        } catch let error as SnippetValidationError {
            throw error
        } catch {
            throw SnippetValidationError.invalidSnippet("snippets.json のJSONが不正です。")
        }
    }

    public static func encode(_ file: SnippetFile) throws -> Data {
        _ = try validate(file)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(file)
        if Int64(data.count) > maxJSONBytes {
            throw SnippetValidationError.fileTooLarge(maxJSONBytes)
        }
        return data
    }

    public static func validate(_ file: SnippetFile) throws -> [Snippet] {
        guard file.version == 1 else {
            throw SnippetValidationError.unsupportedVersion
        }
        guard file.snippets.count <= maxSnippetCount else {
            throw SnippetValidationError.invalidSnippet("snippets は \(maxSnippetCount) 件以下にしてください。")
        }

        var triggers = Set<String>()
        for snippet in file.snippets {
            guard !snippet.id.isEmpty else {
                throw SnippetValidationError.invalidSnippet("id は必須です。")
            }
            guard !snippet.trigger.isEmpty else {
                throw SnippetValidationError.invalidSnippet("trigger は必須です。")
            }
            guard snippet.trigger.count <= maxTriggerLength else {
                throw SnippetValidationError.invalidSnippet("trigger は \(maxTriggerLength) 文字以下にしてください。")
            }
            guard !snippet.body.isEmpty else {
                throw SnippetValidationError.invalidSnippet("body は必須です。")
            }
            guard snippet.body.count <= maxBodyLength else {
                throw SnippetValidationError.invalidSnippet("body は \(maxBodyLength) 文字以下にしてください。")
            }
            guard !triggers.contains(snippet.trigger) else {
                throw SnippetValidationError.duplicateTrigger(snippet.trigger)
            }
            triggers.insert(snippet.trigger)
        }
        return file.snippets
    }
}

public final class SnippetMatcher {
    private let snippets: [Snippet]
    private let maxTriggerLength: Int
    private var buffer = ""

    public init(snippets: [Snippet]) {
        self.snippets = snippets
            .filter { $0.enabled != false }
            .sorted { left, right in
                if left.trigger.count == right.trigger.count {
                    return left.trigger < right.trigger
                }
                return left.trigger.count > right.trigger.count
            }
        maxTriggerLength = self.snippets.map(\.trigger.count).max() ?? 0
    }

    public var hasSnippets: Bool { !snippets.isEmpty }

    public func push(_ text: String) -> Snippet? {
        guard maxTriggerLength > 0, !text.isEmpty else { return currentMatch() }
        buffer = String((buffer + text).suffix(maxTriggerLength))
        return currentMatch()
    }

    public func backspace() -> Snippet? {
        if !buffer.isEmpty {
            buffer.removeLast()
        }
        return currentMatch()
    }

    public func currentMatch() -> Snippet? {
        snippets.first { buffer.hasSuffix($0.trigger) }
    }

    public func reset() {
        buffer = ""
    }
}
