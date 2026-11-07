package com.kaiasai.fukura

object SnippetPresentation {
    fun preview(body: String): String = body.replace("\n", " ↵ ")

    fun lineCount(body: String): Int = if (body.isEmpty()) 0 else body.split("\n").size

    fun bodyCaption(body: String): String =
        "本文: ${body.length} / 8000文字・${lineCount(body)}行"

    fun statusMessage(count: Int): String =
        "読み込み済み: $count 件。設定アプリでキーボードを有効化してください。"
}
