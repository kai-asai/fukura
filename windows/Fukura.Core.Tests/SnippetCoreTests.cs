using Fukura.Core;
using Xunit;

namespace Fukura.Core.Tests;

public sealed class SnippetCoreTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "fukura-tests-" + Guid.NewGuid().ToString("N"));

    public SnippetCoreTests()
    {
        Directory.CreateDirectory(_root);
    }

    public void Dispose()
    {
        if (Directory.Exists(_root)) Directory.Delete(_root, true);
    }

    [Fact]
    public void Load_CreatesExampleAndSkipsDisabledSnippet()
    {
        var store = CreateStore();
        store.Load();

        Assert.True(store.WasCreatedOnLoad);
        Assert.Contains(store.EnabledSnippets, snippet => snippet.Trigger == ";mail");
        Assert.DoesNotContain(store.EnabledSnippets, snippet => snippet.Trigger == ";addr");
        Assert.Contains("\n", store.Document.Snippets.Single(snippet => snippet.Trigger == ";thx").Body);
    }

    [Fact]
    public void LongerTriggerWinsAndMatchClearsBuffer()
    {
        var matcher = new SnippetMatcher();
        matcher.Update([
            new Snippet { Id = "short", Trigger = ";t", Body = "short", Enabled = true },
            new Snippet { Id = "long", Trigger = ";today", Body = "long", Enabled = true }
        ]);

        Assert.Null(matcher.Push(";toda"));
        var match = matcher.Push("y");
        Assert.Equal("long", match?.Id);
        Assert.Null(matcher.Push("x"));
    }

    [Fact]
    public void EmptyDictionaryNeverMatches()
    {
        var matcher = new SnippetMatcher();
        matcher.Update([]);
        Assert.Null(matcher.Push(";mail"));
    }

    [Fact]
    public void SaveRejectsDuplicateAndEmptyFieldsAndWritesBackup()
    {
        var store = CreateStore();
        store.Load();
        var original = File.ReadAllText(store.FilePath);

        var error = Assert.Throws<InvalidDataException>(() => store.Save([
            new Snippet { Id = "a", Trigger = ";x", Body = "A" },
            new Snippet { Id = "b", Trigger = ";x", Body = "B" }
        ]));
        Assert.Contains("重複", error.Message);
        Assert.Equal(original, File.ReadAllText(store.FilePath));
        Assert.False(File.Exists(store.BackupPath));

        Assert.Throws<InvalidDataException>(() => store.Save([
            new Snippet { Id = "a", Trigger = "", Body = "A" }
        ]));
        Assert.Throws<InvalidDataException>(() => store.Save([
            new Snippet { Id = " ", Trigger = ";x", Body = "A" }
        ]));
    }

    [Fact]
    public void SavePreservesMultilineBodyAndTags()
    {
        var store = CreateStore();
        store.Load();
        store.Save([
            new Snippet
            {
                Id = "lines",
                Trigger = ";lines",
                Body = "1行目\n2行目",
                Enabled = true,
                Tags = ["note"]
            }
        ]);

        var reloaded = CreateStore();
        reloaded.Load();
        var snippet = Assert.Single(reloaded.Document.Snippets);
        Assert.Equal("1行目\n2行目", snippet.Body);
        Assert.Equal("note", Assert.Single(snippet.Tags!));
        Assert.False(string.IsNullOrEmpty(reloaded.Document.UpdatedAt));
        var backup = File.ReadAllText(store.BackupPath);
        Assert.Contains(";mail", backup);
        Assert.DoesNotContain(";lines", backup);
    }

    [Fact]
    public void ImportRejectsInvalidJsonWithoutReplacingDictionary()
    {
        var store = CreateStore();
        store.Load();
        var original = File.ReadAllText(store.FilePath);
        var broken = Path.Combine(_root, "broken.json");
        File.WriteAllText(broken, "{ broken");

        var error = Assert.Throws<InvalidDataException>(() => store.Import(broken));
        Assert.Contains("JSON", error.Message);
        Assert.Equal(original, File.ReadAllText(store.FilePath));
    }

    [Fact]
    public void ImportAndExportRoundTrip()
    {
        var store = CreateStore();
        store.Load();
        var source = Path.Combine(_root, "incoming.json");
        File.WriteAllText(source, """
            {
              "version": 1,
              "snippets": [
                { "id": "mail", "trigger": ";mail", "body": "a@example.com", "enabled": true }
              ]
            }
            """);

        store.Import(source);
        Assert.Equal(";mail", Assert.Single(store.EnabledSnippets).Trigger);

        var exported = Path.Combine(_root, "exported.json");
        store.Export(exported);
        Assert.Contains(";mail", File.ReadAllText(exported));
    }

    [Fact]
    public void OversizedFileAndFieldsAreRejected()
    {
        var store = CreateStore();
        store.Load();
        var huge = Path.Combine(_root, "huge.json");
        File.WriteAllText(huge, new string('x', SnippetStore.MaxJsonBytes + 1));
        Assert.Throws<InvalidDataException>(() => store.Import(huge));

        Assert.Throws<InvalidDataException>(() => store.Save([
            new Snippet { Id = "long", Trigger = ";" + new string('x', 64), Body = "body" }
        ]));
        Assert.Throws<InvalidDataException>(() => store.Save([
            new Snippet { Id = "body", Trigger = ";body", Body = new string('x', 8001) }
        ]));
        Assert.Throws<InvalidDataException>(() => store.Save(
            Enumerable.Range(0, 501).Select(index => new Snippet
            {
                Id = $"s{index}",
                Trigger = $";s{index}",
                Body = "body"
            })));
    }

    [Fact]
    public void LegacyDictionaryIsCopiedWhenFukuraDictionaryIsMissing()
    {
        var legacy = Path.Combine(_root, "bon");
        Directory.CreateDirectory(legacy);
        File.WriteAllText(Path.Combine(legacy, "snippets.json"), """
            { "version": 1, "snippets": [ { "id": "old", "trigger": ";old", "body": "移行", "enabled": true } ] }
            """);
        File.WriteAllText(Path.Combine(legacy, "snippets.backup.json"), "{\"version\":1,\"snippets\":[]}");

        var store = CreateStore();
        store.Load();

        Assert.False(store.WasCreatedOnLoad);
        Assert.Equal(";old", Assert.Single(store.EnabledSnippets).Trigger);
        Assert.True(File.Exists(store.BackupPath));
        Assert.True(File.Exists(Path.Combine(legacy, "snippets.json")));
    }

    [Fact]
    public void UnsupportedVersionIsRejected()
    {
        var store = CreateStore();
        var path = Path.Combine(_root, "v2.json");
        File.WriteAllText(path, """{ "version": 2, "snippets": [] }""");
        var error = Assert.Throws<InvalidDataException>(() => store.Import(path));
        Assert.Contains("version", error.Message);
    }

    private SnippetStore CreateStore() => new(Path.Combine(_root, "fukura"), [Path.Combine(_root, "bon")]);
}
