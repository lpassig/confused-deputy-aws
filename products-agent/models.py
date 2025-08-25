from strands.models import BedrockModel

# from strands.models.openai import OpenAIModel
import os


# def get_openai_model():
#     """Initializes and returns an OpenAIModel instance."""
#     return OpenAIModel(
#         model_id="gpt-4o-mini",
#         params={
#             "temperature": 0.1,
#         },
#     )


def get_bedrock_model():
    bedrock_model = BedrockModel(
        model_id=os.getenv("BEDROCK_MODEL_ID", "apac.amazon.nova-pro-v1:0"),
        temperature=float(os.getenv("BEDROCK_TEMPERATURE", 0.1)),
        region_name=os.getenv("BEDROCK_REGION", "ap-southeast-1"),
    )
    return bedrock_model
