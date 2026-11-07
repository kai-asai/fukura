package com.kaiasai.fukura

import android.content.Context
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File

class SnippetKeyboardService : InputMethodService() {
    private enum class Layout { LETTERS, NUMBERS, SYMBOLS }
    private enum class KeyStyle { NORMAL, SPECIAL, ACCENT }

    private var matcher = SnippetMatcher(emptyList())
    private var hasSnippets = false
    private var pendingSnippet: Snippet? = null
    private var dictionaryStamp = Long.MIN_VALUE
    private var layout = Layout.LETTERS
    private var isShifted = false
    private lateinit var candidate: TextView
    private lateinit var rows: LinearLayout

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        reloadSnippets()
        clearMatch()
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        reloadSnippets()
        clearMatch()
        renderLayout()
    }

    override fun onFinishInput() {
        clearMatch()
        super.onFinishInput()
    }

    override fun onCreateInputView(): View {
        reloadSnippets()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(getColor(R.color.keyboard_background))
            setPadding(dp(4), dp(6), dp(4), dp(6))
        }

        val candidateRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        candidateRow.addView(key(";", 0.7f, KeyStyle.SPECIAL) { typeCharacter(";") })
        candidate = TextView(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            textSize = 15f
            setPadding(dp(12), 0, dp(12), 0)
            setTextColor(getColor(R.color.link_blue))
            background = android.graphics.drawable.GradientDrawable().apply {
                cornerRadius = dp(7).toFloat()
                setColor(getColor(R.color.candidate_background))
            }
            setOnClickListener { expandPendingSnippet() }
            layoutParams = LinearLayout.LayoutParams(0, dp(36), 5f).apply {
                setMargins(dp(3), dp(3), dp(3), dp(3))
            }
        }
        candidateRow.addView(candidate)
        root.addView(candidateRow)

        rows = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(rows)
        renderLayout()
        updateCandidate()
        return root
    }

    private fun reloadSnippets() {
        val file = File(filesDir, "snippets.json")
        val stamp = if (file.exists()) file.lastModified() xor file.length() else 0L
        if (stamp == dictionaryStamp) return
        val snippets = runCatching { SnippetRepository(this).load().snippets }
            .getOrElse { emptyList() }
        dictionaryStamp = if (file.exists()) file.lastModified() xor file.length() else stamp
        matcher = SnippetMatcher(snippets)
        hasSnippets = snippets.any { it.enabled }
        pendingSnippet = null
    }

    private fun renderLayout() {
        if (!::rows.isInitialized) return
        rows.removeAllViews()
        when (layout) {
            Layout.LETTERS -> {
                addCharacterRow("qwertyuiop".map(Char::toString))
                addCharacterRow("asdfghjkl".map(Char::toString))
                addActionRow(
                    leadingLabel = if (isShifted) "⇧●" else "⇧",
                    characters = "zxcvbnm".map(Char::toString),
                    leadingAction = { toggleShift() },
                    trailingLabel = "⌫",
                    trailingAction = { deleteBackward() }
                )
                addBottomRow("123") { showNumbers() }
            }

            Layout.NUMBERS -> {
                addCharacterRow("1234567890".map(Char::toString))
                addCharacterRow(listOf("-", "/", ":", ";", "(", ")", "¥", "&", "@", "\""))
                addActionRow(
                    leadingLabel = "#+=",
                    characters = listOf(".", ",", "?", "!", "'"),
                    leadingAction = { showSymbols() },
                    trailingLabel = "⌫",
                    trailingAction = { deleteBackward() }
                )
                addBottomRow("ABC") { showLetters() }
            }

            Layout.SYMBOLS -> {
                addCharacterRow(listOf("[", "]", "{", "}", "#", "%", "^", "*", "+", "="))
                addCharacterRow(listOf("_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"))
                addActionRow(
                    leadingLabel = "123",
                    characters = listOf(".", ",", "?", "!", "'"),
                    leadingAction = { showNumbers() },
                    trailingLabel = "⌫",
                    trailingAction = { deleteBackward() }
                )
                addBottomRow("ABC") { showLetters() }
            }
        }
    }

    private fun addCharacterRow(characters: List<String>) {
        val row = row()
        characters.forEach { character ->
            val label = if (layout == Layout.LETTERS && isShifted) character.uppercase() else character
            row.addView(key(label) { typeCharacter(character) })
        }
        rows.addView(row)
    }

    private fun addActionRow(
        leadingLabel: String,
        characters: List<String>,
        leadingAction: () -> Unit,
        trailingLabel: String,
        trailingAction: () -> Unit
    ) {
        val row = row()
        row.addView(key(leadingLabel, 1.35f, KeyStyle.SPECIAL, leadingAction))
        characters.forEach { character ->
            val label = if (layout == Layout.LETTERS && isShifted) character.uppercase() else character
            row.addView(key(label) { typeCharacter(character) })
        }
        row.addView(key(trailingLabel, 1.35f, KeyStyle.SPECIAL, trailingAction))
        rows.addView(row)
    }

    private fun addBottomRow(layoutLabel: String, layoutAction: () -> Unit) {
        val row = row()
        row.addView(key(layoutLabel, 1.25f, KeyStyle.SPECIAL, layoutAction))

        val canSwitch = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            shouldOfferSwitchingToNextInputMethod()
        } else {
            true
        }
        if (canSwitch) {
            row.addView(key("🌐", 1f, KeyStyle.SPECIAL) { switchInputMethod() })
        }
        row.addView(key(getString(R.string.space_key), 3.4f) { insertSpace() })
        row.addView(key(getString(R.string.return_key), 1.45f, KeyStyle.ACCENT) { insertReturn() })
        rows.addView(row)
    }

    private fun row() = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }

    private fun key(
        label: String,
        weight: Float = 1f,
        style: KeyStyle = KeyStyle.NORMAL,
        action: () -> Unit
    ) = TextView(this).apply {
        text = label
        textSize = if (label.length > 1) 15f else 20f
        gravity = Gravity.CENTER
        setTextColor(getColor(R.color.label_primary))
        includeFontPadding = false
        setPadding(0, 0, 0, 0)
        val fill = android.graphics.drawable.GradientDrawable().apply {
            cornerRadius = dp(6).toFloat()
            setColor(when (style) {
                KeyStyle.NORMAL -> getColor(R.color.key_normal)
                KeyStyle.SPECIAL -> getColor(R.color.key_special)
                KeyStyle.ACCENT -> getColor(R.color.key_accent)
            })
        }
        if (label == "⌫") {
            text = ""
            val icon = android.graphics.drawable.LayerDrawable(arrayOf(fill, getDrawable(R.drawable.ic_delete_key)))
            val inset = dp(10)
            icon.setLayerInset(1, inset, inset, inset, inset)
            background = icon
        } else {
            background = fill
        }
        layoutParams = LinearLayout.LayoutParams(0, dp(42), weight).apply {
            setMargins(dp(3), dp(4), dp(3), dp(4))
        }
        setOnClickListener { action() }
        if (label == "🌐") contentDescription = getString(R.string.next_keyboard)
        if (label == ";") contentDescription = getString(R.string.snippet_mark)
    }

    private fun typeCharacter(character: String) {
        reloadSnippets()
        val text = if (layout == Layout.LETTERS && isShifted) character.uppercase() else character
        currentInputConnection?.commitText(text, 1)
        pendingSnippet = matcher.push(text)
        updateCandidate()
        if (layout == Layout.LETTERS && isShifted) {
            isShifted = false
            renderLayout()
        }
    }

    private fun deleteBackward() {
        reloadSnippets()
        sendKey(KeyEvent.KEYCODE_DEL)
        pendingSnippet = matcher.backspace()
        updateCandidate()
    }

    private fun sendKey(keyCode: Int) {
        currentInputConnection?.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        currentInputConnection?.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
    }

    private fun insertSpace() {
        currentInputConnection?.commitText(" ", 1)
        clearMatch()
    }

    private fun insertReturn() {
        currentInputConnection?.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER))
        currentInputConnection?.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_ENTER))
        clearMatch()
    }

    private fun switchInputMethod() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            if (shouldOfferSwitchingToNextInputMethod()) {
                switchToNextInputMethod(false)
            }
            return
        }

        val token = window.window?.decorView?.windowToken ?: return
        (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
            .switchToNextInputMethod(token, false)
    }

    private fun toggleShift() {
        isShifted = !isShifted
        renderLayout()
    }

    private fun showLetters() {
        layout = Layout.LETTERS
        isShifted = false
        renderLayout()
    }

    private fun showNumbers() {
        layout = Layout.NUMBERS
        renderLayout()
    }

    private fun showSymbols() {
        layout = Layout.SYMBOLS
        renderLayout()
    }

    private fun clearMatch() {
        matcher.reset()
        pendingSnippet = null
        updateCandidate()
    }

    private fun updateCandidate() {
        if (!::candidate.isInitialized) return
        val snippet = pendingSnippet
        candidate.text = when {
            snippet != null -> "展開: ${snippet.body}"
            !hasSnippets -> getString(R.string.candidate_empty_dictionary)
            else -> getString(R.string.candidate_none)
        }
        candidate.setTextColor(getColor(if (snippet != null) R.color.link_blue else R.color.label_secondary))
        candidate.isEnabled = snippet != null
    }

    private fun expandPendingSnippet() {
        val snippet = pendingSnippet ?: return
        repeat(snippet.trigger.length) { sendKey(KeyEvent.KEYCODE_DEL) }
        currentInputConnection?.commitText(snippet.body, 1)
        clearMatch()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
