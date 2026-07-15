package com.kaiasai.fukura

data class Snippet(
    val id: String,
    val trigger: String,
    val body: String,
    val enabled: Boolean = true,
    val tags: List<String> = emptyList()
)

data class SnippetFile(
    val version: Int,
    val updatedAt: String? = null,
    val snippets: List<Snippet>
)

class SnippetValidationException(message: String) : Exception(message)
