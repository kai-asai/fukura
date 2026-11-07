package com.kaiasai.fukura

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SnippetPresentationTest {
    @Test
    fun previewUsesTheSameNewlineMarkAsIos() {
        assertEquals("1行目 ↵ 2行目", SnippetPresentation.preview("1行目\n2行目"))
    }

    @Test
    fun bodyCaptionCountsCharactersAndLines() {
        assertEquals("本文: 0 / 8000文字・0行", SnippetPresentation.bodyCaption(""))
        assertEquals("本文: 4 / 8000文字・2行", SnippetPresentation.bodyCaption("あ\nいう"))
    }

    @Test
    fun statusMessageMatchesTheShippedListCopy() {
        val message = SnippetPresentation.statusMessage(3)
        assertTrue(message.contains("読み込み済み: 3 件"))
        assertFalse(message.contains("システム全体"))
    }
}
