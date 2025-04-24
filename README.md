# Hello Foundry Agent Service with Semantic Kernel as a Function MCP Server

This project uses Microsoft Foundry AI services with Semantic Kernel code, wrapped with an Azure Function and exposed as a remote MCP server.

The bases of inspiration to create this sample template are:
- https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/develop/semantic-kernel
- https://aka.ms/mcp-remote

Use cases for this include
1. Any Foundry agent you've created can be a remote MCP server!
2. Instant access of your agentic code to MCP clients like Github Copilot and Copilot Studio

## Architecture

![Architecture Diagram](./architecture-diagram.svg)

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
   ** Note all environment variables needed for AI Foundry are outputed into the /.azure/<your env name>/.env file

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


## Connect to the *local* MCP server from a client/host

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

### Testing with VS Code - Github Copilot Agent mode

1. **Add MCP Server** from command palette and add URL to your running Function app's SSE endpoint:

    ```shell
    http://0.0.0.0:7071/runtime/webhooks/mcp/sse
    ```

1. **List MCP Servers** from command palette and start the server
1. In Copilot chat agent mode enter a prompt to trigger the tool, e.g., select some code and enter this prompt

    ```plaintext
    Say hello using mcp tool
    ```

1. When prompted to run the tool, consent by clicking **Continue**

1. When you're done, press Ctrl+C in the terminal window to stop the Functions host process.

## Deploy to Azure for Remote MCP

Run this [azd](https://aka.ms/azd) command to provision the function app, with any required Azure resources, and deploy your code:

```shell
azd up
```

> **Note** [API Management]() can be used for improved security and policies over your MCP Server, and [App Service built-in authentication](https://learn.microsoft.com/en-us/azure/app-service/overview-authentication-authorization) can be used to set up your favorite OAuth provider including Entra.  

## Connect to your *remote* MCP server function app from a client

Your client will need a key in order to invoke the new hosted SSE endpoint, which will be of the form `https://<funcappname>.azurewebsites.net/runtime/webhooks/mcp/sse`. The hosted function requires a system key by default which can be obtained from the [portal](https://learn.microsoft.com/en-us/azure/azure-functions/function-keys-how-to?tabs=azure-portal) or the CLI (`az functionapp keys list --resource-group <resource_group> --name <function_app_name>`). Obtain the system key named `mcp_extension`.

### Connect to remote MCP server in MCP Inspector
For MCP Inspector, you can include the key in the URL: 
```plaintext
https://<funcappname>.azurewebsites.net/runtime/webhooks/mcp/sse?code=<your-mcp-extension-system-key>
```

### Connect to remote MCP server in VS Code - GitHub Copilot
For GitHub Copilot within VS Code, you should set the key as the `x-functions-key` header in `mcp.json`, and you would use `https://<funcappname>.azurewebsites.net/runtime/webhooks/mcp/sse` for the URL. The following example is from the [mcp.json](.vscode/mcp.json) file included in this repository and uses an input to prompt you to provide the key when you start the server from VS Code.  

1. Click Start on the server `remote-mcp-function`, inside the [mcp.json](.vscode/mcp.json) file:

1. Enter the name of the function app that you created in the Azure Portal, when prompted by VS Code.

1. Enter the `Azure Functions MCP Extension System Key` into the prompt. You can copy this from the Azure portal for your function app by going to the Functions menu item, then App Keys, and copying the `mcp_extension` key from the System Keys.

1. In Copilot chat agent mode enter a prompt to trigger the tool, e.g., select some code and enter this prompt

    ```plaintext
    Say Hello using MCP tool
    ```

## Redeploy your code

You can run the `azd up` command as many times as you need to both provision your Azure resources and deploy code updates to your function app.

>[!NOTE]
>Deployed code files are always overwritten by the latest deployment package.

## Clean up resources

When you're done working with your function app and related resources, you can use this command to delete the function app and its related resources from Azure and avoid incurring any further costs:

```shell
azd down
```


## Authentication

This function uses Azure Entra ID (formerly Azure Active Directory) for authentication via DefaultAzureCredential. Make sure you're logged in with the Azure CLI or have appropriate credentials configured.

## Troubleshooting

- If you encounter errors about missing environment variables, ensure your `local.settings.json` file has the correct values.
- If authentication fails, run `az login` to log in with your Azure credentials.
- If the MCP Inspector cannot connect, verify that your function app is running and the endpoint URL is correct.
- Irregular behaviors, 404 resource not found errors, and more will happen if `AZURE_OPENAI_API_VERSION` is set to too old a version for these SDKs.  It is recommended to set `"AZURE_OPENAI_API_VERSION": "2024-12-01-preview"` (or later) in local.settings.json locally, and in your deployed Azure Function deployment in the Environment Variables (this is done for you by default using `azd up`'s bicep files). 
