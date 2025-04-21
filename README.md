# Hello Semantic Kernel Function MCP

This project uses Microsoft Fabric AI services with Semantic Kernel code, wrapped with an Azure Function and exposed as a remote MCP server.

The bases of inspiration to create this sample template are:
- https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/develop/semantic-kernel
- https://aka.ms/mcp-remote

## Prerequisites

- [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [Python 3.10+](https://www.python.org/downloads/)
- [VS Code](https://code.visualstudio.com/) with [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
- [Azure AI Services resource](https://portal.azure.com) with deployed models
- [Node.js and npm](https://nodejs.org/) (for running MCP Inspector)

## Setup

1. Clone this repository and open it in VS Code

2. Create a Python virtual environment:
   ```
   python -m venv .venv
   ```

3. Create a deployment in your Azure AI services resource:

   ### Setup via AZD/Bicep

   Simply
   ```shell
   azd provision
   ```
   ** Note all environment variablees needed for AI are outputed into the /.azure/<your env name>/.env file

   ### Setup via Portal
      - In the [portal](https://ai.azure.com), navigate to your Azure OpenAI resource
      - Go to "Model deployments" and click "Create new deployment"
      - Select **model name**: `gpt-4o-mini`
      - Select **model version**: `2024-07-18`
      - Give your deployment a name (e.g., `chat`)
      - Complete the deployment creation

4. Configure your `local.settings.json` file with your Azure AI services being careful to set `AZURE_AI_INFERENCE_ENDPOINT` using value from step 3:
   ```json
   {
     "IsEncrypted": false,
     "Values": {
         "AzureWebJobsStorage": "UseDevelopmentStorage=true",
         "FUNCTIONS_WORKER_RUNTIME": "python",
         "AZURE_OPENAI_DEPLOYMENT_NAME": "chat",
         "AZURE_AI_INFERENCE_ENDPOINT": "https://<your AI Services resource>.cognitiveservices.azure.com/",
         "AZURE_OPENAI_API_VERSION": "2024-12-01-preview"
     }
   }
   ```

   Replace the placeholder values with:
   - `AZURE_OPENAI_DEPLOYMENT_NAME`: The name you gave to your gpt-4o-mini deployment (defaults to `"chat"`)
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

3. The function should start, and you'll see a URL for the local HTTP endpoint (typically http://0.0.0.0:7071).

>**NOTE** if VNetEnabled = True you must remember to either use a jump box on that VNET, or add your local machine's public IP address to the Network -> Firewall settings for your AI Services resource, or you will receive errors like `Exception: HttpResponseError: (403) Public access is disabled. Please configure private endpoint.` or `Exception: HttpResponseError: (403) Access denied due to Virtual Network/Firewall rules.`

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

## Deploying to Azure

To deploy this function to Azure:

```shell
azd up
```

## Authentication

This function uses Azure Entra ID (formerly Azure Active Directory) for authentication via DefaultAzureCredential. Make sure you're logged in with the Azure CLI or have appropriate credentials configured.

## Troubleshooting

- If you encounter errors about missing environment variables, ensure your `local.settings.json` file has the correct values.
- If authentication fails, run `az login` to log in with your Azure credentials.
- If the MCP Inspector cannot connect, verify that your function app is running and the endpoint URL is correct.
