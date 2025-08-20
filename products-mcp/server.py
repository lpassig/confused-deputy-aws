"""
FastMCP server for AWS DocumentDB product operations.

This module implements the MCP server with tool methods for all product operations
including CRUD operations, search, and sorting functionality.
"""

import asyncio
import logging
from typing import Optional

from fastmcp import FastMCP
from fastmcp.server.dependencies import get_http_headers

from config import get_config
from db_utils import get_db_manager
from models import Product, ProductListResponse, ProductResponse
from product_service import ProductService
from jwt_verifier import get_jwt_verifier, get_jwt_token_from_header

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize configuration
config = get_config()

# Create FastMCP server instance
mcp = FastMCP("products-mcp", version="1.0.0", auth=get_jwt_verifier())
# mcp = FastMCP("products-mcp", version="1.0.0")

# Initialize product service
product_service = ProductService()


async def get_jwt_token_from_header(headers: dict) -> str:
    # Get authorization header
    auth_header = headers.get("authorization", "")
    is_bearer = auth_header.startswith("Bearer ")
    jwt_token = auth_header.split(" ")[1] if is_bearer else ""
    return jwt_token


@mcp.tool()
async def list_products(limit: Optional[int] = 10) -> ProductListResponse:
    """
    List all products from the database.

    This tool retrieves all products stored. You can optionally
    limit the number of results returned. Use this tool when you need to see
    all available products or get a general overview of the product catalog.

    Example response:
        {
            "success": true,
            "message": "Product retrieved successfully",
            "products": [
                {
                    "id": "P12345",
                    "name": "Ultra Comfort Running Shoes",
                    "price": 89.99,
                },
            ],
            "count": 1
        }
    Args:
        limit: Maximum number of products to return. Default is 10, maximum is 100.

    Returns:
        ProductListResponse: Products list containing:
        - success (bool): Operation success status
        - message (string): Operation result message
        - products (list): List of product details
        - count (int): Number of products returned
    """
    try:
        logger.info(f"Listing products with limit: {limit}")
        # JWT token has been verified by FastMCP JWTVerifier before reaching this point
        jwt_token = await get_jwt_token_from_header(get_http_headers())

        product_service = ProductService(jwt_token=jwt_token)
        products = await product_service.list_all_products(limit)

        return ProductListResponse(
            success=True,
            message=f"Successfully retrieved {len(products)} products",
            products=products,
            count=len(products),
        )

    except Exception as e:
        logger.error(f"Error listing products: {e}")
        return ProductListResponse(
            success=False,
            message="Failed to list products",
            products=[],
            count=0,
        )


@mcp.tool()
async def search_products(name: str, exact_match: bool = False) -> ProductListResponse:
    """
    Search for products by name.

    This tool searches for products based on their name. It supports both exact
    and partial matching with case-insensitive search. Use this tool when you need
    to find specific products by name or find products whose names contain certain text.

    Example response:
        {
            "success": true,
            "message": "Product retrieved successfully",
            "products": [
                {
                    "id": "P12345",
                    "name": "Ultra Comfort Running Shoes",
                    "price": 89.99,
                },
            ],
            "count": 1
        }
    Args:
        name: Product name to search for
        exact_match: If True, search for exact match; otherwise, partial match. Default value is False.

    Returns:
        ProductListResponse: Products list containing:
        - success (bool): Operation success status
        - message (string): Operation result message
        - products (list): List of product details
        - count (int): Number of products returned
    """
    try:
        logger.info(f"Searching products by name: '{name}' (exact={exact_match})")
        # JWT token has been verified by FastMCP JWTVerifier before reaching this point
        jwt_token = await get_jwt_token_from_header(get_http_headers())

        product_service = ProductService(jwt_token=jwt_token)
        products = await product_service.search_by_name(
            name=name, exact_match=exact_match
        )

        match_type = "exact" if exact_match else "partial"
        message = (
            f"Found {len(products)} products matching '{name}' ({match_type} match)"
        )

        return ProductListResponse(
            success=True, message=message, products=products, count=len(products)
        )

    except ValueError as e:
        logger.error(f"Invalid search parameters: {e}")
        return ProductListResponse(
            success=False,
            message="Invalid search parameters",
            products=[],
            count=0,
        )
    except Exception as e:
        logger.error(f"Error searching products: {e}")
        return ProductListResponse(
            success=False,
            message="Failed to search products",
            products=[],
            count=0,
        )


@mcp.tool()
async def create_product(product: Product) -> ProductResponse:
    """
    Create a new product.

    This tool creates a new product with the specified name and price.
    Product names must be unique (case-insensitive). The product will be assigned
    an auto-generated ID. Use this tool when you need to add new
    products to the catalog.

    Example input:
        {
            "name": "Ultra Comfort Running Shoes",
            "price": 89.99
        }

    Example response:
        {
            "success": true,
            "message": "Product created successfully",
            "data": {
                "id": "P12345",
                "name": "Ultra Comfort Running Shoes",
                "price": 89.99,
            }
        }

    Args:
        product (Product): A JSON object containing the product's details.
            - 'name' (str): The product's name.
            - 'price' (float): The product's price.
    Returns:
        ProductResponse: A product object containing:
        - 'success' (bool): Indicates if the product creation was successful.
        - 'message' (str): A message describing the result of the operation.
        - 'data' (dict): The created product's details, including:
            - 'id' (str): The product's unique identifier.
            - 'name' (str): The product's name.
            - 'price' (float): The product's price.
    """
    try:
        logger.info(f"Creating product: {product.name} (${product.price})")
        # JWT token has been verified by FastMCP JWTVerifier before reaching this point
        jwt_token = await get_jwt_token_from_header(get_http_headers())

        product_service = ProductService(jwt_token=jwt_token)
        product_data = Product(name=product.name, price=product.price)
        created_product = await product_service.create_product(product_data)

        return ProductResponse(
            success=True,
            message=f"Successfully created product '{created_product.name}' with ID {created_product.id}",
            data={
                "id": str(created_product.id),
                "name": created_product.name,
                "price": created_product.price,
            },
        )

    except Exception as e:
        error_msg = str(e)
        if "already exists" in error_msg.lower():
            logger.error(f"Product name conflict: {e}")
            return ProductResponse(
                success=False,
                message="Product name already exists",
            )
        else:
            logger.error(f"Error creating product: {e}")
            return ProductResponse(
                success=False, message="Failed to create product", error=str(e)
            )


@mcp.tool()
async def update_product(product_id: str, product: Product) -> ProductResponse:
    """
    Update an existing product.

    This tool updates a product's name and/or price. Product names must remain unique (case-insensitive).
    Use this tool when you need to modify existing product information.

    Example input:
        product_id (str): "P12345"
        product (Product):
            {
                "name": "Ultra Comfort Running Shoes",
                "price": 89.99
            }

    Example response:
        {
            "success": true,
            "message": "Product created successfully",
        }

    Args:
        product_id (str): Product ID to update
        product (Product): A JSON object containing the product's details.
            - 'name' (str): The product's name.
            - 'price' (float): The product's price.

    Returns:
        ProductResponse: A product object containing:
        - 'success' (bool): Indicates if the product creation was successful.
        - 'message' (str): A message describing the result of the operation.

    """
    try:
        logger.info(f"Updating product {product} with ID: {product_id}")
        # JWT token has been verified by FastMCP JWTVerifier before reaching this point
        jwt_token = await get_jwt_token_from_header(get_http_headers())

        product_service = ProductService(jwt_token=jwt_token)
        # Validate required fields
        if not product_id or not product_id.strip():
            return ProductResponse(
                success=False, message="Product ID is required for updates"
            )

        if not product.name or not product.name.strip():
            return ProductResponse(
                success=False,
                message="Product name is required and cannot be empty",
            )

        if product.price is None or product.price < 0:
            return ProductResponse(
                success=False,
                message="Product price must be a non-negative number",
            )

        updated_product = await product_service.update_product_by_id(
            product_id=product_id, update_product=product
        )

        if updated_product is None:
            return ProductResponse(
                success=False,
                message="Product not found",
            )

        return ProductResponse(success=True, message="Product updated successfully")

    except ValueError as e:
        logger.error(f"Invalid product ID or data: {e}")
        return ProductResponse(
            success=False, message=f"Invalid input parameters: {str(e)}"
        )
    except Exception as e:
        error_msg = str(e)
        if "already exists" in error_msg.lower():
            logger.error(f"Product name conflict during update: {e}")
            return ProductResponse(
                success=False,
                message=f"Product name {product.name} already exists",
            )
        else:
            logger.error(f"Error updating product: {e}")
            return ProductResponse(
                success=False, message=f"Failed to update product {str(e)}"
            )


@mcp.tool()
async def delete_product(product_id: str) -> ProductResponse:
    """
    Delete a product by ID.

    This tool permanently deletes a product from the database using its ID.
    The operation cannot be undone. Use this tool when you need to remove products
    that are no longer needed or were created in error.

    Example response:
        {
            "success": true,
            "message": "Successfully deleted product with ID 'P12345'",
        }

    Args:
        product_id (str): Product ID to delete

    Returns:
        ProductResponse: Response indicating success or failure containing:
        - 'success' (bool): Indicates if the product deletion was successful.
        - 'message' (str): Describes the result of the operation.
    """
    try:
        logger.info(f"Deleting product ID: {product_id}")
        # JWT token has been verified by FastMCP JWTVerifier before reaching this point
        jwt_token = await get_jwt_token_from_header(get_http_headers())

        product_service = ProductService(jwt_token=jwt_token)
        deleted = await product_service.delete_product_by_id(product_id)

        if deleted:
            return ProductResponse(
                success=True,
                message=f"Successfully deleted product with ID '{product_id}'",
            )
        else:
            return ProductResponse(
                success=False,
                message=f"Product with ID '{product_id}' not found",
            )

    except ValueError as e:
        logger.error(f"Invalid product ID: {e}")
        return ProductResponse(success=False, message=f"Invalid product ID: {str(e)}")
    except Exception as e:
        logger.error(f"Error deleting product: {e}")
        return ProductResponse(
            success=False, message=f"Failed to delete product: {str(e)}"
        )


# @mcp.tool()
# async def get_product(args: GetProductArgs) -> ProductResponse:
#     """
#     Get a single product by ID.

#     This tool retrieves detailed information about a specific product using its
#     MongoDB ObjectId. Use this tool when you need to view complete details
#     of a specific product.

#     Args:
#         args: Arguments containing product ID to retrieve

#     Returns:
#         ProductResponse: Response with product data and success status
#     """
#     try:
#         logger.info(f"Getting product ID: {args.product_id}")

#         product = await product_service.get_product_by_id(args.product_id)

#         if product is None:
#             return ProductResponse(
#                 success=False,
#                 message="Product not found",
#                 error=f"No product found with ID '{args.product_id}'",
#             )

#         return ProductResponse(
#             success=True,
#             message=f"Successfully retrieved product '{product.name}'",
#             data={"id": str(product.id), "name": product.name, "price": product.price},
#         )

#     except ValueError as e:
#         logger.error(f"Invalid product ID: {e}")
#         return ProductResponse(
#             success=False, message="Invalid product ID", error=str(e)
#         )
#     except Exception as e:
#         logger.error(f"Error getting product: {e}")
#         return ProductResponse(
#             success=False, message="Failed to retrieve product", error=str(e)
#         )


@mcp.tool()
async def sort_products_by_price(
    ascending: bool = True, limit: Optional[int] = 10
) -> ProductListResponse:
    """
    Sort products by price.

    This tool retrieves products sorted by their price in either ascending (low to high)
    or descending (high to low) order. You can optionally limit the number of results.
    Use this tool when you need to find the cheapest/most expensive products or
    analyze price distribution.

    Example response:
        {
            "success": true,
            "message": "Products sorted successfully",
            "products": [
                {
                    "id": "P12345",
                    "name": "Ultra Comfort Running Shoes",
                    "price": 89.99,
                },
            ],
            "count": 1
        }

    Args:
        ascending (bool): If True, sort ascending; otherwise, descending. Default is True.
        limit (Optional[int]): Maximum number of products to return, default is 10.

    Returns:
        ProductListResponse: Products list containing:
        - success (bool): Operation success status
        - message (string): Operation result message
        - products (list): List of product details sorted by price in ascending/descending order
        - count (int): Number of products returned
    """
    try:
        logger.info(f"Sorting products by price (ascending={ascending}, limit={limit})")
        # JWT token has been verified by FastMCP JWTVerifier before reaching this point
        jwt_token = await get_jwt_token_from_header(get_http_headers())

        product_service = ProductService(jwt_token=jwt_token)
        products = await product_service.sort_products_by_price(
            ascending=ascending, limit=limit
        )

        sort_direction = (
            "ascending (low to high)" if ascending else "descending (high to low)"
        )
        message = f"Successfully retrieved {len(products)} products sorted by price ({sort_direction})"

        return ProductListResponse(
            success=True, message=message, products=products, count=len(products)
        )

    except Exception as e:
        logger.error(f"Error sorting products: {e}")
        return ProductListResponse(
            success=False,
            message=f"Failed to sort products by price: {e}",
            products=[],
            count=0,
        )


async def main():
    """
    Run the MCP server.

    This function starts the FastMCP server and handles graceful shutdown.
    """
    try:
        logger.info("Starting Products MCP Server...")
        logger.info(f"Server configuration: {config.get_server_info()}")
        # logger.info(f"Database configuration: {config.get_database_info()}")

        # Test database connection on startup
        # test_db_connection()

        # Run the MCP server
        await mcp.run_async(
            transport="streamable-http",
            host=config.server_host,
            port=config.server_port,
        )

    except KeyboardInterrupt:
        logger.info("Shutting down server...")
    except Exception as e:
        logger.error(f"Server error: {e}")
        raise
    finally:
        # Clean up database connections
        get_db_manager().close_all_connections()
        logger.info("Server shutdown complete")


if __name__ == "__main__":
    asyncio.run(main())
