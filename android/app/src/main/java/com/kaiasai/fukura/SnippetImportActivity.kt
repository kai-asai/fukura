package com.kaiasai.fukura

import android.app.*
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.graphics.Color
import android.text.InputType
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.*
import java.util.UUID

class SnippetImportActivity : Activity() {
    private lateinit var repository: SnippetRepository
    private lateinit var summary: TextView
    private lateinit var list: LinearLayout
    private var snippets = mutableListOf<Snippet>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = SnippetRepository(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(32, 32, 32, 32)
            addView(TextView(this@SnippetImportActivity).apply { text = "fukura"; textSize = 24f })
            addView(TextView(this@SnippetImportActivity).apply { text = "本文は普通の複数行入力です。改行用の \\n を書く必要はありません。" })
            summary = TextView(this@SnippetImportActivity); addView(summary)
            addView(button("＋ スニペットを追加") { editSnippet(null) })
            addView(button("snippets.json をインポート") { openJsonPicker() })
            addView(button("snippets.json を書き出す") { createJsonFile() })
            addView(button("キーボードを有効化") { startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)) })
            addView(button("入力方法を選択") { (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager).showInputMethodPicker() })
            list = LinearLayout(this@SnippetImportActivity).apply { orientation = LinearLayout.VERTICAL }; addView(list)
        }
        setContentView(ScrollView(this).apply { addView(content) })
        runCatching { repository.load() }.onSuccess { showFile(it) }.onFailure { summary.text = it.message }
    }

    private fun button(label: String, action: () -> Unit) = Button(this).apply { text = label; setOnClickListener { action() } }

    private fun showFile(file: SnippetFile) {
        snippets = file.snippets.toMutableList()
        summary.text = "${snippets.size}件 / 有効 ${snippets.count { it.enabled }}件"
        list.removeAllViews()
        snippets.forEach { snippet ->
            list.addView(LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL; setPadding(0, 20, 0, 20)
                addView(TextView(this@SnippetImportActivity).apply { text = "${if (snippet.enabled) "●" else "○"} ${snippet.trigger}"; textSize = 18f })
                addView(TextView(this@SnippetImportActivity).apply { text = snippet.body.replace("\n", " ↵ "); maxLines = 2 })
                addView(button("編集") { editSnippet(snippet) })
            })
        }
    }

    private fun editSnippet(existing: Snippet?) {
        val trigger = EditText(this).apply { hint = ";mail"; setText(existing?.trigger ?: ";new"); inputType = InputType.TYPE_CLASS_TEXT }
        val body = EditText(this).apply { hint = "展開する文章"; setText(existing?.body ?: ""); minLines = 7; gravity = android.view.Gravity.TOP; inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE }
        val enabled = CheckBox(this).apply { text = "このスニペットを有効にする"; isChecked = existing?.enabled ?: true }
        val editorError = TextView(this).apply { setTextColor(Color.RED); visibility = View.GONE }
        val editor = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(40, 0, 40, 0); addView(trigger); addView(body); addView(TextView(this@SnippetImportActivity).apply { text = "改行はEnterで入力できます。" }); addView(enabled); addView(editorError) }
        val dialog = AlertDialog.Builder(this).setTitle("辞書を編集").setView(editor)
            .setNegativeButton("キャンセル", null)
            .setNeutralButton(if (existing == null) "" else "削除", null)
            .setPositiveButton("保存", null).create()
        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                editorError.visibility = View.GONE
                val updated = Snippet(existing?.id ?: UUID.randomUUID().toString(), trigger.text.toString(), body.text.toString(), enabled.isChecked, existing?.tags ?: emptyList())
                val next = snippets.toMutableList().apply { if (existing == null) add(updated) else set(indexOfFirst { it.id == existing.id }, updated) }
                runCatching { repository.save(next) }.onSuccess { showFile(it); dialog.dismiss() }.onFailure {
                    editorError.text = it.message ?: "保存できません。"
                    editorError.visibility = View.VISIBLE
                }
            }
            if (existing != null) dialog.getButton(AlertDialog.BUTTON_NEUTRAL).setOnClickListener {
                AlertDialog.Builder(this).setMessage("「${existing.trigger}」を削除しますか？").setNegativeButton("キャンセル", null).setPositiveButton("削除") { _, _ ->
                    runCatching { repository.save(snippets.filter { it.id != existing.id }) }
                        .onSuccess { showFile(it); dialog.dismiss() }
                        .onFailure {
                            editorError.text = it.message ?: "削除を保存できません。"
                            editorError.visibility = View.VISIBLE
                        }
                }.show()
            }
        }
        dialog.show()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        when (requestCode) {
            REQUEST_IMPORT -> runCatching { repository.importFrom(uri) }
                .onSuccess { showFile(it) }
                .onFailure { summary.text = it.message ?: "インポートできません。" }
            REQUEST_EXPORT -> runCatching { repository.exportTo(uri) }
                .onSuccess { summary.text = "snippets.json を書き出しました。" }
                .onFailure { summary.text = it.message ?: "書き出せません。" }
        }
    }
    private fun openJsonPicker() { startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type = "application/json" }, REQUEST_IMPORT) }
    private fun createJsonFile() {
        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, "snippets.json")
        }, REQUEST_EXPORT)
    }
    companion object {
        private const val REQUEST_IMPORT = 1001
        private const val REQUEST_EXPORT = 1002
    }
}
