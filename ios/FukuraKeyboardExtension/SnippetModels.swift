import Foundation

struct SnippetFile: Codable {
    let version: Int
    let snippets: [Snippet]
}

struct Snippet: Codable {
    let id: String
    let trigger: String
    let body: String
    let enabled: Bool?
}

enum SnippetValidator {
    static let maxJSONBytes: Int64 = 512 * 1024
    static let maxSnippetCount = 500
    static let maxTriggerLength = 64
    static let maxBodyLength = 8_000

    static func readDataCheckingSize(from url: URL) throws -> Data {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values?.fileSize, Int64(fileSize) > maxJSONBytes {
            throw NSError(domain: "fukura", code: 1)
        }

        let data = try Data(contentsOf: url)
        if Int64(data.count) > maxJSONBytes {
            throw NSError(domain: "fukura", code: 1)
        }
        return data
    }

    static func validate(_ file: SnippetFile) throws -> [Snippet] {
        guard file.version == 1 else {
            return []
        }
        guard file.snippets.count <= maxSnippetCount else {
            return []
        }
        var triggers = Set<String>()
        return file.snippets.filter { snippet in
            guard !snippet.id.isEmpty, !snippet.trigger.isEmpty, !snippet.body.isEmpty else {
                return false
            }
            guard snippet.trigger.count <= maxTriggerLength, snippet.body.count <= maxBodyLength else {
                return false
            }
            guard !triggers.contains(snippet.trigger) else {
                return false
            }
            triggers.insert(snippet.trigger)
            return snippet.enabled ?? true
        }
    }
}
