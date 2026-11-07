package com.kaiasai.fukura

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BackwardDeleteTest {
    @Test
    fun singleTapDeletesOneCharacter() {
        val action = BackwardDelete.plan("hello", selectedText = null, selectionStart = 5, selectionEnd = 5)
        assertEquals(BackwardDelete.Mode.SURROUNDING, action.mode)
        assertEquals(1, action.deleteBefore)
        assertEquals(BackwardDelete.BufferUpdate.DROP, action.buffer)
    }

    @Test
    fun emptyFieldDeletesNothing() {
        val action = BackwardDelete.plan("", selectedText = null, selectionStart = 0, selectionEnd = 0)
        assertEquals(BackwardDelete.Mode.NONE, action.mode)
        assertEquals(BackwardDelete.BufferUpdate.UNCHANGED, action.buffer)
    }

    @Test
    fun deletesASelectedRangeAndKeepsThePlanInsideThatRange() {
        val action = BackwardDelete.plan(
            textBeforeCursor = "ab",
            selectedText = "HELLO",
            selectionStart = 3,
            selectionEnd = 8
        )
        assertEquals(BackwardDelete.Mode.SELECTION, action.mode)
        assertEquals(3, action.selectionStart)
        assertEquals(8, action.selectionEnd)
        assertEquals(BackwardDelete.BufferUpdate.RESET, action.buffer)
    }

    @Test
    fun reversedSelectionIsNormalized() {
        val action = BackwardDelete.plan(
            textBeforeCursor = "ab",
            selectedText = "HELLO",
            selectionStart = 8,
            selectionEnd = 3
        )
        assertEquals(BackwardDelete.Mode.SELECTION, action.mode)
        assertEquals(3, action.selectionStart)
        assertEquals(8, action.selectionEnd)
    }

    @Test
    fun selectedTextWithoutIndicesStillDeletesTheSelection() {
        val action = BackwardDelete.plan("ab", selectedText = "HELLO", selectionStart = -1, selectionEnd = -1)
        assertEquals(BackwardDelete.Mode.SELECTION, action.mode)
        assertEquals(BackwardDelete.BufferUpdate.RESET, action.buffer)
    }

    @Test
    fun deletesOneEmojiAndOneCombiningCharacter() {
        assertEquals(2, BackwardDelete.trailingGraphemeLength("hi\uD83D\uDC4D"))
        assertEquals(2, BackwardDelete.trailingGraphemeLength("e\u0301"))
        assertEquals(1, BackwardDelete.trailingGraphemeLength("e\u0301x"))
        assertEquals(1, BackwardDelete.trailingGraphemeLength("あ"))
        val emoji = BackwardDelete.plan("hi\uD83D\uDC4D", null, 4, 4)
        assertEquals(2, emoji.deleteBefore)
    }

    @Test
    fun deletesAFamilyEmojiAFlagAndAKeycapAsOneCluster() {
        val family = "\uD83D\uDC68\u200D\uD83D\uDC69\u200D\uD83D\uDC67\u200D\uD83D\uDC66"
        assertEquals(family.length, BackwardDelete.trailingGraphemeLength("x$family"))
        assertEquals(4, BackwardDelete.trailingGraphemeLength("\uD83C\uDDEF\uD83C\uDDF5"))
        assertEquals(2, BackwardDelete.trailingGraphemeLength("\uD83C\uDDEF\uD83C\uDDF5\uD83C\uDDEF"))
        assertEquals(4, BackwardDelete.trailingGraphemeLength("\uD83C\uDDEF\uD83C\uDDF5\uD83C\uDDEF\uD83C\uDDF5"))
        assertEquals(4, BackwardDelete.trailingGraphemeLength("\uD83D\uDC4B\uD83C\uDFFB"))
        assertEquals(3, BackwardDelete.trailingGraphemeLength("1\uFE0F\u20E3"))
    }

    @Test
    fun holdStopsOnReleaseCancelLeaveAndHide() {
        assertEquals(true, BackwardDelete.hold(BackwardDelete.HoldSignal.DOWN).active)
        for (signal in listOf(
            BackwardDelete.HoldSignal.UP,
            BackwardDelete.HoldSignal.CANCEL,
            BackwardDelete.HoldSignal.MOVE_OUTSIDE,
            BackwardDelete.HoldSignal.HIDE
        )) {
            assertEquals(false, BackwardDelete.hold(signal).active)
        }
        assertEquals(400L, BackwardDelete.REPEAT_START_DELAY_MS)
        assertEquals(50L, BackwardDelete.REPEAT_INTERVAL_MS)
    }

    @Test
    fun deletingOneGraphemeRestoresTheSnippetCandidate() {
        val matcher = SnippetMatcher(
            listOf(
                Snippet("hi", "hi", "there"),
                Snippet("pad", "x".repeat(20), "z")
            )
        )
        assertEquals("hi", matcher.push("hi")?.id)
        matcher.push("\uD83D\uDC4D")
        assertNull(matcher.currentMatch())
        assertEquals("hi", matcher.backspace(2)?.id)
    }

    @Test
    fun unreadableFieldFallsBackToOneCodeUnit() {
        val action = BackwardDelete.plan(null, null, -1, -1)
        assertEquals(BackwardDelete.Mode.SURROUNDING, action.mode)
        assertEquals(1, action.deleteBefore)
    }
}
