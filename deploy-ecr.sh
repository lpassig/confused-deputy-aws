#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

# Function to print warnings
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Error handling
handle_error() {
    echo -e "\033[0;31m✘ Error: $1\033[0m"
    exit 1
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        handle_error "AWS CLI is not installed. Please install it first."
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        handle_error "Docker is not installed. Please install it first."
    fi
}

# Login to ECR
ecr_login() {
    print_section "Logging into Amazon ECR"
    
    # Get AWS region
    AWS_REGION=$(aws configure get region)
    if [ -z "$AWS_REGION" ]; then
        AWS_REGION="us-east-1"  # Default region
        print_warning "No AWS region configured, using us-east-1"
    fi
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        handle_error "Failed to get AWS account ID. Please check your AWS credentials."
    fi
    
    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    print_section "Logging into ECR registry: ${ECR_REGISTRY}"
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
    
    if [ $? -eq 0 ]; then
        print_success "Successfully logged into ECR"
        echo "ECR_REGISTRY=${ECR_REGISTRY}"
    else
        handle_error "Failed to login to ECR"
    fi
}

# Build and push images
build_and_push_images() {
    print_section "Building and pushing Docker images to ECR"
    
    # Get ECR registry URL from Terraform output
    cd terraform
    ECR_REGISTRY_URL=$(terraform output -raw ecr_registry_url)
    ECR_PRODUCTS_WEB_REPO=$(terraform output -raw ecr_products_web_repository_url)
    ECR_PRODUCTS_AGENT_REPO=$(terraform output -raw ecr_products_agent_repository_url)
    ECR_PRODUCTS_MCP_REPO=$(terraform output -raw ecr_products_mcp_repository_url)
    cd ..
    
    if [ -z "$ECR_REGISTRY_URL" ]; then
        handle_error "Failed to get ECR registry URL from Terraform. Make sure Terraform has been applied."
    fi
    
    print_section "Building and pushing products-web"
    cd products-web
    docker build --platform linux/amd64 --target production -t ${ECR_PRODUCTS_WEB_REPO}:latest .
    if [ $? -ne 0 ]; then
        handle_error "Failed to build products-web image"
    fi
    docker push ${ECR_PRODUCTS_WEB_REPO}:latest
    if [ $? -ne 0 ]; then
        handle_error "Failed to push products-web image"
    fi
    print_success "products-web pushed to ECR"
    cd ..
    
    print_section "Building and pushing products-agent"
    cd products-agent
    docker build --platform linux/amd64 --target production -t ${ECR_PRODUCTS_AGENT_REPO}:latest .
    if [ $? -ne 0 ]; then
        handle_error "Failed to build products-agent image"
    fi
    docker push ${ECR_PRODUCTS_AGENT_REPO}:latest
    if [ $? -ne 0 ]; then
        handle_error "Failed to push products-agent image"
    fi
    print_success "products-agent pushed to ECR"
    cd ..
    
    print_section "Building and pushing products-mcp"
    cd products-mcp
    docker build --platform linux/amd64 -t ${ECR_PRODUCTS_MCP_REPO}:latest .
    if [ $? -ne 0 ]; then
        handle_error "Failed to build products-mcp image"
    fi
    docker push ${ECR_PRODUCTS_MCP_REPO}:latest
    if [ $? -ne 0 ]; then
        handle_error "Failed to push products-mcp image"
    fi
    print_success "products-mcp pushed to ECR"
    cd ..
    
    print_success "All images successfully pushed to ECR!"
}

# Deploy to AWS bastion
deploy_to_aws() {
    print_section "Deploying to AWS bastion host"
    
    # Get bastion connection info
    cd terraform
    BASTION_IP=$(terraform output -raw bastion_public_ip)
    SSH_KEY_PATH=$(terraform output -raw bastion_ssh_key_path)
    SSH_KEY=$(realpath $SSH_KEY_PATH)
    cd ..
    
    if [ -z "$BASTION_IP" ] || [ -z "$SSH_KEY" ]; then
        handle_error "Failed to get bastion connection info from Terraform"
    fi
    
    print_section "Connecting to bastion host: ${BASTION_IP}"
    
    # Copy docker-compose files and environment files to bastion
    print_section "Copying files to bastion host"
    scp -i ${SSH_KEY} -r docker-compose ubuntu@${BASTION_IP}:~/
    
    # SSH into bastion and run deployment
    print_section "Deploying services on bastion host"
    ssh -i ${SSH_KEY} ubuntu@${BASTION_IP} << EOF
        cd docker-compose
        
        # Install AWS CLI if not present
        if ! command -v aws &> /dev/null; then
            echo "Installing AWS CLI..."
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf awscliv2.zip aws/
        fi
        
        # Login to ECR (non-interactive)
        AWS_ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
        aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin \${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com
        
        # Set environment variables for docker-compose
        export tag=latest
        export platform=linux/amd64
        export target=""
        export ECR_REGISTRY_URL=${ECR_REGISTRY_URL}
        export ECR_PRODUCTS_WEB_REPO=${ECR_PRODUCTS_WEB_REPO}
        export ECR_PRODUCTS_AGENT_REPO=${ECR_PRODUCTS_AGENT_REPO}
        export ECR_PRODUCTS_MCP_REPO=${ECR_PRODUCTS_MCP_REPO}
        export BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID:-anthropic.claude-3-5-sonnet-20240620-v1:0}
        export BEDROCK_TEMPERATURE=${BEDROCK_TEMPERATURE:-0.1}
        export BEDROCK_REGION=${BEDROCK_REGION:-eu-central-1}
        
        # Pull and start services
        docker compose pull
        docker compose up -d
        
        echo "Services deployed successfully!"
        docker compose ps
EOF
    
    if [ $? -ne 0 ]; then
        handle_error "Failed to deploy services on bastion host"
    fi
    
    print_success "Deployment completed!"
}

# Help message
show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  login       - Login to Amazon ECR"
    echo "  build       - Build and push all images to ECR"
    echo "  deploy      - Deploy services to AWS bastion host"
    echo "  full        - Complete deployment (login + build + deploy)"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 login                    # Login to ECR"
    echo "  $0 build                   # Build and push images"
    echo "  $0 deploy                  # Deploy to AWS"
    echo "  $0 full                    # Complete deployment"
}

# Main script logic
case "$1" in
    "login")
        check_aws_cli
        check_docker
        ecr_login
        ;;
    "build")
        check_aws_cli
        check_docker
        ecr_login
        build_and_push_images
        ;;
    "deploy")
        check_aws_cli
        deploy_to_aws
        ;;
    "full")
        check_aws_cli
        check_docker
        ecr_login
        build_and_push_images
        deploy_to_aws
        ;;
    "help"|*)
        show_help
        ;;
esac
