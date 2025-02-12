using Azure.AI.ContentSafety;
using Azure.AI.TextAnalytics;
using Azure.AI.Translation.Text;
using Azure;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using System.Net;

namespace FunctionApp;

public class Function
{
    // Transation
    private const string TextTranslationApiKey = "#InsertValue#";
    private const string Region = "#InsertValue#";

    // Content Safety
    private const string ContentSafetyServiceEndpoint = "#InsertValue#";
    private const string ContentSafetyApiKey = "#InsertValue#";

    // Sentiment Analysis
    private const string SentimentAnalysisServiceEndpoint = "#InsertValue#";
    private const string SentimentAnalysisApiKey = "#InsertValue#";

    [Function("Function")]
    public static async Task<HttpResponseData> RunAsync([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
    {
        // read body stream as InputData
        var inputData = await req.ReadFromJsonAsync<InputData>();
        if (inputData is null)
        {
            return req.CreateResponse(HttpStatusCode.BadRequest);
        }

        List<ResultRow> results =
        [
            .. inputData.Lines.Select(
                    (text, index) =>
                        new ResultRow(text) { TextDocumentInput = new(index.ToString(), text) }
                )
        ];

        // translate text
        if (inputData.Translate ?? false)
        {
            var textTranslationClient = new TextTranslationClient(
                new AzureKeyCredential(TextTranslationApiKey),
                Region
            );
            var translationResult = await textTranslationClient.TranslateAsync(
                "en",
                inputData.Lines
            );

            foreach (var item in translationResult.Value.Select((x, i) => (x, i)))
            {
                results
                    .First(x => x.TextDocumentInput!.Id == item.i.ToString())
                    .TranslatedText = item.x.Translations[0].Text;
            }
        }

        // moderate text
        if (inputData.Moderate ?? false)
        {
            var contentSafetyClient = new ContentSafetyClient(
                new Uri(ContentSafetyServiceEndpoint),
                new AzureKeyCredential(ContentSafetyApiKey)
            );

            AnalyzeTextResult analyzeTextResult;
            foreach (var item in results)
            {
                var data =
                    inputData.Translate ?? false ? item.TranslatedText : item.OriginalText;

                var analyzeTextOptions = new AnalyzeTextOptions(data)
                {
                    OutputType = AnalyzeTextOutputType.EightSeverityLevels
                };
                analyzeTextResult = await contentSafetyClient.AnalyzeTextAsync(
                    analyzeTextOptions
                );
                item.CategoriesAnalysis = analyzeTextResult
                    .CategoriesAnalysis.Select(ca => new CategoriesAnalysis(
                        ca.Category.ToString(),
                        ca.Severity ?? 0
                    ))
                    .ToList();
            }
        }

        // sentiment analysis
        var textAnalyticsClient = new TextAnalyticsClient(
            new Uri(SentimentAnalysisServiceEndpoint),
            new AzureKeyCredential(SentimentAnalysisApiKey)
        );

        var sentimentAnalysisResult = await textAnalyticsClient.AnalyzeSentimentBatchAsync(
            results.Select(x => x.TextDocumentInput)
        );

        foreach (var item in sentimentAnalysisResult.Value)
        {
            var result = results
                .Where(x => x.TextDocumentInput?.Id == item.Id)
                .FirstOrDefault();
            if (result is not null)
            {
                result.ConfidenceScores = item.DocumentSentiment.ConfidenceScores;
                result.ConfidentScoreResult = item.DocumentSentiment.Sentiment.ToString();
                result.Status = Status.Success;
            }
        }

        var response = req.CreateResponse(HttpStatusCode.OK);
        await response.WriteAsJsonAsync(results);
        return response;
    }
}