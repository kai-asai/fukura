using System.Text;
using System.Text.Json;

namespace FukuraWindows;

internal sealed class SnippetStore
{
    internal const int MaxJsonBytes = 512 * 1024;
    internal const int MaxSnippets = 500;
    internal const int MaxTriggerLength = 64;
    internal const int MaxBodyLength = 8000;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        AllowTrailingCommas = false,
        PropertyNameCaseInsensitive = false,
        ReadCommentHandling = JsonCommentHandling.Disallow,
        WriteIndented = true
    };

    public string DirectoryPath { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "fukura");
    public string FilePath => Path.Combine(DirectoryPath, "snippets.json");
    public string BackupPath => Path.Combine(DirectoryPath, "snippets.backup.json");
    public bool WasCreatedOnLoad { get; private set; }
    public SnippetFile Document { get; private set; } = new();
    public IReadOnlyList<Snippet> EnabledSnippets => Document.Snippets
        .Where(item => item.Enabled)
        .OrderByDescending(item => item.Trigger.Length)
        .ThenBy(item => item.Trigger, StringComparer.Ordinal)
        .ToList();

    public void Load()
    {
        Directory.CreateDirectory(DirectoryPath);
        MigrateLegacyDataIfNeeded();
        WasCreatedOnLoad = !File.Exists(FilePath);
        if (!File.Exists(FilePath))
        {
            File.WriteAllText(FilePath, ExampleJson, new UTF8Encoding(false));
        }
        Document = ReadAndValidate(FilePath);
    }

    private void MigrateLegacyDataIfNeeded()
    {
        if (File.Exists(FilePath)) return;

        var localApplicationData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        foreach (var legacyName in new[] { "bon", "SnippetExpander" })
        {
            var legacyDirectory = Path.Combine(localApplicationData, legacyName);
            var legacyFile = Path.Combine(legacyDirectory, "snippets.json");
            if (!File.Exists(legacyFile)) continue;

            File.Copy(legacyFile, FilePath);
            var legacyBackup = Path.Combine(legacyDirectory, "snippets.backup.json");
            if (File.Exists(legacyBackup)) File.Copy(legacyBackup, BackupPath, true);
            return;
        }
    }

    public void Save(IEnumerable<Snippet> snippets)
    {
        var document = new SnippetFile
        {
            Version = 1,
            UpdatedAt = DateTimeOffset.Now.ToString("O"),
            Snippets = snippets.ToList()
        };
        Validate(document);
        var json = JsonSerializer.Serialize(document, JsonOptions);
        if (Encoding.UTF8.GetByteCount(json) > MaxJsonBytes)
            throw new InvalidDataException($"snippets.json は {MaxJsonBytes / 1024} KiB 以下にしてください。");

        Directory.CreateDirectory(DirectoryPath);
        if (File.Exists(FilePath)) File.Copy(FilePath, BackupPath, true);
        var temporaryPath = FilePath + ".tmp";
        File.WriteAllText(temporaryPath, json + Environment.NewLine, new UTF8Encoding(false));
        File.Move(temporaryPath, FilePath, true);
        Document = document;
    }

    public void Import(string sourcePath)
    {
        var imported = ReadAndValidate(sourcePath);
        Save(imported.Snippets);
    }

    public void Export(string destinationPath)
    {
        Save(Document.Snippets);
        File.Copy(FilePath, destinationPath, true);
    }

    private static SnippetFile ReadAndValidate(string path)
    {
        var info = new FileInfo(path);
        if (info.Length > MaxJsonBytes)
            throw new InvalidDataException($"snippets.json は {MaxJsonBytes / 1024} KiB 以下にしてください。");
        try
        {
            var document = JsonSerializer.Deserialize<SnippetFile>(File.ReadAllText(path), JsonOptions)
                ?? throw new InvalidDataException("ファイルの内容が空です。");
            Validate(document);
            return document;
        }
        catch (JsonException error)
        {
            throw new InvalidDataException($"JSON形式を読み取れません（{error.LineNumber + 1}行目付近）。", error);
        }
    }

    private static void Validate(SnippetFile document)
    {
        if (document.Version != 1) throw new InvalidDataException("version は 1 のみ対応しています。");
        if (document.Snippets.Count > MaxSnippets) throw new InvalidDataException($"スニペットは {MaxSnippets} 件以下にしてください。");
        var triggers = new HashSet<string>(StringComparer.Ordinal);
        foreach (var snippet in document.Snippets)
        {
            if (string.IsNullOrWhiteSpace(snippet.Id)) throw new InvalidDataException("IDが空のスニペットがあります。");
            if (string.IsNullOrEmpty(snippet.Trigger)) throw new InvalidDataException("トリガーが空のスニペットがあります。");
            if (snippet.Trigger.Length > MaxTriggerLength) throw new InvalidDataException($"トリガーは {MaxTriggerLength} 文字以下にしてください: {snippet.Trigger}");
            if (string.IsNullOrEmpty(snippet.Body)) throw new InvalidDataException($"展開する文章が空です: {snippet.Trigger}");
            if (snippet.Body.Length > MaxBodyLength) throw new InvalidDataException($"本文は {MaxBodyLength} 文字以下にしてください: {snippet.Trigger}");
            if (!triggers.Add(snippet.Trigger)) throw new InvalidDataException($"トリガーが重複しています: {snippet.Trigger}");
        }
    }

    private const string ExampleJson = """
        {
          "version": 1,
          "snippets": [
            { "id": "mail", "trigger": ";mail", "body": "your.name@example.com", "enabled": true },
            { "id": "thanks", "trigger": ";thx", "body": "ありがとうございます。\n確認して折り返しいたします。", "enabled": true },
            { "id": "address", "trigger": ";addr", "body": "住所を入力してください", "enabled": false }
          ]
        }
        """;
}
