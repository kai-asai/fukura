package com.kaiasai.fukura

import android.app.Activity
import android.os.Bundle
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.SearchView
import android.widget.TextView

/** Debug-only host for checking expansion in search and single-line fields. Not a launcher entry. */
class SnippetInputProbeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
    }

    companion object {
        const val SEARCH_ID = 0x5101
        const val SINGLE_ID = 0x5102
        const val MULTI_ID = 0x5103
    }
}
