# =============================================================================
# Multi-stage Dockerfile for products-agent FastAPI application
# Supports multi-architecture builds (arm64/amd64)
# Uses uv for fast dependency management
# =============================================================================

# Build arguments for multi-architecture support
ARG PYTHON_VERSION=3.12

# =============================================================================
# Stage 1: Base image with uv
# =============================================================================
FROM python:${PYTHON_VERSION}-slim-bookworm AS base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

# Install system dependencies and uv
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir uv

# =============================================================================
# Stage 2: Dependencies installation
# =============================================================================
FROM base AS deps

# Create app directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml ./

# Install dependencies using uv
RUN uv pip install --system --no-cache-dir -r pyproject.toml

# =============================================================================
# Stage 3: Development image (optional, for development builds)
# =============================================================================
FROM deps AS development

# Copy application code
COPY . .

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser \
    && chown -R appuser:appuser /app

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# Expose port
EXPOSE 8001

# Run the application
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]

# =============================================================================
# Stage 4: Production image (optimized)
# =============================================================================
FROM python:${PYTHON_VERSION}-slim-bookworm AS production

# Set environment variables for production
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

# Install minimal runtime dependencies and uv
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && pip install --no-cache-dir uv

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser -d /app appuser

# Create app directory and set ownership
WORKDIR /app
RUN chown appuser:appuser /app

# Copy dependency files first
COPY pyproject.toml ./

# Install dependencies directly in production stage
RUN uv pip install --system --no-cache-dir -r pyproject.toml

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# Expose port
EXPOSE 8001

# Add metadata labels
LABEL maintainer="products-agent-team" \
      version="0.1.0" \
      description="ProductsAgent FastAPI application with JWT authentication and Microsoft Entra ID integration" \
      org.opencontainers.image.source="https://github.com/your-org/confused-deputy-aws"

# Run the application with optimized settings
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "1"]
