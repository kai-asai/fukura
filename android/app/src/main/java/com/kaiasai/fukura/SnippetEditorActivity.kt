package com.kaiasai.fukura

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.widget.EditText
import android.widget.Switch
import android.widget.TextView
import java.util.UUID

class SnippetEditorActivity : Activity() {
    private lateinit var repository: SnippetRepository
    private lateinit var triggerField: EditText
    private lateinit var bodyField: EditText
    private lateinit var caption: TextView
    private lateinit var enabledSwitch: Switch
    private lateinit var saveButton: TextView
    private lateinit var errorView: TextView
    private var snippetId: String = ""
    private var tags: List<String> = emptyList()
    private var isNew = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = SnippetRepository(this)
        setContentView(R.layout.activity_editor)
        triggerField = findViewById(R.id.trigger_field)
        bodyField = findViewById(R.id.body_field)
        caption = findViewById(R.id.body_caption)
        enabledSwitch = findViewById(R.id.enabled_switch)
        saveButton = findViewById(R.id.save_button)
        errorView = findViewById(R.id.editor_error)
        snippetId = intent.getStringExtra(EXTRA_ID) ?: UUID.randomUUID().toString()
        isNew = !intent.hasExtra(EXTRA_ID)
        triggerField.setText(intent.getStringExtra(EXTRA_TRIGGER) ?: ";new")
        bodyField.setText(intent.getStringExtra(EXTRA_BODY) ?: "")
        enabledSwitch.isChecked = if (intent.hasExtra(EXTRA_ENABLED)) intent.getBooleanExtra(EXTRA_ENABLED, true) else true
        tags = intent.getStringArrayExtra(EXTRA_TAGS)?.toList() ?: emptyList()
        tintSwitch()
        val watcher = object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) = refreshForm()
        }
        triggerField.addTextChangedListener(watcher)
        bodyField.addTextChangedListener(watcher)
        findViewById<TextView>(R.id.cancel_button).setOnClickListener { finish() }
        saveButton.setOnClickListener { save() }
        refreshForm()
    }

    private fun tintSwitch() {
        enabledSwitch.thumbTintList = android.content.res.ColorStateList(
            arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
            intArrayOf(Color.WHITE, Color.parseColor("#F4F4F5"))
        )
        enabledSwitch.trackTintList = android.content.res.ColorStateList(
            arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
            intArrayOf(getColor(R.color.switch_on), Color.parseColor("#E9E9EA"))
        )
    }

    private fun refreshForm() {
        caption.text = getString(R.string.body_hint) + "\n" + SnippetPresentation.bodyCaption(bodyField.text.toString())
        val ready = triggerField.text.isNotBlank() && bodyField.text.isNotEmpty()
        saveButton.isEnabled = ready
        saveButton.setTextColor(getColor(if (ready) R.color.link_blue else R.color.label_secondary))
    }

    private fun save() {
        if (!saveButton.isEnabled) return
        val updated = Snippet(
            id = snippetId,
            trigger = triggerField.text.toString(),
            body = bodyField.text.toString(),
            enabled = enabledSwitch.isChecked,
            tags = tags
        )
        val current = runCatching { repository.load().snippets }.getOrElse {
            showFailure(it.message)
            return
        }.toMutableList()
        if (isNew) current.add(updated) else {
            val index = current.indexOfFirst { it.id == snippetId }
            if (index >= 0) current[index] = updated else current.add(updated)
        }
        runCatching { repository.save(current) }
            .onSuccess { finish() }
            .onFailure { showFailure(it.message) }
    }

    private fun showFailure(message: String?) {
        errorView.visibility = android.view.View.VISIBLE
        errorView.text = message ?: getString(R.string.cannot_operate)
    }

    companion object {
        const val EXTRA_ID = "id"
        const val EXTRA_TRIGGER = "trigger"
        const val EXTRA_BODY = "body"
        const val EXTRA_ENABLED = "enabled"
        const val EXTRA_TAGS = "tags"
    }
}
