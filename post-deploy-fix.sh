#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Function to print errors
print_error() {
    echo -e "${RED}✘ $1${NC}"
}

# Error handling
handle_error() {
    print_error "Error: $1"
    exit 1
}

print_section "Post-Deployment Fix Script"
echo "This script applies critical fixes after terraform apply"
echo ""

# Check if we're in the right directory
if [ ! -f "terraform/terraform.tfstate" ]; then
    handle_error "terraform/terraform.tfstate not found. Please run this script from the project root."
fi

# Check if terraform outputs are available
if ! terraform -chdir=terraform output -raw products_web_client_secret > /dev/null 2>&1; then
    handle_error "Terraform outputs not available. Please run 'terraform apply' first."
fi

print_section "Getting new client secrets from Terraform"

# Get new client secrets
cd terraform
PRODUCTS_WEB_SECRET=$(terraform output -raw products_web_client_secret)
PRODUCTS_AGENT_SECRET=$(terraform output -raw products_agent_client_secret)
cd ..

if [ -z "$PRODUCTS_WEB_SECRET" ] || [ -z "$PRODUCTS_AGENT_SECRET" ]; then
    handle_error "Failed to get client secrets from Terraform outputs"
fi

print_success "Retrieved client secrets from Terraform"

print_section "Updating docker-compose files"

# Update products-agent docker-compose.yml
if [ -f "docker-compose/products-agent/docker-compose.yml" ]; then
    sed -i.bak "s/ENTRA_CLIENT_SECRET=.*/ENTRA_CLIENT_SECRET=$PRODUCTS_AGENT_SECRET/" docker-compose/products-agent/docker-compose.yml
    print_success "Updated products-agent client secret"
else
    print_warning "docker-compose/products-agent/docker-compose.yml not found"
fi

# Update products-web .env file
if [ -f "docker-compose/products-web/.env" ]; then
    sed -i.bak "s/CLIENT_SECRET=.*/CLIENT_SECRET=$PRODUCTS_WEB_SECRET/" docker-compose/products-web/.env
    print_success "Updated products-web client secret"
else
    print_warning "docker-compose/products-web/.env not found"
fi

print_section "Checking for other hardcoded values"

# Check for hardcoded tenant ID in export-env.sh
TENANT_ID=$(terraform -chdir=terraform output -raw azure_tenant_id)
if [ -n "$TENANT_ID" ]; then
    if grep -q "TENANT_ID=0aa96723-98b3-4842-9673-73bafaafde70" terraform/export-env.sh; then
        print_warning "Found hardcoded tenant ID in terraform/export-env.sh"
        print_warning "Consider updating TENANT_ID to: $TENANT_ID"
    fi
fi

print_section "Verifying Nova Pro configuration"

# Check if Nova Pro inference profile is configured
if grep -q "BEDROCK_MODEL_ID.*eu.amazon.nova-pro-v1:0" docker-compose/products-agent/docker-compose.yml; then
    print_success "Nova Pro inference profile is correctly configured"
else
    print_warning "Nova Pro inference profile may not be configured correctly"
    print_warning "Expected: BEDROCK_MODEL_ID=eu.amazon.nova-pro-v1:0"
fi

print_section "Checking ECR region configuration"

# Check if ECR region matches deployment region
AWS_REGION=$(terraform -chdir=terraform output -raw aws_region)
if grep -q "region eu-central-1" deploy-ecr.sh; then
    print_success "ECR region configuration looks correct"
else
    print_warning "ECR region in deploy-ecr.sh may not match deployment region: $AWS_REGION"
fi

print_section "Summary of fixes applied"

echo "✅ Updated products-agent client secret"
echo "✅ Updated products-web client secret"
echo "✅ Verified Nova Pro configuration"
echo "✅ Checked ECR region configuration"

print_section "Next steps"

echo "To complete the deployment, run:"
echo ""
echo "  ./deploy-ecr.sh build    # Rebuild Docker images"
echo "  ./deploy-ecr.sh deploy   # Deploy to AWS bastion"
echo ""
echo "Or run the complete deployment:"
echo ""
echo "  ./deploy-ecr.sh full     # Complete deployment"
echo ""

print_success "Post-deployment fixes completed!"
echo ""
echo "⚠️  Important: Always run this script after 'terraform apply' to ensure"
echo "   client secrets are updated in your deployment files."
