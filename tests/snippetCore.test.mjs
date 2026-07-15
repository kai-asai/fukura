import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  SnippetExpanderBuffer,
  SnippetValidationError,
  findSnippetMatch,
  getEnabledSnippets,
  loadSnippetFile,
} from "../shared/snippetCore.mjs";

test("example snippets load and default enabled snippets are usable", async () => {
  const json = await readFile(new URL("../examples/snippets.example.json", import.meta.url), "utf8");
  const file = loadSnippetFile(json);
  const enabled = getEnabledSnippets(file);

  assert.equal(file.version, 1);
  assert.equal(enabled.some((snippet) => snippet.trigger === ";mail"), true);
  assert.equal(enabled.some((snippet) => snippet.trigger === ";addr"), false);
});

test("enabled defaults to true when omitted", () => {
  const file = loadSnippetFile(JSON.stringify({
    version: 1,
    snippets: [{ id: "mail", trigger: ";mail", body: "a@example.com" }],
  }));

  assert.equal(file.snippets[0].enabled, true);
  assert.equal(getEnabledSnippets(file).length, 1);
});

test("invalid JSON returns a validation error instead of crashing", () => {
  assert.throws(
    () => loadSnippetFile("{ broken"),
    (error) => error instanceof SnippetValidationError && error.issues[0].includes("JSON parse error"),
  );
});

test("missing required fields are rejected", () => {
  assert.throws(
    () => loadSnippetFile(JSON.stringify({ version: 1, snippets: [{ id: "x", trigger: ";x" }] })),
    /形式が不正/,
  );
});

test("duplicate trigger is rejected", () => {
  assert.throws(
    () => loadSnippetFile(JSON.stringify({
      version: 1,
      snippets: [
        { id: "a", trigger: ";x", body: "A" },
        { id: "b", trigger: ";x", body: "B" },
      ],
    })),
    (error) => error instanceof SnippetValidationError && error.issues.some((issue) => issue.includes("重複")),
  );
});

test("oversized snippet files and fields are rejected", () => {
  assert.throws(
    () => loadSnippetFile(JSON.stringify({
      version: 1,
      snippets: Array.from({ length: 501 }, (_, index) => ({
        id: `s${index}`,
        trigger: `;s${index}`,
        body: "body",
      })),
    })),
    (error) => error instanceof SnippetValidationError && error.issues.some((issue) => issue.includes("500 件以下")),
  );

  assert.throws(
    () => loadSnippetFile(JSON.stringify({
      version: 1,
      snippets: [{ id: "long", trigger: `;${"x".repeat(64)}`, body: "body" }],
    })),
    (error) => error instanceof SnippetValidationError && error.issues.some((issue) => issue.includes("64 文字以下")),
  );

  assert.throws(
    () => loadSnippetFile(JSON.stringify({
      version: 1,
      snippets: [{ id: "body", trigger: ";body", body: "x".repeat(8001) }],
    })),
    (error) => error instanceof SnippetValidationError && error.issues.some((issue) => issue.includes("8000 文字以下")),
  );
});

test("longer trigger wins for suffix matching", () => {
  const file = loadSnippetFile(JSON.stringify({
    version: 1,
    snippets: [
      { id: "short", trigger: ";t", body: "short" },
      { id: "long", trigger: ";today", body: "long" },
    ],
  }));

  const match = findSnippetMatch("memo ;today", file);
  assert.equal(match.id, "long");
});

test("buffer emits delete and insert operations when a trigger is complete", () => {
  const file = loadSnippetFile(JSON.stringify({
    version: 1,
    snippets: [{ id: "thanks", trigger: ";thx", body: "ありがとうございます。確認いたします。" }],
  }));
  const expander = new SnippetExpanderBuffer(file);

  assert.equal(expander.push(";").matched, false);
  assert.equal(expander.push("t").matched, false);
  assert.equal(expander.push("h").matched, false);
  const result = expander.push("x");

  assert.equal(result.matched, true);
  assert.equal(result.deleteCount, 4);
  assert.equal(result.insertText, "ありがとうございます。確認いたします。");
});

test("empty snippet list never grows the buffer or matches", () => {
  const expander = new SnippetExpanderBuffer({ version: 1, snippets: [] });

  const result = expander.push(";mail");

  assert.equal(result.matched, false);
  assert.equal(expander.buffer, "");
});

test("multiline bodies use real newlines after JSON parsing", () => {
  const file = loadSnippetFile(JSON.stringify({
    version: 1,
    snippets: [{ id: "multiline", trigger: ";lines", body: "1行目\n2行目\n3行目" }],
  }));
  const expander = new SnippetExpanderBuffer(file);

  const result = expander.push(";lines");

  assert.equal(result.matched, true);
  assert.equal(result.insertText, "1行目\n2行目\n3行目");
  assert.equal(result.insertText.split("\n").length, 3);
});
