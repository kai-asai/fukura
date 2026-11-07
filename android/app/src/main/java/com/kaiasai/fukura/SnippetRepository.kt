package com.kaiasai.fukura

import android.content.Context
import android.net.Uri
import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import java.time.OffsetDateTime

class SnippetRepository private constructor(
    private val directory: File,
    private val context: Context?
) {
    constructor(context: Context) : this(context.filesDir, context)

    constructor(directory: File) : this(directory, null)

    private val file = File(directory, "snippets.json")
    private val backup = File(directory, "snippets.backup.json")

    fun load(): SnippetFile {
        if (!file.exists()) {
            directory.mkdirs()
            file.writeText(defaultJson)
        }
        if (file.length() > SnippetParser.MAX_JSON_BYTES) {
            throw SnippetValidationException("snippets.json は ${SnippetParser.MAX_JSON_BYTES} bytes 以下にしてください。")
        }
        return SnippetParser.parse(file.readText())
    }

    fun importFrom(uri: Uri): SnippetFile {
        val currentContext = context ?: throw SnippetValidationException("ファイルを読み込めません。")
        currentContext.contentResolver.openAssetFileDescriptor(uri, "r")?.use { descriptor ->
            if (descriptor.length > SnippetParser.MAX_JSON_BYTES) {
                throw SnippetValidationException("snippets.json は ${SnippetParser.MAX_JSON_BYTES} bytes 以下にしてください。")
            }
        }
        val json = currentContext.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
            ?: throw SnippetValidationException("ファイルを読み込めません。")
        return importText(json)
    }

    fun importText(json: String): SnippetFile {
        val parsed = SnippetParser.parse(json)
        directory.mkdirs()
        if (file.exists()) file.copyTo(backup, overwrite = true)
        file.writeText(json)
        return parsed
    }

    fun exportTo(uri: Uri) {
        val currentContext = context ?: throw SnippetValidationException("書き出し先を開けません。")
        val json = exportText()
        currentContext.contentResolver.openOutputStream(uri, "wt")?.bufferedWriter()?.use { writer ->
            writer.write(json)
        } ?: throw SnippetValidationException("書き出し先を開けません。")
    }

    fun exportText(): String {
        load()
        val json = file.readText()
        SnippetParser.parse(json)
        return json
    }

    fun save(snippets: List<Snippet>): SnippetFile {
        val root = JSONObject().apply {
            put("version", 1)
            put("updated_at", OffsetDateTime.now().toString())
            put("snippets", JSONArray().apply {
                snippets.forEach { snippet ->
                    put(JSONObject().apply {
                        put("id", snippet.id)
                        put("trigger", snippet.trigger)
                        put("body", snippet.body)
                        put("enabled", snippet.enabled)
                        if (snippet.tags.isNotEmpty()) put("tags", JSONArray(snippet.tags))
                    })
                }
            })
        }
        val json = root.toString(2)
        val parsed = SnippetParser.parse(json)
        directory.mkdirs()
        if (file.exists()) file.copyTo(backup, overwrite = true)
        val temporary = File(directory, "snippets.json.tmp")
        temporary.writeText(json)
        temporary.copyTo(file, overwrite = true)
        temporary.delete()
        return parsed
    }

    companion object {
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
