package com.kaiasai.fukura

import org.json.JSONArray
import org.json.JSONObject

object SnippetParser {
    private const val MAX_SNIPPETS = 500
    private const val MAX_TRIGGER_LENGTH = 64
    private const val MAX_BODY_LENGTH = 8_000

    fun parse(json: String): SnippetFile {
        val root = try {
            JSONObject(json)
        } catch (error: Exception) {
            throw SnippetValidationException("snippets.json のJSONが不正です: ${error.message}")
        }

        if (root.optInt("version") != 1) {
            throw SnippetValidationException("version は 1 のみ対応しています。")
        }

        val snippetsArray = root.optJSONArray("snippets")
            ?: throw SnippetValidationException("snippets は配列である必要があります。")
        if (snippetsArray.length() > MAX_SNIPPETS) {
            throw SnippetValidationException("snippets は ${MAX_SNIPPETS} 件以下にしてください。")
        }

        val seenTriggers = mutableSetOf<String>()
        val snippets = mutableListOf<Snippet>()
        for (index in 0 until snippetsArray.length()) {
            val item = snippetsArray.optJSONObject(index)
                ?: throw SnippetValidationException("snippets[$index] はオブジェクトである必要があります。")

            val id = item.optString("id")
            val trigger = item.optString("trigger")
            val body = item.optString("body")
            if (id.isEmpty()) throw SnippetValidationException("snippets[$index].id は必須です。")
            if (trigger.isEmpty()) throw SnippetValidationException("snippets[$index].trigger は必須です。")
            if (trigger.length > MAX_TRIGGER_LENGTH) {
                throw SnippetValidationException("snippets[$index].trigger は ${MAX_TRIGGER_LENGTH} 文字以下にしてください。")
            }
            if (body.isEmpty()) throw SnippetValidationException("snippets[$index].body は必須です。")
            if (body.length > MAX_BODY_LENGTH) {
                throw SnippetValidationException("snippets[$index].body は ${MAX_BODY_LENGTH} 文字以下にしてください。")
            }
            if (!seenTriggers.add(trigger)) throw SnippetValidationException("trigger が重複しています: $trigger")

            snippets += Snippet(
                id = id,
                trigger = trigger,
                body = body,
                enabled = !item.has("enabled") || item.optBoolean("enabled"),
                tags = item.optJSONArray("tags").toStringList()
            )
        }

        return SnippetFile(
            version = 1,
            updatedAt = root.optString("updated_at").ifEmpty { null },
            snippets = snippets
        )
    }

    private fun JSONArray?.toStringList(): List<String> {
        if (this == null) return emptyList()
        return (0 until length()).mapNotNull { index -> optString(index).takeIf { it.isNotEmpty() } }
    }
}
