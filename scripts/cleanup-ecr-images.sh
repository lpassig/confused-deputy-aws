#!/bin/bash

# Script to clean up ECR repositories before Terraform destroy
# This prevents "RepositoryNotEmptyException" errors during terraform destroy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install it first."
    exit 1
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

print_status "AWS Account ID: $AWS_ACCOUNT_ID"
print_status "AWS Region: $AWS_REGION"

# Function to delete all images from an ECR repository
delete_ecr_images() {
    local repo_name=$1
    
    print_status "Cleaning up ECR repository: $repo_name"
    
    # Check if repository exists
    if ! aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" &> /dev/null; then
        print_warning "Repository $repo_name does not exist, skipping..."
        return 0
    fi
    
    # Get all image tags
    local image_tags=$(aws ecr list-images --repository-name "$repo_name" --region "$AWS_REGION" --query 'imageIds[].imageTag' --output text)
    
    if [ -z "$image_tags" ] || [ "$image_tags" = "None" ]; then
        print_status "No images found in repository $repo_name"
        return 0
    fi
    
    print_status "Found images in $repo_name: $image_tags"
    
    # Delete all images
    aws ecr batch-delete-image \
        --repository-name "$repo_name" \
        --region "$AWS_REGION" \
        --image-ids imageTag="$image_tags" \
        --output table
    
    print_status "Successfully deleted all images from $repo_name"
}

# Function to delete all untagged images from an ECR repository
delete_untagged_images() {
    local repo_name=$1
    
    print_status "Cleaning up untagged images from: $repo_name"
    
    # Check if repository exists
    if ! aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" &> /dev/null; then
        print_warning "Repository $repo_name does not exist, skipping..."
        return 0
    fi
    
    # Get all untagged images
    local untagged_images=$(aws ecr list-images --repository-name "$repo_name" --region "$AWS_REGION" --filter tagStatus=UNTAGGED --query 'imageIds[].imageDigest' --output text)
    
    if [ -z "$untagged_images" ] || [ "$untagged_images" = "None" ]; then
        print_status "No untagged images found in repository $repo_name"
        return 0
    fi
    
    print_status "Found untagged images in $repo_name: $untagged_images"
    
    # Delete untagged images
    aws ecr batch-delete-image \
        --repository-name "$repo_name" \
        --region "$AWS_REGION" \
        --image-ids imageDigest="$untagged_images" \
        --output table
    
    print_status "Successfully deleted untagged images from $repo_name"
}

# Main cleanup function
cleanup_ecr_repositories() {
    local name_prefix=${1:-"ai-l0q"}
    
    print_status "Starting ECR cleanup for prefix: $name_prefix"
    
    # List of repositories to clean up
    local repositories=(
        "${name_prefix}-products-web"
        "${name_prefix}-products-agent"
        "${name_prefix}-products-mcp"
    )
    
    for repo in "${repositories[@]}"; do
        print_status "Processing repository: $repo"
        
        # Delete untagged images first
        delete_untagged_images "$repo"
        
        # Delete all tagged images
        delete_ecr_images "$repo"
        
        print_status "Completed cleanup for $repo"
        echo "---"
    done
    
    print_status "ECR cleanup completed successfully!"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [REPOSITORY_PREFIX]"
    echo ""
    echo "Arguments:"
    echo "  REPOSITORY_PREFIX    ECR repository name prefix (default: ai-l0q)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Clean up repositories with prefix 'ai-l0q'"
    echo "  $0 my-prefix          # Clean up repositories with prefix 'my-prefix'"
    echo ""
    echo "This script will:"
    echo "  1. Delete all untagged images from ECR repositories"
    echo "  2. Delete all tagged images from ECR repositories"
    echo "  3. Allow Terraform destroy to succeed without 'RepositoryNotEmptyException'"
}

# Main execution
main() {
    # Check for help flag
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Get repository prefix from argument or use default
    local repo_prefix=${1:-"ai-l0q"}
    
    print_status "ECR Repository Cleanup Script"
    print_status "=============================="
    
    # Confirm before proceeding
    echo ""
    print_warning "This will delete ALL images from ECR repositories with prefix: $repo_prefix"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled by user"
        exit 0
    fi
    
    # Perform cleanup
    cleanup_ecr_repositories "$repo_prefix"
}

# Run main function with all arguments
main "$@"
