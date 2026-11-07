package com.kaiasai.fukura

/**
 * One backspace, independent of which editor is focused.
 * A selection is removed as a range. A caret deletes one grapheme before it.
 * Hold-to-repeat is a separate signal so release, cancel, and hide all stop it.
 */
internal object BackwardDelete {
    const val REPEAT_START_DELAY_MS = 400L
    const val REPEAT_INTERVAL_MS = 50L

    enum class Mode { NONE, SURROUNDING, SELECTION }
    enum class BufferUpdate { UNCHANGED, DROP, RESET }
    enum class HoldSignal { DOWN, UP, CANCEL, MOVE_OUTSIDE, HIDE }

    data class Hold(val active: Boolean = false)

    fun hold(signal: HoldSignal): Hold = when (signal) {
        HoldSignal.DOWN -> Hold(active = true)
        HoldSignal.UP, HoldSignal.CANCEL, HoldSignal.MOVE_OUTSIDE, HoldSignal.HIDE -> Hold(active = false)
    }

    data class Action(
        val mode: Mode,
        val deleteBefore: Int = 0,
        val selectionStart: Int = -1,
        val selectionEnd: Int = -1,
        val buffer: BufferUpdate = BufferUpdate.UNCHANGED
    )

    fun plan(
        textBeforeCursor: String?,
        selectedText: String?,
        selectionStart: Int,
        selectionEnd: Int
    ): Action {
        val indexedSelection = selectionStart >= 0 && selectionEnd >= 0 && selectionStart != selectionEnd
        if (indexedSelection || !selectedText.isNullOrEmpty()) {
            val start = if (selectionStart >= 0 && selectionEnd >= 0) minOf(selectionStart, selectionEnd) else -1
            val end = if (selectionStart >= 0 && selectionEnd >= 0) maxOf(selectionStart, selectionEnd) else -1
            return Action(
                mode = Mode.SELECTION,
                selectionStart = start,
                selectionEnd = end,
                buffer = BufferUpdate.RESET
            )
        }
        if (textBeforeCursor == null) {
            return Action(Mode.SURROUNDING, deleteBefore = 1, buffer = BufferUpdate.DROP)
        }
        val units = trailingGraphemeLength(textBeforeCursor)
        if (units <= 0) return Action(Mode.NONE)
        return Action(Mode.SURROUNDING, deleteBefore = units, buffer = BufferUpdate.DROP)
    }

    fun trailingGraphemeLength(text: String): Int {
        if (text.isEmpty()) return 0
        if (text.endsWith("\r\n")) return 2
        var index = text.length

        fun readPrevious(): Int {
            if (index <= 0) return -1
            index--
            if (index > 0 && Character.isLowSurrogate(text[index]) && Character.isHighSurrogate(text[index - 1])) {
                index--
            }
            return Character.codePointAt(text, index)
        }

        fun peekPrevious(): Int {
            if (index <= 0) return -1
            var probe = index - 1
            if (probe > 0 && Character.isLowSurrogate(text[probe]) && Character.isHighSurrogate(text[probe - 1])) {
                probe--
            }
            return Character.codePointAt(text, probe)
        }

        val last = readPrevious()
        if (last < 0) return 0
        if (isRegionalIndicator(last)) {
            var run = 1
            while (isRegionalIndicator(peekPrevious())) {
                readPrevious()
                run++
            }
            val take = if (run % 2 == 0) 2 else 1
            index = text.length
            repeat(take) { readPrevious() }
            return text.length - index
        }

        var consumedBase = !isExtender(last)
        while (index > 0) {
            val previous = peekPrevious()
            if (previous < 0) break
            if (previous == ZWJ) {
                readPrevious()
                if (peekPrevious() >= 0) {
                    readPrevious()
                    while (isExtender(peekPrevious())) readPrevious()
                }
                consumedBase = true
                continue
            }
            // A mark belongs to the base before it, not to the character after it.
            if (!consumedBase) {
                readPrevious()
                if (!isExtender(previous)) consumedBase = true
                continue
            }
            break
        }
        return text.length - index
    }

    private const val ZWJ = 0x200D

    private fun isRegionalIndicator(codePoint: Int) = codePoint in 0x1F1E6..0x1F1FF

    private fun isExtender(codePoint: Int): Boolean {
        if (codePoint in 0xFE00..0xFE0F) return true
        if (codePoint in 0xE0100..0xE01EF) return true
        if (codePoint in 0x1F3FB..0x1F3FF) return true
        if (codePoint in 0xE0020..0xE007F) return true
        return when (Character.getType(codePoint)) {
            Character.NON_SPACING_MARK.toInt(),
            Character.ENCLOSING_MARK.toInt(),
            Character.COMBINING_SPACING_MARK.toInt() -> true
            else -> false
        }
    }
}
