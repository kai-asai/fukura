package com.kaiasai.fukura

import android.content.Context
import android.net.Uri
import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import java.time.OffsetDateTime

class SnippetRepository(private val context: Context) {
    private val file = File(context.filesDir, "snippets.json")
    private val backup = File(context.filesDir, "snippets.backup.json")

    fun load(): SnippetFile {
        if (!file.exists()) {
            file.writeText(defaultJson)
        }
        if (file.length() > MAX_JSON_BYTES) {
            throw SnippetValidationException("snippets.json は ${MAX_JSON_BYTES} bytes 以下にしてください。")
        }
        return SnippetParser.parse(file.readText())
    }

    fun importFrom(uri: Uri): SnippetFile {
        if (file.exists()) {
            file.copyTo(backup, overwrite = true)
        }

        context.contentResolver.openAssetFileDescriptor(uri, "r")?.use { descriptor ->
            if (descriptor.length > MAX_JSON_BYTES) {
                throw SnippetValidationException("snippets.json は ${MAX_JSON_BYTES} bytes 以下にしてください。")
            }
        }
        val json = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
            ?: throw SnippetValidationException("ファイルを読み込めません。")
        if (json.toByteArray().size > MAX_JSON_BYTES) {
            throw SnippetValidationException("snippets.json は ${MAX_JSON_BYTES} bytes 以下にしてください。")
        }
        val parsed = SnippetParser.parse(json)
        file.writeText(json)
        return parsed
    }

    fun exportTo(uri: Uri) {
        load()
        val json = file.readText()
        SnippetParser.parse(json)
        context.contentResolver.openOutputStream(uri, "wt")?.bufferedWriter()?.use { writer ->
            writer.write(json)
        } ?: throw SnippetValidationException("書き出し先を開けません。")
    }

    fun save(snippets: List<Snippet>): SnippetFile {
        val root = JSONObject().apply {
            put("version", 1)
            put("updated_at", OffsetDateTime.now().toString())
            put("snippets", JSONArray().apply {
                snippets.forEach { snippet ->
                    put(JSONObject().apply {
                        put("id", snippet.id); put("trigger", snippet.trigger); put("body", snippet.body); put("enabled", snippet.enabled)
                        if (snippet.tags.isNotEmpty()) put("tags", JSONArray(snippet.tags))
                    })
                }
            })
        }
        val json = root.toString(2)
        if (json.toByteArray().size > MAX_JSON_BYTES) throw SnippetValidationException("snippets.json は ${MAX_JSON_BYTES} bytes 以下にしてください。")
        val parsed = SnippetParser.parse(json)
        if (file.exists()) file.copyTo(backup, overwrite = true)
        val temporary = File(context.filesDir, "snippets.json.tmp")
        temporary.writeText(json)
        temporary.copyTo(file, overwrite = true)
        temporary.delete()
        return parsed
    }

    companion object {
        private const val MAX_JSON_BYTES = 512 * 1024

        val defaultJson = """
            {
              "version": 1,
              "updated_at": "2026-06-20T10:00:00+09:00",
              "snippets": [
                { "id": "mail", "trigger": ";mail", "body": "your.name@example.com", "enabled": true },
                { "id": "thanks", "trigger": ";thx", "body": "ありがとうございます。確認いたします。", "enabled": true },
                { "id": "address", "trigger": ";addr", "body": "住所を入力してください", "enabled": false }
              ]
            }
        """.trimIndent()
    }
}
