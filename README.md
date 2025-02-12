# AI-CourseEvaluations

This is a Proof of Concept (POC) demonstrating how AI can enhance the safety and efficiency of processing free-text course evaluations by detecting potential threats and categorizing feedback for manual review.

## Project Overview

This POC offers two approaches to classify course evaluations:

- **Azure Logic App**: Orchestrates text classification using Azure Language Services and SharePoint lists. This method is better suited for non-developers.
- **Azure Function**: Classifies text using Azure Language Services. This approach is ideal for developers who prefer handling input/output directly.

Select the approach that best fits your needs. The Logic App/SharePoint approach is better suited for 'non-developers', whereas the Function App only processes the data and leaves the input/output to you.

**Note**: Azure Content Safety produced inconsistent results for texts in Swedish, so a translation option has been added. Sentiment analysis is performed on the original text.

## Setting Up the Logic App Workflow

### Prerequisites

- An Azure subscription with permissions to create resources.
- Access to a SharePoint site with permissions to create lists.
- A service account or similar credentials to authenticate the Logic App or Azure Function with the SharePoint site.

### Initial setup

1. Create the necessary Azure resources as outlined in the [prerequisites section](#prerequisites).
1. Set up SharePoint lists as described in the [SharePoint Lists section](#sharepoint-lists).
1. Deploy resources following the instructions in the [Deployment section](#deployment-of-the-logic-app-and-the-necessary-resources).

#### SharePoint Lists

Import the templates to your SharePoint site:

- `MainListTemplate.csv`: Main list template with example data.
- `SettingsTemplate.csv`: Settings list template containing default values.

Modify the settings list as needed to match your requirements.

#### Deployment of the Logic App and the necessary resources

*Note: The parameters below are sample values.*

1. Create a resource group to deploy the Logic App and related resources:

    ```azurecli-interactive
    az group create --name course-eval-ai-rg --location swedencentral
    ```

1. Deploy using the `main.bicep` file. You can set parameters directly in the file or via the `--parameters` flag.

    **The parameters needed are**:

    - `namePrefix`: Prefix for the names of the resources. Default is 'course-eval-ai'.
    - `sharepointSiteUrl`: URL of the SharePoint site.
    - `sharepointListMainName`: Name of the main SharePoint list.
    - `sharepointListSettingsName`: Name of the settings SharePoint list. Default is 'Settings'.

    **Deployment Commands**

    - If parameters are set in the `main.bicep` file:

        ```azurecli-interactive
        az deployment group create `
            --resource-group course-eval-ai-rg `
            --template-file main.bicep 
        ```

    - If parameters are not set in the `main.bicep` file:

        ```azurecli-interactive
        az deployment group create `
            --resource-group course-eval-ai-rg `
            --template-file main.bicep `
            --parameters `
                namePrefix=course-eval-ai `
                sharepointSiteUrl=https://somesharepoint.com/sites/somesite `
                sharepointListMainName=CourseEvaluations `
                sharepointListSettingsName=Settings
        ```

1. **Post-Deployment Steps**:
    1. In the Logic App, go to the `Connections` tab and authenticate the connector with a user that have access to the SharePoint lists.
    1. Enable the Logic App.

### Usage

1. Enter data into the main SharePoint list under 'Free Text - Incoming' and set the status to 'New'.
1. The Logic App or Azure Function will process the data every 5 minutes.
1. Review the results in the main SharePoint list. The status will update based on the classification results.

### Implementing the Azure Function for Text Classification

For detailed information on setting up and using the Azure Function, refer to the [readme.md for the Azure function](AzureFunction/FunctionApp/readme.md).
