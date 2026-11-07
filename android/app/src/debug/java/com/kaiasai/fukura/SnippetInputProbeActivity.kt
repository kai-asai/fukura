package com.kaiasai.fukura

import android.app.Activity
import android.os.Bundle
import android.text.InputType
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.SearchView
import android.widget.TextView
import kotlin.math.max
import kotlin.math.min

/** Debug-only host for checking expansion in search and single-line fields. Not a launcher entry. */
class SnippetInputProbeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
        val search = SearchView(this).apply {
            id = SEARCH_ID
            queryHint = "search"
            isIconified = false
        }
        val single = EditText(this).apply {
            id = SINGLE_ID
            hint = "single"
            setSingleLine(true)
            inputType = InputType.TYPE_CLASS_TEXT
        }
        val multi = EditText(this).apply {
            id = MULTI_ID
            hint = "multi"
            minLines = 3
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
            addView(TextView(this@SnippetInputProbeActivity).apply { text = "probe" })
            addView(search)
            addView(single)
            addView(multi)
        }
        setContentView(root)

        val seed = intent?.getStringExtra("seed")
        val field = intent?.getStringExtra("field") ?: "multi"
        val selStart = intent?.getIntExtra("selStart", -1) ?: -1
        val selEnd = intent?.getIntExtra("selEnd", -1) ?: -1
        if (seed != null) {
            when (field) {
                "search" -> search.setQuery(seed, false)
                "single" -> single.setText(seed)
                else -> multi.setText(seed)
            }
        }
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        root.post {
            val target = when (field) {
                "search" -> search.findViewById<EditText>(resources.getIdentifier("search_src_text", "id", "android"))
                "single" -> single
                else -> multi
            }
            if (seed != null && selStart >= 0 && selEnd >= 0) {
                val endLimit = target.text?.length ?: 0
                val start = min(selStart, selEnd).coerceIn(0, endLimit)
                val end = max(selStart, selEnd).coerceIn(0, endLimit)
                target.setSelection(start, end)
            } else if (seed != null) {
                target.setSelection(target.text?.length ?: 0)
            }
            fun showIme(attempt: Int) {
                target.requestFocus()
                if (seed != null && selStart >= 0 && selEnd >= 0) {
                    val endLimit = target.text?.length ?: 0
                    target.setSelection(
                        min(selStart, selEnd).coerceIn(0, endLimit),
                        max(selStart, selEnd).coerceIn(0, endLimit)
                    )
                }
                val shown = imm.showSoftInput(target, InputMethodManager.SHOW_IMPLICIT)
                if (!shown && attempt < 6) target.postDelayed({ showIme(attempt + 1) }, 150)
            }
            showIme(0)
        }
    }

    companion object {
        const val SEARCH_ID = 0x5101
        const val SINGLE_ID = 0x5102
        const val MULTI_ID = 0x5103
    }
}
