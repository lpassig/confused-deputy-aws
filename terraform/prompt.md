### Terraform
I would like to create following resources on HashiCorp Cloud and AWS using Terraform. 
1. Create a first teraform module with following resources:
- Create an HVN network on HCP. This would be used to setup VPC peering connection with AWS VPC. Ensure the HVN CIDR does not overlap with AWS VPC CIDR.
- Create HCP Vault cluster with "Plus" edition. Output the vault cluster admin token.
- Output necessary values to be consumed by other modules.
2. Create a second terraform module with following resources:
- VPC with private and public subnets in us-east-1 region.
- Setup VPC peering between AWS VPC and HCP HVN
- Output necessary values to be consumed by other modules.
3. Create third module with following resources:
- AWS DocumentDB using "t3.medium" instance size. The username and password should be read from terraform variables.
- Security group allowing inbound connection to DocumentDB endpoints and port from any resources in HVN and AWS VPC network cidr.   
- Output necessary values
4. Create fourth module with following resources:
- Bastion host based on Ubuntu in a public subnet
- Bastion host size should be "t3.medium"
- SSH private/public keypair with private key downloaded in the current folder
- Security groups allowing inbound SSH connection from internet
- DocumentDB should allow inbound connection from the bastion host
- Output necessary values

I would also like to create "products" collection in the DocumentDB "test" database.
Ensure all the terraform resources configurations are valid. Do not make up your own configurations. 

Could you also create a prefix with a random 3 chars random suffix for each terraform resource. The prefix should be loaded from terraform variables.

### products-mcp
Create a new python project that implements an MCP server using fastmcp package as below:
- Create a class with methods to perform operations against AWS DocumentDB "products" collection. The product contains name, price and auto-generated _id. Create a Pydantic model class for the Product.  Below methods should be implemented:
  - List all products
  - Search product by name
  - Create a new product
  - Delete product by ID
  - Update product by ID
  - Sort products by price
- Create a DB utility to manage MongoDB connections. The Product service class should use this utility to get the database connection.
- Create a FastMCP server with MCP tool methods. A tool method should be created for each product service method to list products, create/update/delete a  product, search products by name and sort products by price.
- The tool methods should return structured output.
- Generate appropriate tool descriptions, args and docstring so that LLM agents would know which tool to invoke based on the tool descriptions.
- Create a plan first with step by step tasks, review the steps and then create necessary files. 
- Use python version >= 3.12.8