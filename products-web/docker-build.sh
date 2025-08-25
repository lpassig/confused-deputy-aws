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
    docker build --platform linux/amd64 --target production -t products-web:amd64 . || handle_error "AMD64 build failed"
    print_success "AMD64 build completed"
}

# Build for ARM64
build_arm64() {
    print_section "Building for ARM64"
    docker build --platform linux/arm64 --target production -t products-web:arm64 . || handle_error "ARM64 build failed"
    print_success "ARM64 build completed"
}

# Build for both platforms using buildx
build_multi() {
    print_section "Building for both AMD64 and ARM64 using buildx"
    docker buildx create --use || handle_error "Failed to create buildx builder"
    docker buildx build --platform linux/amd64,linux/arm64 --target production -t products-web:latest . || handle_error "Multi-platform build failed"
    print_success "Multi-platform build completed"
}

# Build and push to registry
build_and_push() {
    if [ -z "$1" ]; then
        echo "Please provide a registry URL (e.g., your-registry.com/products-web)"
        exit 1
    fi
    print_section "Building and pushing to registry: $1"
    docker buildx create --use
    docker buildx build --platform linux/amd64,linux/arm64 --target production -t "$1:latest" --push .
    print_success "Multi-platform build and push completed"
}

# Run the container
run_container() {
    local arch=${1:-"latest"}  # Default to latest if no architecture specified
    
    # Check if .env file exists
    if [ ! -f .env ]; then
        handle_error ".env file not found. Please create one with required settings"
    fi
    
    case "$arch" in
        "amd64"|"arm64")
            print_section "Running container for $arch"
            docker run \
                -p 8501:8501 \
                --env-file .env \
                products-web:$arch || handle_error "Failed to run container for $arch"
            ;;
        "latest"|*)
            print_section "Running container (latest)"
            docker run \
                -p 8501:8501 \
                --env-file .env \
                products-web:latest || handle_error "Failed to run container"
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
    echo "  run [arch]   - Run the container (arch = amd64, arm64, dev, or latest)"
    echo "  help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 amd64                           # Build for AMD64"
    echo "  $0 multi                           # Build for both architectures"
    echo "  $0 push myregistry.com/products-web  # Build and push to registry"
    echo "  $0 run dev                         # Run development container with volume mount"
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
