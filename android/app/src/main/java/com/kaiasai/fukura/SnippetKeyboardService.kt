package com.kaiasai.fukura

import android.content.Context
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class SnippetKeyboardService : InputMethodService() {
    private enum class Layout { LETTERS, NUMBERS, SYMBOLS }

    private var matcher = SnippetMatcher(emptyList())
    private var hasSnippets = false
    private var pendingSnippet: Snippet? = null
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
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }

        val candidateRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        candidateRow.addView(key(";", 0.8f) { typeCharacter(";") })
        candidate = TextView(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            textSize = 14f
            setPadding(dp(12), 0, dp(12), 0)
            setBackgroundColor(0x1A808080)
            setOnClickListener { expandPendingSnippet() }
            layoutParams = LinearLayout.LayoutParams(0, dp(42), 5f).apply {
                setMargins(dp(2), dp(2), dp(2), dp(2))
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
        val snippets = runCatching { SnippetRepository(this).load().snippets }
            .getOrElse { emptyList() }
        matcher = SnippetMatcher(snippets)
        hasSnippets = snippets.any { it.enabled }
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
        row.addView(key(leadingLabel, 1.3f, leadingAction))
        characters.forEach { character ->
            val label = if (layout == Layout.LETTERS && isShifted) character.uppercase() else character
            row.addView(key(label) { typeCharacter(character) })
        }
        row.addView(key(trailingLabel, 1.3f, trailingAction))
        rows.addView(row)
    }

    private fun addBottomRow(layoutLabel: String, layoutAction: () -> Unit) {
        val row = row()
        row.addView(key(layoutLabel, 1.2f, layoutAction))

        val canSwitch = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            shouldOfferSwitchingToNextInputMethod()
        } else {
            true
        }
        if (canSwitch) {
            row.addView(key("🌐", 1f) { switchInputMethod() })
        }
        row.addView(key("空白", 3.2f) { insertSpace() })
        row.addView(key("改行", 1.5f) { insertReturn() })
        rows.addView(row)
    }

    private fun row() = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }

    private fun key(label: String, weight: Float = 1f, action: () -> Unit) = Button(this).apply {
        text = label
        textSize = if (label.length > 2) 13f else 18f
        minWidth = 0
        minimumWidth = 0
        setPadding(0, 0, 0, 0)
        layoutParams = LinearLayout.LayoutParams(0, dp(46), weight).apply {
            setMargins(dp(2), dp(2), dp(2), dp(2))
        }
        setOnClickListener { action() }
    }

    private fun typeCharacter(character: String) {
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
        currentInputConnection?.deleteSurroundingText(1, 0)
        clearMatch()
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
            !hasSnippets -> "辞書をfukura本体で設定してください"
            else -> "候補なし"
        }
        candidate.isEnabled = snippet != null
    }

    private fun expandPendingSnippet() {
        val snippet = pendingSnippet ?: return
        currentInputConnection?.deleteSurroundingText(snippet.trigger.length, 0)
        currentInputConnection?.commitText(snippet.body, 1)
        clearMatch()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
