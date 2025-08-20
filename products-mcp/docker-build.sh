#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

# Error handling
handle_error() {
    echo -e "\033[0;31m✘ Error: $1\033[0m"
    exit 1
}

# Build for AMD64 (x86_64)
build_amd64() {
    print_section "Building for AMD64 (x86_64)"
    docker build --platform linux/amd64 -t products-mcp:amd64 . || handle_error "AMD64 build failed"
    print_success "AMD64 build completed"
}

# Build for ARM64
build_arm64() {
    print_section "Building for ARM64"
    docker build --platform linux/arm64 -t products-mcp:arm64 . || handle_error "ARM64 build failed"
    print_success "ARM64 build completed"
}

# Build for both platforms using buildx
build_multi() {
    print_section "Building for both AMD64 and ARM64 using buildx"
    docker buildx create --use || handle_error "Failed to create buildx builder"
    docker buildx build --platform linux/amd64,linux/arm64 -t products-mcp:latest . || handle_error "Multi-platform build failed"
    print_success "Multi-platform build completed"
}

# Build and push to registry
build_and_push() {
    if [ -z "$1" ]; then
        echo "Please provide a registry URL (e.g., your-registry.com/products-mcp)"
        exit 1
    fi
    print_section "Building and pushing to registry: $1"
    docker buildx create --use
    docker buildx build --platform linux/amd64,linux/arm64 -t "$1:latest" --push .
    print_success "Multi-platform build and push completed"
}

# Run the container
run_container() {
    local arch=${1:-"amd64"}  # Default to amd64 if no architecture specified
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        handle_error ".env file not found. Please create one with required JWT settings"
    fi
    
    case "$arch" in
        "amd64"|"arm64")
            print_section "Running container for $arch"
            docker run \
                -p 8000:8000 \
                --env-file .env \
                products-mcp:$arch || handle_error "Failed to run container for $arch"
            ;;
        *)
            echo "Invalid architecture. Use 'amd64' or 'arm64'"
            exit 1
            ;;
    esac
}

# Help message
show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  amd64        - Build for AMD64 architecture"
    echo "  arm64        - Build for ARM64 architecture"
    echo "  multi        - Build for both architectures using buildx"
    echo "  push [reg]   - Build and push to registry (reg = registry URL)"
    echo "  run [arch]   - Run the container (arch = amd64 or arm64, default: amd64)"
    echo "  help         - Show this help message"
}

# Main script logic
case "$1" in
    "amd64")
        build_amd64
        ;;
    "arm64")
        build_arm64
        ;;
    "multi")
        build_multi
        ;;
    "push")
        build_and_push "$2"
        ;;
    "run")
        run_container "$2"
        ;;
    "help"|*)
        show_help
        ;;
esac