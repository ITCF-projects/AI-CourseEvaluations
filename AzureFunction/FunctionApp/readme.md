# Azure Function App

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment of the Azure Function](#deployment-of-the-azure-function)
- [Example](#example)

## Overview
This is a more developer-friendly approach to classifying course evaluations.
It uses an Azure Function to classify the text using Azure Language Services. 

As specified in the [Readme.md](../../README.md) for the Logic App, the translation option is used only when Azure Content Safety returns unexpected results, which has occurred a few times when the original text is in Swedish.

### Prerequisites
- An Azure subscription with permissions to create resources.
- A Function App
- [Azure AI Translator](https://learn.microsoft.com/en-us/azure/ai-services/translator/) (optional)
- [Azure AI Content Safety](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/) (optional)
- [Sentiment analysis from Azure AI Language](https://learn.microsoft.com/en-us/azure/ai-services/language-service/sentiment-opinion-mining/overview)

### Deployment of the Azure Function
1. Configure the required parameters:
    - `TextTranslationApiKey`: The API key for the Azure AI Translation Service.
    - `Region`: The region where the Azure AI Translation Service is deployed.
    - `ContentSafetyServiceEndpoint`: The endpoint for the Azure AI Content Safety Service.
    - `ContentSafetyApiKey`: The API key for the Azure AI Content Safety Service.
    - `SentimentAnalysisServiceEndpoint`: The endpoint for the Azure AI Sentiment Analysis Service.
    - `SentimentAnalysisApiKey`: The API key for the Azure AI Sentiment Analysis Service.
1. Create the Azure Function and deploy it to your Azure environment.

## Example

The input data is a JSON object:
```json
{
	"Lines": [
		"The food and service were unacceptable. The concierge was nice, however.",
		"Just OK."
	],
	"Translate": false,
	"Moderate": true
}
```

The output will be:
```json
[
    {
        "OriginalText": "The food and service were unacceptable. The concierge was nice, however.",
        "TranslatedText": null,
        "CategoriesAnalysis": [
            {
                "Category": "Hate",
                "Severity": 0
            },
            {
                "Category": "SelfHarm",
                "Severity": 0
            },
            {
                "Category": "Sexual",
                "Severity": 0
            },
            {
                "Category": "Violence",
                "Severity": 0
            }
        ],
        "ConfidenceScores": {
            "Positive": 0,
            "Neutral": 0,
            "Negative": 1
        },
        "ConfidentScoreResult": "Negative",
        "Status": "Success"
    },
    {
        "OriginalText": "Just OK.",
        "TranslatedText": null,
        "CategoriesAnalysis": [
            {
                "Category": "Hate",
                "Severity": 0
            },
            {
                "Category": "SelfHarm",
                "Severity": 0
            },
            {
                "Category": "Sexual",
                "Severity": 0
            },
            {
                "Category": "Violence",
                "Severity": 0
            }
        ],
        "ConfidenceScores": {
            "Positive": 0.55,
            "Neutral": 0.43,
            "Negative": 0.02
        },
        "ConfidentScoreResult": "Positive",
        "Status": "Success"
    }
]
```
