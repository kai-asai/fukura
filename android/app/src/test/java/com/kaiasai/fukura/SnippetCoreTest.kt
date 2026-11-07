package com.kaiasai.fukura

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class SnippetCoreTest {
    @Test
    fun exampleDictionarySkipsDisabledSnippet() {
        val file = SnippetParser.parse(SnippetRepository.defaultJson)
        assertEquals(1, file.version)
        assertTrue(file.snippets.any { it.trigger == ";mail" && it.enabled })
        assertFalse(file.snippets.first { it.trigger == ";addr" }.enabled)
    }

    @Test
    fun omittedEnabledDefaultsToTrue() {
        val file = SnippetParser.parse(
            """{"version":1,"snippets":[{"id":"mail","trigger":";mail","body":"a@example.com"}]}"""
        )
        assertTrue(file.snippets.single().enabled)
    }

    @Test
    fun invalidFilesAreRejected() {
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse("{ broken")
        }
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse("""{"version":2,"snippets":[]}""")
        }
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse("""{"version":1,"snippets":[{"id":"x","trigger":";x"}]}""")
        }
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse(
                """{"version":1,"snippets":[{"id":"a","trigger":";x","body":"A"},{"id":"b","trigger":";x","body":"B"}]}"""
            )
        }
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse(
                """{"version":1,"snippets":[{"id":"a","trigger":";x","body":"A","enabled":"yes"}]}"""
            )
        }
    }

    @Test
    fun limitsAreEnforced() {
        val tooMany = (0 until 501).joinToString(",") { index ->
            """{"id":"s$index","trigger":";s$index","body":"body"}"""
        }
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse("""{"version":1,"snippets":[$tooMany]}""")
        }
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse(
                """{"version":1,"snippets":[{"id":"long","trigger":";${"x".repeat(64)}","body":"body"}]}"""
            )
        }
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse(
                """{"version":1,"snippets":[{"id":"body","trigger":";body","body":"${"x".repeat(8001)}"}]}"""
            )
        }
        assertThrows(SnippetValidationException::class.java) {
            SnippetParser.parse("x".repeat(SnippetParser.MAX_JSON_BYTES + 1))
        }
    }

    @Test
    fun longerTriggerWinsAndBackspaceKeepsTheRest() {
        val matcher = SnippetMatcher(
            listOf(
                Snippet("short", ";t", "short"),
                Snippet("long", ";today", "long"),
                Snippet("address", ";addr", "hidden", enabled = false)
            )
        )
        assertEquals("short", matcher.push(";t")?.id)
        assertEquals("long", matcher.push("oday")?.id)
        assertNull(matcher.backspace())
        assertEquals("long", matcher.push("y")?.id)
        assertNull(matcher.push(" "))
        matcher.reset()
        assertNull(matcher.push(";addr"))
    }

    @Test
    fun backspaceRemovesOnlyTheLastTypedCharacter() {
        val matcher = SnippetMatcher(listOf(Snippet("mail", ";mail", "a@example.com")))
        assertNull(matcher.push(";mai"))
        assertNull(matcher.backspace())
        assertNull(matcher.push("i"))
        assertEquals("mail", matcher.push("l")?.id)
    }

    @Test
    fun emptyDictionaryDoesNotMatch() {
        val matcher = SnippetMatcher(emptyList())
        assertNull(matcher.push(";mail"))
        assertNull(matcher.backspace())
    }

    @Test
    fun repositorySaveImportAndBackupStayLocal() {
        val directory = File.createTempFile("fukura", "dir").apply {
            delete()
            mkdirs()
        }
        try {
            val repository = SnippetRepository(directory)
            val created = repository.load()
            assertTrue(created.snippets.any { it.trigger == ";mail" })
            val original = File(directory, "snippets.json").readText()

            assertThrows(SnippetValidationException::class.java) {
                repository.importText("{ broken")
            }
            assertEquals(original, File(directory, "snippets.json").readText())
            assertFalse(File(directory, "snippets.backup.json").exists())

            val saved = repository.save(
                listOf(Snippet("lines", ";lines", "1行目\n2行目", tags = listOf("note")))
            )
            assertEquals("1行目\n2行目", saved.snippets.single().body)
            assertEquals(listOf("note"), saved.snippets.single().tags)
            assertTrue(File(directory, "snippets.backup.json").readText().contains(";mail"))
            assertFalse(File(directory, "snippets.backup.json").readText().contains(";lines"))

            val imported = repository.importText(
                """{"version":1,"snippets":[{"id":"mail","trigger":";mail","body":"a@example.com"}]}"""
            )
            assertEquals(";mail", imported.snippets.single().trigger)
            assertTrue(repository.exportText().contains(";mail"))
        } finally {
            directory.deleteRecursively()
        }
    }
}
