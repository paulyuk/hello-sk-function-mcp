import azure.functions as func
import logging
import os
from azure.ai.inference.aio import ChatCompletionsClient
from azure.identity.aio import DefaultAzureCredential
from semantic_kernel.connectors.ai.azure_ai_inference import AzureAIInferenceChatCompletion

ai_deployment_name = os.environ.get("AZURE_OPENAI_DEPLOYMENT_NAME", "chat")
ai_endpoint = os.environ["AZURE_AI_INFERENCE_ENDPOINT"]

# Check if ai_endpoint is empty or null
if not ai_endpoint or ai_endpoint.strip() == "":
    raise ValueError("AZURE_AI_INFERENCE_ENDPOINT environment variable is empty or not set")

# Use os.environ.get with default value "chat" if the environment variable is not set
chat_completion_service = AzureAIInferenceChatCompletion(
    ai_model_id=ai_deployment_name,
    client=ChatCompletionsClient(
        endpoint=f"{str(ai_endpoint).strip('/')}/openai/deployments/{ai_deployment_name}",
        credential=DefaultAzureCredential(),
        credential_scopes=["https://cognitiveservices.azure.com/.default"],
    ),
)

from semantic_kernel.connectors.ai.azure_ai_inference import AzureAIInferenceChatPromptExecutionSettings

execution_settings = AzureAIInferenceChatPromptExecutionSettings(
    max_tokens=100,
    temperature=0.5,
    top_p=0.9,
    # extra_parameters={...},    # model-specific parameters
)

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)
import asyncio

@app.route(route="hello")
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Starting Azure Function -> Main from /api/hello route")
    return func.HttpResponse(
            "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
            status_code=200
    )

if __name__ == "__main__":
    asyncio.run(main())

@app.route(route="http_trigger")
def http_trigger(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            name = req_body.get('name')

    if name:
        return func.HttpResponse(f"Hello, {name}. This HTTP triggered function executed successfully.")
    else:
        return func.HttpResponse(
             "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
             status_code=200
        )