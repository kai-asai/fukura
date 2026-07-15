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

struct Snippet: Codable, Identifiable {
    let id: String
    let trigger: String
    let body: String
    let enabled: Bool?
    let tags: [String]?
}

enum SnippetValidationError: LocalizedError {
    case unsupportedVersion
    case invalidSnippet(String)
    case duplicateTrigger(String)
    case fileTooLarge(Int64)

    var errorDescription: String? {
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

enum SnippetValidator {
    static let maxJSONBytes: Int64 = 512 * 1024
    static let maxSnippetCount = 500
    static let maxTriggerLength = 64
    static let maxBodyLength = 8_000

    static func readDataCheckingSize(from url: URL) throws -> Data {
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

    static func validate(_ file: SnippetFile) throws -> [Snippet] {
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
