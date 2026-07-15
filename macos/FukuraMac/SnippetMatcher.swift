import Foundation

final class SnippetMatcher {
    private var buffer = ""
    private var snippets: [Snippet] = []
    private var maxTriggerLength = 0

    func update(snippets: [Snippet]) {
        self.snippets = snippets.sorted { left, right in
            if left.trigger.count == right.trigger.count {
                return left.trigger < right.trigger
            }
            return left.trigger.count > right.trigger.count
        }
        maxTriggerLength = self.snippets.map { $0.trigger.count }.max() ?? 0
        buffer = ""
    }

    func push(_ text: String) -> Snippet? {
        buffer += text
        if buffer.count > maxTriggerLength {
            buffer = String(buffer.suffix(maxTriggerLength))
        }

        if let match = snippets.first(where: { buffer.hasSuffix($0.trigger) }) {
            buffer = ""
            return match
        }
        return nil
    }

    func reset() {
        buffer = ""
    }
}
