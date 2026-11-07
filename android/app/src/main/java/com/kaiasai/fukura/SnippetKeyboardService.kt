package com.kaiasai.fukura

import android.content.Context
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.ExtractedTextRequest
import android.view.inputmethod.InputConnection
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
    private var ignoreSelectionUpdates = 0
    private lateinit var candidate: TextView
    private lateinit var rows: LinearLayout
    private val deleteHandler = Handler(Looper.getMainLooper())
    private var deleteHold = BackwardDelete.Hold()
    private var deleteGeneration = 0

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
        stopDeleteHold()
        clearMatch()
        super.onFinishInput()
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        stopDeleteHold()
        super.onFinishInputView(finishingInput)
    }

    override fun onWindowHidden() {
        stopDeleteHold()
        super.onWindowHidden()
    }

    override fun onDestroy() {
        stopDeleteHold()
        super.onDestroy()
    }

    override fun onUpdateSelection(
        oldSelStart: Int,
        oldSelEnd: Int,
        newSelStart: Int,
        newSelEnd: Int,
        candidatesStart: Int,
        candidatesEnd: Int
    ) {
        super.onUpdateSelection(oldSelStart, oldSelEnd, newSelStart, newSelEnd, candidatesStart, candidatesEnd)
        if (ignoreSelectionUpdates > 0) {
            ignoreSelectionUpdates--
            return
        }
        if (newSelStart != newSelEnd || pendingSnippet != null) {
            clearMatch()
        }
    }

    override fun onCreateInputView(): View {
        reloadSnippets()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(getColor(R.color.keyboard_background))
            setPadding(dp(4), dp(6), dp(4), dp(6))
        }
        applyBottomInset(root)

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
        row.addView(key(leadingLabel, 1.35f, KeyStyle.SPECIAL) { leadingAction() })
        characters.forEach { character ->
            val label = if (layout == Layout.LETTERS && isShifted) character.uppercase() else character
            row.addView(key(label) { typeCharacter(character) })
        }
        row.addView(
            key(
                trailingLabel,
                1.35f,
                KeyStyle.SPECIAL,
                repeatDelete = trailingLabel == "⌫",
                action = trailingAction
            )
        )
        rows.addView(row)
    }

    private fun addBottomRow(layoutLabel: String, layoutAction: () -> Unit) {
        val row = row()
        row.addView(key(layoutLabel, 1.25f, KeyStyle.SPECIAL) { layoutAction() })

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
        repeatDelete: Boolean = false,
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
        if (repeatDelete) {
            setOnTouchListener { view, event -> handleDeleteTouch(view, event) }
        } else {
            setOnClickListener { action() }
        }
        if (label == "🌐") contentDescription = getString(R.string.next_keyboard)
        if (label == ";") contentDescription = getString(R.string.snippet_mark)
    }

    private fun handleDeleteTouch(view: View, event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                view.isPressed = true
                startDeleteHold()
            }
            MotionEvent.ACTION_MOVE -> {
                val outside = event.x < 0 || event.y < 0 || event.x >= view.width || event.y >= view.height
                if (outside) stopDeleteHold()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                view.isPressed = false
                stopDeleteHold()
            }
        }
        return true
    }

    private fun startDeleteHold() {
        val generation = ++deleteGeneration
        deleteHold = BackwardDelete.hold(BackwardDelete.HoldSignal.DOWN)
        deleteBackward()
        deleteHandler.postDelayed({
            repeatDelete(generation)
        }, BackwardDelete.REPEAT_START_DELAY_MS)
    }

    private fun repeatDelete(generation: Int) {
        if (generation != deleteGeneration || !deleteHold.active) return
        deleteBackward()
        deleteHandler.postDelayed({ repeatDelete(generation) }, BackwardDelete.REPEAT_INTERVAL_MS)
    }

    private fun stopDeleteHold() {
        deleteGeneration++
        deleteHold = BackwardDelete.hold(BackwardDelete.HoldSignal.UP)
        deleteHandler.removeCallbacksAndMessages(null)
    }

    private fun typeCharacter(character: String) {
        reloadSnippets()
        val text = if (layout == Layout.LETTERS && isShifted) character.uppercase() else character
        edit { it.commitText(text, 1) }
        pendingSnippet = matcher.push(text)
        updateCandidate()
        if (layout == Layout.LETTERS && isShifted) {
            isShifted = false
            renderLayout()
        }
    }

    private fun deleteBackward() {
        reloadSnippets()
        val connection = currentInputConnection ?: return
        val before = connection.getTextBeforeCursor(64, 0)?.toString()
        val selected = connection.getSelectedText(0)?.toString()
        val extracted = connection.getExtractedText(extractedTextRequest(), 0)
        val action = BackwardDelete.plan(
            textBeforeCursor = before,
            selectedText = selected,
            selectionStart = extracted?.selectionStart ?: -1,
            selectionEnd = extracted?.selectionEnd ?: -1
        )
        if (action.mode == BackwardDelete.Mode.NONE) return
        ignoreSelectionUpdates++
        connection.beginBatchEdit()
        try {
            connection.finishComposingText()
            when (action.mode) {
                BackwardDelete.Mode.NONE -> Unit
                BackwardDelete.Mode.SURROUNDING -> connection.deleteSurroundingText(action.deleteBefore, 0)
                BackwardDelete.Mode.SELECTION -> {
                    val replaced = connection.commitText("", 1)
                    if (!replaced && action.selectionEnd > action.selectionStart) {
                        connection.setComposingRegion(action.selectionStart, action.selectionEnd)
                        connection.commitText("", 1)
                    }
                }
            }
        } finally {
            connection.endBatchEdit()
        }
        when (action.buffer) {
            BackwardDelete.BufferUpdate.UNCHANGED -> Unit
            BackwardDelete.BufferUpdate.DROP -> {
                pendingSnippet = matcher.backspace(action.deleteBefore)
                updateCandidate()
            }
            BackwardDelete.BufferUpdate.RESET -> clearMatch()
        }
    }

    private fun edit(block: (InputConnection) -> Unit) {
        val connection = currentInputConnection ?: return
        ignoreSelectionUpdates++
        connection.beginBatchEdit()
        try {
            block(connection)
        } finally {
            connection.endBatchEdit()
        }
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
        val connection = currentInputConnection ?: return
        ignoreSelectionUpdates++
        connection.beginBatchEdit()
        try {
            connection.finishComposingText()
            val before = connection.getTextBeforeCursor(snippet.trigger.length, 0)?.toString()
            val extracted = connection.getExtractedText(extractedTextRequest(), 0)
            val action = SnippetReplacement.plan(
                SnippetReplacement.FieldState(
                    textBeforeCursor = before,
                    selectionStart = extracted?.selectionStart ?: -1,
                    selectionEnd = extracted?.selectionEnd ?: -1,
                    fullText = extracted?.text?.toString()
                ),
                snippet.trigger,
                snippet.body
            )
            when (action.mode) {
                SnippetReplacement.Mode.DELETE_THEN_INSERT -> {
                    connection.deleteSurroundingText(action.deleteBefore, 0)
                    val stillThere = connection.getTextBeforeCursor(snippet.trigger.length, 0)
                        ?.toString()
                        ?.endsWith(snippet.trigger) == true
                    if (stillThere) {
                        val again = connection.getExtractedText(extractedTextRequest(), 0)
                        val fallback = SnippetReplacement.plan(
                            SnippetReplacement.FieldState(
                                textBeforeCursor = null,
                                selectionStart = again?.selectionStart ?: -1,
                                selectionEnd = again?.selectionEnd ?: -1,
                                fullText = again?.text?.toString()
                            ),
                            snippet.trigger,
                            snippet.body
                        )
                        if (fallback.mode == SnippetReplacement.Mode.REPLACE_REGION) {
                            connection.setComposingRegion(fallback.regionStart, fallback.regionEnd)
                            connection.commitText(fallback.insert, 1)
                        }
                    } else {
                        connection.commitText(snippet.body, 1)
                    }
                }
                SnippetReplacement.Mode.REPLACE_REGION -> {
                    connection.setComposingRegion(action.regionStart, action.regionEnd)
                    connection.commitText(action.insert, 1)
                }
                SnippetReplacement.Mode.SKIP -> Unit
            }
        } finally {
            connection.endBatchEdit()
        }
        clearMatch()
    }

    private fun extractedTextRequest() = ExtractedTextRequest().apply {
        hintMaxChars = 100_000
        hintMaxLines = 10_000
    }

    private fun applyBottomInset(view: View) {
        val footer = SnippetReplacement.reservedFooter(
            systemNavigationHeight(),
            dp(SnippetReplacement.FOOTER_BREATHING_DP)
        )
        view.setPadding(view.paddingLeft, view.paddingTop, view.paddingRight, dp(6) + footer)
    }

    private fun systemNavigationHeight(): Int {
        val id = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (id > 0) resources.getDimensionPixelSize(id) else 0
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
