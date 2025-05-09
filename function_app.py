import azure.functions as func
import logging
import os
import asyncio
from azure.ai.inference.aio import ChatCompletionsClient
from azure.identity.aio import DefaultAzureCredential
from semantic_kernel.connectors.ai.azure_ai_inference import AzureAIInferenceChatCompletion, AzureAIInferenceChatPromptExecutionSettings
from semantic_kernel.contents.chat_history import ChatHistory

ai_deployment_name = os.environ.get("AZURE_OPENAI_DEPLOYMENT_NAME", "chat")
ai_endpoint = os.environ["AZURE_AI_INFERENCE_ENDPOINT"]
api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-12-01-preview")

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
        api_version=api_version,
    ),
)

execution_settings = AzureAIInferenceChatPromptExecutionSettings(
    max_completion_tokens=100,  # Changed from max_tokens to max_completion_tokens
    temperature=1.0,
    #  top_p=0.9,  #unsupported in mini model
    # extra_parameters={...},    # model-specific parameters
)

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.generic_trigger(
    arg_name="context",
    type="mcpToolTrigger",
    toolName="hello_mcp",
    description="Hello world.",
    toolProperties="[]",
)
async def hello_mcp(context) -> None:
    """
    A simple function that returns a greeting message.

    Args:
        context: The trigger context (not used in this function).

    Returns:
        str: A greeting message.
    """
    chat_history = ChatHistory()
    chat_history.add_user_message("Hello, how are you?")

    response = await chat_completion_service.get_chat_message_content(
        chat_history=chat_history,
        settings=execution_settings,
    )
    logging.info(response)
    # Convert the response object to a string before returning
    response_str = str(response)
    return response_str

if __name__ == "__main__":
    asyncio.run(hello_mcp())
