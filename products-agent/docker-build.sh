#!/bin/bash

# =============================================================================
# Multi-Architecture Docker Build Script for products-agent
# 
# This script builds Docker images for multiple architectures (arm64, amd64)
# using Docker Buildx. It supports development and production builds with
# optional push to registry.
#
# Usage:
#   ./docker-build.sh [OPTIONS]
#
# Examples:
#   ./docker-build.sh                                    # Build production for local platform
#   ./docker-build.sh --dev                              # Build development image
#   ./docker-build.sh --multi-arch                       # Build for arm64 and amd64
#   ./docker-build.sh --push --registry your-registry    # Build and push to registry
#   ./docker-build.sh --tag v1.0.0 --push               # Build with custom tag and push
# =============================================================================

set -euo pipefail

# Default configuration
IMAGE_NAME="products-agent"
TAG="latest"
REGISTRY=""
BUILD_TARGET="production"
PLATFORMS="linux/amd64"
PUSH=false
LOAD=true
BUILD_ARGS=""
DOCKERFILE="Dockerfile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Display usage information
usage() {
    cat << EOF
Multi-Architecture Docker Build Script for products-agent

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -t, --tag TAG           Tag for the image (default: latest)
    -r, --registry URL      Registry URL (e.g., docker.io/username)
    -n, --name NAME         Image name (default: products-agent)
    --dev                   Build development image
    --prod                  Build production image (default)
    --multi-arch            Build for multiple architectures (arm64, amd64)
    --arm64                 Build for ARM64 architecture only
    --amd64                 Build for AMD64 architecture only
    --push                  Push image to registry after build
    --no-load               Don't load image to local Docker (useful with --push)
    --build-arg ARG=VALUE   Pass build argument to Docker
    --dockerfile FILE       Use custom Dockerfile (default: Dockerfile)
    --dry-run               Show commands without executing

EXAMPLES:
    $0                              # Build production for current platform
    $0 --dev                        # Build development image
    $0 --multi-arch --push          # Build and push multi-arch production image
    $0 --tag v1.0.0 --registry myregistry.com/myproject
    $0 --arm64 --dev                # Build development image for ARM64
    $0 --build-arg PYTHON_VERSION=3.12 --prod

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -t|--tag)
                TAG="$2"
                shift 2
                ;;
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ;;
            -n|--name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            --dev)
                BUILD_TARGET="development"
                shift
                ;;
            --prod)
                BUILD_TARGET="production"
                shift
                ;;
            --multi-arch)
                PLATFORMS="linux/amd64,linux/arm64"
                LOAD=false
                shift
                ;;
            --arm64)
                PLATFORMS="linux/arm64"
                shift
                ;;
            --amd64)
                PLATFORMS="linux/amd64"
                shift
                ;;
            --push)
                PUSH=true
                shift
                ;;
            --no-load)
                LOAD=false
                shift
                ;;
            --build-arg)
                BUILD_ARGS="$BUILD_ARGS --build-arg $2"
                shift 2
                ;;
            --dockerfile)
                DOCKERFILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check if Dockerfile exists
    if [[ ! -f "$DOCKERFILE" ]]; then
        print_error "Dockerfile not found: $DOCKERFILE"
        exit 1
    fi
    
    # Check if buildx is available for multi-arch builds
    if [[ "$PLATFORMS" == *","* ]] && ! docker buildx version &> /dev/null; then
        print_error "Docker Buildx is required for multi-architecture builds"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Setup Docker buildx for multi-architecture builds
setup_buildx() {
    if [[ "$PLATFORMS" == *","* ]]; then
        print_info "Setting up Docker Buildx for multi-architecture builds..."
        
        # Create or use existing buildx builder
        if ! docker buildx ls | grep -q "products-agent-builder"; then
            print_info "Creating new buildx builder: products-agent-builder"
            docker buildx create --name products-agent-builder --driver docker-container --bootstrap
        fi
        
        # Use the builder
        docker buildx use products-agent-builder
        print_success "Buildx setup complete"
    fi
}

# Build the Docker image
build_image() {
    local full_image_name
    
    # Construct full image name
    if [[ -n "$REGISTRY" ]]; then
        full_image_name="$REGISTRY/$IMAGE_NAME:$TAG"
    else
        full_image_name="$IMAGE_NAME:$TAG"
    fi
    
    print_info "Building Docker image..."
    print_info "Image name: $full_image_name"
    print_info "Target: $BUILD_TARGET"
    print_info "Platforms: $PLATFORMS"
    print_info "Dockerfile: $DOCKERFILE"
    
    # Construct Docker build command
    local docker_cmd="docker"
    if [[ "$PLATFORMS" == *","* ]]; then
        docker_cmd="docker buildx"
    fi
    
    local build_cmd="$docker_cmd build"
    build_cmd="$build_cmd --platform $PLATFORMS"
    build_cmd="$build_cmd --target $BUILD_TARGET"
    build_cmd="$build_cmd --tag $full_image_name"
    build_cmd="$build_cmd --file $DOCKERFILE"
    
    # Add build arguments
    if [[ -n "$BUILD_ARGS" ]]; then
        build_cmd="$build_cmd $BUILD_ARGS"
    fi
    
    # Add push flag if requested
    if [[ "$PUSH" == true ]]; then
        build_cmd="$build_cmd --push"
        LOAD=false  # Cannot load when pushing multi-arch
    fi
    
    # Add load flag if requested (only for single platform)
    if [[ "$LOAD" == true && "$PLATFORMS" != *","* ]]; then
        build_cmd="$build_cmd --load"
    fi
    
    # Add context (current directory)
    build_cmd="$build_cmd ."
    
    print_info "Executing: $build_cmd"
    
    # Execute or show command
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_warning "DRY RUN - Command would be:"
        echo "$build_cmd"
    else
        eval "$build_cmd"
        print_success "Build completed successfully"
        
        # Show image info if loaded locally
        if [[ "$LOAD" == true && "$PLATFORMS" != *","* ]]; then
            print_info "Image information:"
            docker images "$full_image_name" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
        fi
    fi
}

# Main function
main() {
    print_info "Starting multi-architecture Docker build for products-agent"
    
    parse_args "$@"
    check_prerequisites
    setup_buildx
    build_image
    
    print_success "Build process completed!"
    
    if [[ "$PUSH" == true ]]; then
        print_success "Image pushed to registry successfully"
    fi
    
    if [[ "$PLATFORMS" == *","* ]]; then
        # Construct full image name for display
        local display_image_name
        if [[ -n "$REGISTRY" ]]; then
            display_image_name="$REGISTRY/$IMAGE_NAME:$TAG"
        else
            display_image_name="$IMAGE_NAME:$TAG"
        fi
        print_info "Multi-architecture images built for: $PLATFORMS"
        print_info "Use 'docker buildx imagetools inspect $display_image_name' to view manifest"
    fi
}

# Run main function with all arguments
main "$@"
