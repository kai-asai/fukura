export class SnippetValidationError extends Error {
  constructor(message, issues = []) {
    super(message);
    this.name = "SnippetValidationError";
    this.issues = issues;
  }
}

export const SNIPPET_LIMITS = Object.freeze({
  maxJsonBytes: 512 * 1024,
  maxSnippets: 500,
  maxTriggerLength: 64,
  maxBodyLength: 8000,
});

export function parseSnippetJson(jsonText) {
  if (new TextEncoder().encode(jsonText).length > SNIPPET_LIMITS.maxJsonBytes) {
    throw new SnippetValidationError("snippets.json の形式が不正です", [
      `snippets.json は ${SNIPPET_LIMITS.maxJsonBytes} bytes 以下にしてください`,
    ]);
  }

  try {
    return JSON.parse(jsonText);
  } catch (error) {
    throw new SnippetValidationError("snippets.json のJSONが不正です", [
      `JSON parse error: ${error.message}`,
    ]);
  }
}

export function normalizeSnippetFile(input) {
  const issues = [];

  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new SnippetValidationError("snippets.json はオブジェクトである必要があります", [
      "root must be an object",
    ]);
  }

  if (input.version !== 1) {
    issues.push("version は 1 のみ対応しています");
  }

  if (!Array.isArray(input.snippets)) {
    issues.push("snippets は配列である必要があります");
  } else if (input.snippets.length > SNIPPET_LIMITS.maxSnippets) {
    issues.push(`snippets は ${SNIPPET_LIMITS.maxSnippets} 件以下にしてください`);
  }

  if (issues.length > 0) {
    throw new SnippetValidationError("snippets.json の形式が不正です", issues);
  }

  const seenTriggers = new Map();
  const snippets = input.snippets.map((snippet, index) => {
    const prefix = `snippets[${index}]`;

    if (!snippet || typeof snippet !== "object" || Array.isArray(snippet)) {
      issues.push(`${prefix} はオブジェクトである必要があります`);
      return null;
    }

    const normalized = {
      id: readRequiredString(snippet.id, `${prefix}.id`, issues),
      trigger: readRequiredString(snippet.trigger, `${prefix}.trigger`, issues),
      body: readRequiredString(snippet.body, `${prefix}.body`, issues),
      enabled: snippet.enabled === undefined ? true : snippet.enabled,
      tags: Array.isArray(snippet.tags) ? snippet.tags.filter((tag) => typeof tag === "string") : undefined,
      updated_at: typeof snippet.updated_at === "string" ? snippet.updated_at : undefined,
    };

    if (snippet.enabled !== undefined && typeof snippet.enabled !== "boolean") {
      issues.push(`${prefix}.enabled は boolean である必要があります`);
    }

    if (normalized.trigger) {
      if (normalized.trigger.length > SNIPPET_LIMITS.maxTriggerLength) {
        issues.push(`${prefix}.trigger は ${SNIPPET_LIMITS.maxTriggerLength} 文字以下にしてください`);
      }
      const previous = seenTriggers.get(normalized.trigger);
      if (previous !== undefined) {
        issues.push(`${prefix}.trigger が snippets[${previous}].trigger と重複しています: ${normalized.trigger}`);
      } else {
        seenTriggers.set(normalized.trigger, index);
      }
    }
    if (normalized.body && normalized.body.length > SNIPPET_LIMITS.maxBodyLength) {
      issues.push(`${prefix}.body は ${SNIPPET_LIMITS.maxBodyLength} 文字以下にしてください`);
    }

    return normalized;
  });

  if (issues.length > 0) {
    throw new SnippetValidationError("snippets.json の形式が不正です", issues);
  }

  return {
    version: 1,
    updated_at: typeof input.updated_at === "string" ? input.updated_at : undefined,
    snippets,
  };
}

export function loadSnippetFile(jsonText) {
  return normalizeSnippetFile(parseSnippetJson(jsonText));
}

export function getEnabledSnippets(snippetFile) {
  return snippetFile.snippets
    .filter((snippet) => snippet.enabled !== false)
    .sort((a, b) => b.trigger.length - a.trigger.length || a.trigger.localeCompare(b.trigger));
}

export function findSnippetMatch(buffer, snippetsOrFile) {
  const snippets = Array.isArray(snippetsOrFile)
    ? snippetsOrFile
    : getEnabledSnippets(snippetsOrFile);

  return snippets
    .filter((snippet) => snippet.enabled !== false)
    .sort((a, b) => b.trigger.length - a.trigger.length || a.trigger.localeCompare(b.trigger))
    .find((snippet) => buffer.endsWith(snippet.trigger)) || null;
}

export class SnippetExpanderBuffer {
  constructor(snippetsOrFile) {
    this.snippets = Array.isArray(snippetsOrFile) ? snippetsOrFile : getEnabledSnippets(snippetsOrFile);
    this.maxTriggerLength = this.snippets.reduce((max, snippet) => Math.max(max, snippet.trigger.length), 0);
    this.buffer = "";
  }

  push(text) {
    if (this.maxTriggerLength === 0) {
      return {
        matched: false,
        snippet: null,
        deleteCount: 0,
        insertText: "",
      };
    }

    this.buffer = `${this.buffer}${text}`.slice(-this.maxTriggerLength);
    const match = findSnippetMatch(this.buffer, this.snippets);
    if (match) {
      this.buffer = "";
      return {
        matched: true,
        snippet: match,
        deleteCount: match.trigger.length,
        insertText: match.body,
      };
    }
    return {
      matched: false,
      snippet: null,
      deleteCount: 0,
      insertText: "",
    };
  }

  reset() {
    this.buffer = "";
  }
}

function readRequiredString(value, field, issues) {
  if (typeof value !== "string" || value.length === 0) {
    issues.push(`${field} は空でない文字列である必要があります`);
    return "";
  }
  return value;
}
