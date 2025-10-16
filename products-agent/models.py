from strands.models import BedrockModel
import os

class MockBedrockModel:
    """Mock Bedrock model for testing when Bedrock access is not available."""
    
    def __init__(self, model_id="mock-model", temperature=0.1, region_name="eu-central-1"):
        self.model_id = model_id
        self.temperature = temperature
        self.region_name = region_name
    
    def invoke(self, messages, **kwargs):
        """Mock invoke method that returns a simple response."""
        if isinstance(messages, str):
            prompt = messages
        else:
            # Extract the last user message
            prompt = messages[-1].get('content', '') if messages else 'Hello'
        
        # Simple mock response based on the prompt
        if 'product' in prompt.lower():
            return "I can help you with product management! Here are some products I found: Laptop ($999), Phone ($699), Tablet ($499)."
        elif 'list' in prompt.lower():
            return "Here's a list of available products:\n1. Laptop - $999\n2. Phone - $699\n3. Tablet - $499"
        else:
            return f"Hello! I'm a mock AI assistant. You asked: '{prompt}'. I'm here to help with product management queries!"

def get_bedrock_model():
    # Check if we should use mock model (when Bedrock access is not available)
    use_mock = os.getenv("USE_MOCK_MODEL", "false").lower() == "true"
    
    if use_mock:
        return MockBedrockModel(
            model_id=os.getenv("BEDROCK_MODEL_ID", "mock-model"),
            temperature=float(os.getenv("BEDROCK_TEMPERATURE", 0.1)),
            region_name=os.getenv("BEDROCK_REGION", "eu-central-1"),
        )
    else:
        bedrock_model = BedrockModel(
            model_id=os.getenv("BEDROCK_MODEL_ID", "anthropic.claude-3-5-sonnet-20240620-v1:0"),
            temperature=float(os.getenv("BEDROCK_TEMPERATURE", 0.1)),
            region_name=os.getenv("BEDROCK_REGION", "eu-central-1"),
        )
        return bedrock_model
