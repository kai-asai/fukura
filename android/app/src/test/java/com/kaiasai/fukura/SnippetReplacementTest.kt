package com.kaiasai.fukura

import org.junit.Assert.assertEquals
import org.junit.Test

class SnippetReplacementTest {
    private val trigger = ";mail"
    private val body = "your.name@example.com"

    @Test
    fun replacesOnlyTheTriggerAfterAPrefix() {
        val action = SnippetReplacement.plan(
            SnippetReplacement.FieldState(textBeforeCursor = "xx$trigger", selectionStart = 8, selectionEnd = 8, fullText = "xx$trigger"),
            trigger,
            body
        )
        assertEquals(SnippetReplacement.Mode.DELETE_THEN_INSERT, action.mode)
        assertEquals(trigger.length, action.deleteBefore)
        assertEquals(body, action.insert)
    }

    @Test
    fun doesNotDeleteWhenTheCursorIsNotAfterTheTrigger() {
        val action = SnippetReplacement.plan(
            SnippetReplacement.FieldState(textBeforeCursor = "abc", selectionStart = 3, selectionEnd = 3, fullText = "abc$trigger"),
            trigger,
            body
        )
        assertEquals(SnippetReplacement.Mode.SKIP, action.mode)
        assertEquals(0, action.deleteBefore)
    }

    @Test
    fun doesNotDeleteANonEmptySelection() {
        val action = SnippetReplacement.plan(
            SnippetReplacement.FieldState(textBeforeCursor = trigger, selectionStart = 2, selectionEnd = 5, fullText = "abc$trigger"),
            trigger,
            body
        )
        assertEquals(SnippetReplacement.Mode.SKIP, action.mode)
    }

    @Test
    fun usesTheVisibleTextWhenTheCursorQueryIsUnavailable() {
        val full = "find $trigger"
        val action = SnippetReplacement.plan(
            SnippetReplacement.FieldState(textBeforeCursor = null, selectionStart = full.length, selectionEnd = full.length, fullText = full),
            trigger,
            body
        )
        assertEquals(SnippetReplacement.Mode.REPLACE_REGION, action.mode)
        assertEquals(full.length - trigger.length, action.regionStart)
        assertEquals(full.length, action.regionEnd)
        assertEquals(body, action.insert)
    }

    @Test
    fun skipsWhenTheFieldCannotBeRead() {
        val action = SnippetReplacement.plan(
            SnippetReplacement.FieldState(textBeforeCursor = null, fullText = null),
            trigger,
            body
        )
        assertEquals(SnippetReplacement.Mode.SKIP, action.mode)
    }

    @Test
    fun aSecondExpansionDoesNotSeeThePreviousBodyAsATrigger() {
        val action = SnippetReplacement.plan(
            SnippetReplacement.FieldState(textBeforeCursor = body, selectionStart = body.length, selectionEnd = body.length, fullText = body),
            trigger,
            body
        )
        assertEquals(SnippetReplacement.Mode.SKIP, action.mode)
    }

    @Test
    fun backspaceDropsOneCharacterFromTheMatchBuffer() {
        val matcher = SnippetMatcher(listOf(Snippet("mail", trigger, body)))
        matcher.push(trigger)
        assertEquals("mail", matcher.currentMatch()?.id)
        assertEquals(null, matcher.backspace()?.id)
        assertEquals("mail", matcher.push("l")?.id)
    }

    @Test
    fun bottomPaddingUsesTheLargerSystemInsetWithoutAddingThem() {
        assertEquals(48, SnippetReplacement.bottomPadding(navigationBarBottom = 48, gestureBottom = 24))
        assertEquals(64, SnippetReplacement.bottomPadding(navigationBarBottom = 20, gestureBottom = 64))
        assertEquals(0, SnippetReplacement.bottomPadding(0, 0))
    }
}
