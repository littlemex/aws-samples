from strands import Agent, tool
import json
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands.models import BedrockModel

app = BedrockAgentCoreApp()

# Create custom tools
@tool
def calculator(expression: str) -> str:
    """ Calculate mathematical expressions. Use this for basic math operations like 2+2, 10*5, etc. """
    try:
        # Safe evaluation of basic mathematical expressions
        result = eval(expression, {"__builtins__": {}}, {})
        return f"計算結果: {expression} = {result}"
    except Exception as e:
        return f"計算エラー: {str(e)}"

@tool
def weather():
    """ Get weather information """
    # Dummy implementation
    return "今日は晴れです。気温は22度です。"

@tool
def greeting():
    """ Provide a friendly greeting """
    return "こんにちは！私はAIアシスタントです。計算や天気情報をお手伝いできます。"

# Initialize the model - 環境変数から取得
import os
model_id = os.getenv("BEDROCK_MODEL_ID", "us.anthropic.claude-3-7-sonnet-20250219-v1:0")
model = BedrockModel(
    model_id=model_id,
)

agent = Agent(
    model=model,
    tools=[calculator, weather, greeting],
    system_prompt="あなたは親切なアシスタントです。日本語で回答してください。簡単な数学計算、天気情報の取得、挨拶ができます。"
)

@app.entrypoint
def runtime_agent_invoke(payload):
    """
    Invoke the agent with a payload - AgentCore Runtime entry point
    """
    user_input = payload.get("prompt", "こんにちは")
    print(f"User input: {user_input}")
    response = agent(user_input)
    result = response.message['content'][0]['text']
    print(f"Agent response: {result}")
    return result

if __name__ == "__main__":
    app.run()
