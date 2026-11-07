package com.kaiasai.fukura

/**
 * Decides how to replace a trigger that sits immediately before the cursor.
 * Search fields often ignore a burst of delete key events, so the plan is a
 * single delete or a composing-region replace, and it refuses to touch a
 * selection or text that does not end with the trigger.
 */
internal object SnippetReplacement {
    enum class Mode { DELETE_THEN_INSERT, REPLACE_REGION, SKIP }

    data class FieldState(
        val textBeforeCursor: String?,
        val selectionStart: Int = -1,
        val selectionEnd: Int = -1,
        val fullText: String? = null
    )

    data class Action(
        val mode: Mode,
        val deleteBefore: Int = 0,
        val regionStart: Int = -1,
        val regionEnd: Int = -1,
        val insert: String = ""
    )

    fun plan(state: FieldState, trigger: String, body: String): Action {
        if (trigger.isEmpty() || body.isEmpty()) return Action(Mode.SKIP)
        val collapsed = state.selectionStart < 0 || state.selectionStart == state.selectionEnd
        if (!collapsed) return Action(Mode.SKIP)

        val before = state.textBeforeCursor
        if (before != null) {
            if (before != trigger && !before.endsWith(trigger)) return Action(Mode.SKIP)
            return Action(Mode.DELETE_THEN_INSERT, deleteBefore = trigger.length, insert = body)
        }

        val text = state.fullText ?: return Action(Mode.SKIP)
        val cursor = state.selectionStart
        if (cursor < trigger.length || cursor > text.length) return Action(Mode.SKIP)
        if (text.substring(cursor - trigger.length, cursor) != trigger) return Action(Mode.SKIP)
        return Action(
            Mode.REPLACE_REGION,
            regionStart = cursor - trigger.length,
            regionEnd = cursor,
            insert = body
        )
    }

    fun bottomPadding(navigationBarBottom: Int, gestureBottom: Int): Int =
        maxOf(navigationBarBottom, gestureBottom, 0)
}
