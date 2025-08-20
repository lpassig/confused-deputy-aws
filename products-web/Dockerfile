# =============================================================================
# Multi-stage Dockerfile for products-web Streamlit application
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
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 2: Production image (optimized)
# =============================================================================
FROM base AS production

# Create app directory
WORKDIR /app

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser -d /app appuser

# Copy dependency file
COPY requirements.txt ./

# Install dependencies with pip
RUN pip install -r requirements.txt

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Health check for Streamlit
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health

# Expose port
EXPOSE 8501

# Add metadata labels
LABEL maintainer="products-web-team" \
      version="0.1.0" \
      description="Streamlit application for Entra ID OAuth and ProductsAgent chat"

# Run the application
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]

# =============================================================================
# Stage 3: Development image (for debugging and hot-reloading)
# =============================================================================
FROM base AS development

# Create app directory
WORKDIR /app

# Install uv for faster development installs
RUN pip install uv

# Copy dependency files
COPY pyproject.toml ./

# Install dependencies with uv
RUN uv pip install -r pyproject.toml

# Copy application code
COPY . .

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser -d /app appuser \
    && chown -R appuser:appuser /app

USER appuser

# Expose port
EXPOSE 8501

# Run with hot reload for development
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.fileWatcherType=poll"]
