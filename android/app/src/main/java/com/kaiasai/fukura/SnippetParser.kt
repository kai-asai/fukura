package com.kaiasai.fukura

import org.json.JSONArray
import org.json.JSONObject

object SnippetParser {
    const val MAX_JSON_BYTES = 512 * 1024
    private const val MAX_SNIPPETS = 500
    private const val MAX_TRIGGER_LENGTH = 64
    private const val MAX_BODY_LENGTH = 8_000

    fun parse(json: String): SnippetFile {
        if (json.toByteArray().size > MAX_JSON_BYTES) {
            throw SnippetValidationException("snippets.json は ${MAX_JSON_BYTES} bytes 以下にしてください。")
        }
        val root = try {
            JSONObject(json)
        } catch (error: Exception) {
            throw SnippetValidationException("snippets.json のJSONが不正です: ${error.message}")
        }

        if ((root.opt("version") as? Number)?.toInt() != 1) {
            throw SnippetValidationException("version は 1 のみ対応しています。")
        }

        val snippetsValue = if (root.has("snippets")) root.get("snippets") else null
        val snippetsArray = snippetsValue as? JSONArray
            ?: throw SnippetValidationException("snippets は配列である必要があります。")
        if (snippetsArray.length() > MAX_SNIPPETS) {
            throw SnippetValidationException("snippets は ${MAX_SNIPPETS} 件以下にしてください。")
        }

        val seenTriggers = mutableSetOf<String>()
        val snippets = mutableListOf<Snippet>()
        for (index in 0 until snippetsArray.length()) {
            val item = snippetsArray.optJSONObject(index)
                ?: throw SnippetValidationException("snippets[$index] はオブジェクトである必要があります。")
            val prefix = "snippets[$index]"
            val id = requiredString(item, "id", "$prefix.id")
            val trigger = requiredString(item, "trigger", "$prefix.trigger")
            val body = requiredString(item, "body", "$prefix.body")
            if (trigger.length > MAX_TRIGGER_LENGTH) {
                throw SnippetValidationException("$prefix.trigger は ${MAX_TRIGGER_LENGTH} 文字以下にしてください。")
            }
            if (body.length > MAX_BODY_LENGTH) {
                throw SnippetValidationException("$prefix.body は ${MAX_BODY_LENGTH} 文字以下にしてください。")
            }
            if (!seenTriggers.add(trigger)) throw SnippetValidationException("trigger が重複しています: $trigger")

            val enabled = when {
                !item.has("enabled") -> true
                item.get("enabled") is Boolean -> item.getBoolean("enabled")
                else -> throw SnippetValidationException("$prefix.enabled は boolean である必要があります。")
            }
            snippets += Snippet(
                id = id,
                trigger = trigger,
                body = body,
                enabled = enabled,
                tags = stringTags(item.opt("tags"))
            )
        }

        val updatedAt = if (root.opt("updated_at") is String) root.getString("updated_at") else null
        return SnippetFile(version = 1, updatedAt = updatedAt, snippets = snippets)
    }

    private fun requiredString(item: JSONObject, key: String, field: String): String {
        val value = item.opt(key)
        if (value !is String || value.isEmpty()) {
            throw SnippetValidationException("$field は空でない文字列である必要があります。")
        }
        return value
    }

    private fun stringTags(value: Any?): List<String> {
        val array = value as? JSONArray ?: return emptyList()
        return (0 until array.length()).mapNotNull { index ->
            (array.opt(index) as? String)?.takeIf { it.isNotEmpty() }
        }
    }
}
