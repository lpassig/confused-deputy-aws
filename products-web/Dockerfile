# =============================================================================
# Multi-stage Dockerfile for products-web Streamlit application
# Optimized for minimal image size
# =============================================================================

# Build arguments for multi-architecture support
ARG PYTHON_VERSION=3.12

# =============================================================================
# Stage 1: Build dependencies
# =============================================================================
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy dependency files
COPY requirements.txt ./

# Install dependencies to a temporary location
RUN pip install --prefix=/install -r requirements.txt

# =============================================================================
# Stage 2: Production image (optimized for size)
# =============================================================================
FROM python:${PYTHON_VERSION}-slim-bookworm AS production

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/install/bin:$PATH \
    PYTHONPATH=/install/lib/python3.12/site-packages

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser -d /app appuser

# Create app directory and set ownership
WORKDIR /app
RUN chown appuser:appuser /app

# Copy Python dependencies from builder stage
COPY --from=builder /install /install

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
