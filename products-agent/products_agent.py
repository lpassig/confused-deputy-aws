import asyncio
import logging
import os

from mcp.client.streamable_http import streamablehttp_client
from strands import Agent
from strands.agent import AgentResult
from strands.tools.mcp.mcp_client import MCPClient
from strands.types.content import ContentBlock


from models import get_bedrock_model

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def get_system_prompt() -> str:
    # Define the system message
    system_message = """You are a helpful AI assistant for product management. You have access to tools that allow you to:
1. **list_products**: List all products from the database. This tool retrieves all products stored. You can optionally limit the number of results returned. Use this tool when you need to see all available products or get a general overview of the product catalog. 
2. **search_products**: Search for products by name. This tool searches for products based on their name. It supports both exact and partial matching with case-insensitive search. Use this tool when you need to find specific products by name or find products whose names contain certain text. 
3. **create_product**: Create a new product. This tool creates a new product with the specified name and price. Product names must be unique (case-insensitive). The product will be assigned an auto-generated ID. Use this tool when you need to add new products to the catalog.
4. **update_product**: Update an existing product. This tool updates a product's name and/or price. Product names must remain unique (case-insensitive). Use this tool when you need to modify existing product information. 
5. **delete_product**: Delete a product by ID. This tool permanently deletes a product from the database using its ID. The operation cannot be undone. Use this tool when you need to remove products that are no longer needed or were created in error. 
6. **sort_products_by_price**: Sort products by price. This tool retrieves products sorted by their price in either ascending (low to high) or descending (high to low) order. You can optionally limit the number of results. Use this tool when you need to find the cheapest/most expensive products or analyze price distribution.

You should help users with natural language queries about products. For example:
- "Show me all products" → use list_products
- "What's the price of product ABC123?" → use search_products 
- "Find all laptops" or "Search for products containing 'laptop'" → use search_products
- "Create a new laptop priced at $999" → use create_product with proper JSON
- "Update product XYZ to cost $150" → use update_product with proper JSON
- "Delete product ABC" → use delete_product

For searching, use the search_products tool when users ask for products with specific names or containing certain keywords. This is more efficient than retrieving all products and filtering.

Always be helpful and explain what you're doing. If you need clarification, ask the user for more details.

When updating or deleting products, use search_products tool first to get the product ID. Then call the appropriate tool with the product ID.
"""
    return system_message


# Default token for testing - this will be replaced by the on-behalf-of token
DEFAULT_JWT_TOKEN = None  # No default token


class ProductsAgent:
    # def __init__(self):
    #     self.mcp_client = MCPClient(
    #         lambda: streamablehttp_client(
    #             "http://localhost:8000/mcp",
    #             headers={"Authorization": "Bearer YOUR_TOKEN"},
    #         )
    #     )

    #     Create an agent with these tools
    #     self.agent = Agent(
    #         model=get_bedrock_model(),
    #         system_prompt=get_system_prompt(),
    #     )

    async def invoke(self, user_prompt: str, jwt_token: str = None) -> str:
        # Use provided token or fall back to default for testing
        token = jwt_token or DEFAULT_JWT_TOKEN

        # Load MCP URL from environment variable
        mcp_url = os.getenv("PRODUCTS_MCP_SERVER_URL", "http://localhost:8000/mcp")
        logger.info(f"MCP URL: {mcp_url}")

        mcp_client = MCPClient(
            lambda: streamablehttp_client(
                mcp_url,
                headers={"Authorization": f"Bearer {token}"},
            )
        )
        with mcp_client:
            # Get the tools from the MCP server
            tools = mcp_client.list_tools_sync()

            agent = Agent(
                model=get_bedrock_model(),
                tools=tools,
                system_prompt=get_system_prompt(),
            )

            result: AgentResult = await agent.invoke_async(user_prompt)
            if result.message and result.message["content"]:
                for msg in reversed(result.message["content"]):
                    logger.info(f"msg: {msg}")
                    if msg["text"] and msg["text"].strip():
                        return msg["text"]

            return "I apologize, but I encountered an issue processing your request. Please try again or contact support."


if __name__ == "__main__":
    user_prompt1 = "Could you please list me all products?"
    user_prompt2 = "Could you please show me the details of product matching iPad?"
    user_prompt3 = (
        "Could you please create a new product called 'Tablet' priced at $499?"
    )
    user_prompt4 = "Could you please update Bose price to $299?"
    user_prompt5 = "Could you please delete product Bose?"
    user_prompt6 = "Could you please sort all products by price in ascending order?"

    agent = ProductsAgent()
    result = asyncio.run(agent.invoke(user_prompt2))
    print(result)
