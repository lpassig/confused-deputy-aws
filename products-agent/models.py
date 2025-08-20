from strands.models import BedrockModel

# from strands.models.openai import OpenAIModel
from dotenv import load_dotenv

load_dotenv()


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
        # model_id="amazon.nova-lite-v1:0",
        model_id="amazon.nova-pro-v1:0",
        temperature=0.1,
        region_name="us-east-1",
    )
    return bedrock_model
