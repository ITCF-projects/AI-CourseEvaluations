using Azure.AI.TextAnalytics;
using System.Text.Json.Serialization;

namespace FunctionApp;

record InputData(string[] Lines, bool? Translate, bool? Moderate);

class ResultRow(string text)
{
    public string OriginalText { get; init; } = text;

    [JsonIgnore]
    public TextDocumentInput? TextDocumentInput { get; set; }
    public string? TranslatedText { get; set; }
    public List<CategoriesAnalysis>? CategoriesAnalysis { get; set; }
    public SentimentConfidenceScores? ConfidenceScores { get; set; }
    public string? ConfidentScoreResult { get; set; }
    public Status Status { get; set; }
}

record CategoriesAnalysis(string Category, int Severity);

[JsonConverter(typeof(JsonStringEnumConverter))]
enum Status
{
    Init,
    Success,
    Blocked,
    Warning,
    Failed
}