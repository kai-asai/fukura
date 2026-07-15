using System.Text.Json.Serialization;

namespace FukuraWindows;

internal sealed class SnippetFile
{
    [JsonPropertyName("version")]
    public int Version { get; set; } = 1;

    [JsonPropertyName("updated_at")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? UpdatedAt { get; set; }

    [JsonPropertyName("snippets")]
    public List<Snippet> Snippets { get; set; } = [];
}

internal sealed class Snippet
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("trigger")]
    public string Trigger { get; set; } = "";

    [JsonPropertyName("body")]
    public string Body { get; set; } = "";

    [JsonPropertyName("enabled")]
    public bool Enabled { get; set; } = true;

    [JsonPropertyName("tags")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<string>? Tags { get; set; }

    [JsonPropertyName("updated_at")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? UpdatedAt { get; set; }

    public Snippet Clone(string? trigger = null) => new()
    {
        Id = Guid.NewGuid().ToString("N"),
        Trigger = trigger ?? Trigger,
        Body = Body,
        Enabled = Enabled,
        Tags = Tags is null ? null : [.. Tags]
    };

    public override string ToString() => $"{(Enabled ? "●" : "○")} {Trigger}";
}
