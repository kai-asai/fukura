package com.kaiasai.fukura

class SnippetMatcher(snippets: List<Snippet>) {
    private val enabled = snippets
        .filter { it.enabled }
        .sortedWith(compareByDescending<Snippet> { it.trigger.length }.thenBy { it.trigger })
    private val maxTriggerLength = enabled.maxOfOrNull { it.trigger.length } ?: 0
    private var buffer = ""

    fun push(text: String): Snippet? {
        buffer = (buffer + text).takeLast(maxTriggerLength)
        val match = enabled.firstOrNull { buffer.endsWith(it.trigger) }
        if (match != null) {
            buffer = ""
        }
        return match
    }

    fun reset() {
        buffer = ""
    }
}
