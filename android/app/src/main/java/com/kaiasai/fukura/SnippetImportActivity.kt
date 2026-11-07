package com.kaiasai.fukura

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.LinearLayout
import android.widget.TextView
import java.util.UUID

class SnippetImportActivity : Activity() {
    private lateinit var repository: SnippetRepository
    private lateinit var statusMessage: TextView
    private lateinit var aboutCard: LinearLayout
    private lateinit var snippetList: LinearLayout
    private var snippets = mutableListOf<Snippet>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = SnippetRepository(this)
        setContentView(R.layout.activity_main)
        statusMessage = findViewById(R.id.status_message)
        aboutCard = findViewById(R.id.about_card)
        snippetList = findViewById(R.id.snippet_list)
        findViewById<View>(R.id.import_button).setOnClickListener { openJsonPicker() }
        findViewById<View>(R.id.add_button).setOnClickListener { openEditor(null) }
        buildAboutRows()
        reload()
    }

    override fun onResume() {
        super.onResume()
        reload()
    }

    private fun buildAboutRows() {
        aboutCard.removeAllViews()
        addLinkRow(getString(R.string.privacy_policy)) {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/kai-asai/fukura/blob/main/PRIVACY.md")))
        }
        addLinkRow(getString(R.string.enable_keyboard)) {
            startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
        }
        addLinkRow(getString(R.string.choose_input_method)) {
            (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager).showInputMethodPicker()
        }
        addLinkRow(getString(R.string.export_json)) { createJsonFile() }
    }

    private fun addLinkRow(title: String, action: () -> Unit) {
        if (aboutCard.childCount > 0) aboutCard.addView(divider())
        val row = layoutInflater.inflate(R.layout.item_link_row, aboutCard, false)
        row.findViewById<TextView>(R.id.row_title).text = title
        row.setOnClickListener { action() }
        aboutCard.addView(row)
    }

    private fun reload() {
        runCatching { repository.load() }
            .onSuccess { showFile(it) }
            .onFailure { showError(it.message ?: getString(R.string.cannot_operate)) }
    }

    private fun showFile(file: SnippetFile) {
        snippets = file.snippets.toMutableList()
        statusMessage.text = SnippetPresentation.statusMessage(snippets.size)
        snippetList.removeAllViews()
        if (snippets.isEmpty()) {
            val empty = TextView(this).apply {
                text = getString(R.string.candidate_empty_dictionary)
                setTextColor(getColor(R.color.label_secondary))
                textSize = 15f
                setPadding(dp(16), dp(16), dp(16), dp(16))
            }
            snippetList.addView(empty)
            return
        }
        snippets.forEachIndexed { index, snippet ->
            if (index > 0) snippetList.addView(divider())
            val row = layoutInflater.inflate(R.layout.item_snippet, snippetList, false)
            row.findViewById<TextView>(R.id.trigger).text = snippet.trigger
            row.findViewById<TextView>(R.id.stopped).visibility =
                if (snippet.enabled) View.GONE else View.VISIBLE
            row.findViewById<TextView>(R.id.body).text = SnippetPresentation.preview(snippet.body)
            row.setOnClickListener { openEditor(snippet) }
            row.setOnLongClickListener {
                confirmDelete(snippet)
                true
            }
            row.contentDescription = "${snippet.trigger}。${SnippetPresentation.preview(snippet.body)}"
            snippetList.addView(row)
        }
    }

    private fun confirmDelete(snippet: Snippet) {
        AlertDialog.Builder(this)
            .setTitle(R.string.delete_snippet)
            .setMessage(getString(R.string.delete_confirm, snippet.trigger))
            .setNegativeButton(R.string.cancel, null)
            .setPositiveButton(R.string.delete_snippet) { _, _ ->
                runCatching { repository.save(snippets.filter { it.id != snippet.id }) }
                    .onSuccess { showFile(it) }
                    .onFailure { showError(it.message ?: getString(R.string.cannot_operate)) }
            }
            .show()
    }

    private fun openEditor(existing: Snippet?) {
        val intent = Intent(this, SnippetEditorActivity::class.java)
        if (existing != null) {
            intent.putExtra(SnippetEditorActivity.EXTRA_ID, existing.id)
            intent.putExtra(SnippetEditorActivity.EXTRA_TRIGGER, existing.trigger)
            intent.putExtra(SnippetEditorActivity.EXTRA_BODY, existing.body)
            intent.putExtra(SnippetEditorActivity.EXTRA_ENABLED, existing.enabled)
            intent.putExtra(SnippetEditorActivity.EXTRA_TAGS, existing.tags.toTypedArray())
        }
        startActivity(intent)
    }

    private fun showError(message: String) {
        statusMessage.text = message
        AlertDialog.Builder(this)
            .setTitle(R.string.cannot_operate)
            .setMessage(message)
            .setPositiveButton(R.string.ok, null)
            .show()
    }

    private fun divider(): View = View(this).apply {
        setBackgroundColor(getColor(R.color.separator))
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1)).apply {
            marginStart = dp(16)
        }
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        when (requestCode) {
            REQUEST_IMPORT -> runCatching { repository.importFrom(uri) }
                .onSuccess { showFile(it) }
                .onFailure { showError(it.message ?: getString(R.string.cannot_operate)) }
            REQUEST_EXPORT -> runCatching { repository.exportTo(uri) }
                .onSuccess { statusMessage.text = getString(R.string.export_json) }
                .onFailure { showError(it.message ?: getString(R.string.cannot_operate)) }
        }
    }

    private fun openJsonPicker() {
        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
        }, REQUEST_IMPORT)
    }

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
