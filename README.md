# Hello Semantic Kernel Function MCP

This project is an Azure Function that uses Semantic Kernel with the Model Context Protocol (MCP) and Azure AI services.

## Prerequisites

- [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [Python 3.11+](https://www.python.org/downloads/)
- [VS Code](https://code.visualstudio.com/) with [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
- [Azure AI Services resource](https://portal.azure.com) with deployed models
- [Node.js and npm](https://nodejs.org/) (for running MCP Inspector)

## Setup

1. Clone this repository and open it in VS Code

2. Create a Python virtual environment:
   ```
   python -m venv .venv
   ```

3. Configure your `local.settings.json` file with your Azure AI services:
   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "FUNCTIONS_WORKER_RUNTIME": "python",
       "AzureWebJobsStorage": "UseDevelopmentStorage=true",
       "AZURE_OPENAI_DEPLOYMENT_NAME": "chat",
       "AZURE_AI_INFERENCE_ENDPOINT": "https://your-azure-ai-endpoint.com"
     }
   }
   ```

   Replace the placeholder values with:
   - `AZURE_OPENAI_DEPLOYMENT_NAME`: Your Azure OpenAI deployment name (defaults to "chat" if not specified)
   - `AZURE_AI_INFERENCE_ENDPOINT`: Your Azure AI Inference endpoint URL (required)

## Running Locally

1. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Start the function app:
   ```
   func start
   ```
   
   Alternatively, in VS Code, press `F5` or use the command palette to run "Tasks: Run Task" and select "func: host start".

3. The function should start, and you'll see a URL for the local HTTP endpoint (typically http://localhost:7071).

## Testing with MCP Inspector

1. In a new terminal window, install and run MCP Inspector:
   ```
   npx @modelcontextprotocol/inspector
   ```

2. CTRL+click to load the MCP Inspector web app from the URL displayed by the app (e.g., http://0.0.0.0:5173/#resources)

3. In the MCP Inspector interface:
   - Set the transport type to **SSE**
   - Set the URL to your running Function app's SSE endpoint:
     ```
     http://localhost:7071/runtime/webhooks/mcp/sse
     ```
   - Click **Connect**

   > **Note**: This step will not work in CodeSpaces.

4. Once connected, you can:
   - List Tools
   - Click on a tool
   - Run Tool

## Authentication

This function uses Azure Entra ID (formerly Azure Active Directory) for authentication via DefaultAzureCredential. Make sure you're logged in with the Azure CLI or have appropriate credentials configured.

## Troubleshooting

- If you encounter errors about missing environment variables, ensure your `local.settings.json` file has the correct values.
- If authentication fails, run `az login` to log in with your Azure credentials.
- If the MCP Inspector cannot connect, verify that your function app is running and the endpoint URL is correct.

## Deploying to Azure

To deploy this function to Azure:

1. Create a Function App in Azure
2. Deploy using VS Code Azure Functions extension or Azure CLI
3. Configure application settings in the Azure portal with the same environment variables you used locally