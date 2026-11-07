package com.kaiasai.fukura

class SnippetMatcher(snippets: List<Snippet>) {
    private val enabled = snippets
        .filter { it.enabled }
        .sortedWith(compareByDescending<Snippet> { it.trigger.length }.thenBy { it.trigger })
    private val maxTriggerLength = enabled.maxOfOrNull { it.trigger.length } ?: 0
    private var buffer = ""

    fun push(text: String): Snippet? {
        if (maxTriggerLength == 0 || text.isEmpty()) return currentMatch()
        buffer = (buffer + text).takeLast(maxTriggerLength)
        return currentMatch()
    }

    fun backspace(codeUnits: Int = 1): Snippet? {
        if (codeUnits > 0 && buffer.isNotEmpty()) {
            buffer = buffer.dropLast(codeUnits.coerceAtMost(buffer.length))
        }
        return currentMatch()
    }

    fun currentMatch(): Snippet? = enabled.firstOrNull { buffer.endsWith(it.trigger) }

    fun reset() {
        buffer = ""
    }
}
