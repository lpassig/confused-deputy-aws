# syntax=docker/dockerfile:1
# Multi-stage build for Python application supporting both ARM64 and AMD64

# Stage 1: Build stage
FROM --platform=$BUILDPLATFORM python:3.12-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy only necessary files first
COPY pyproject.toml README.md ./

# Install dependencies using pip-tools
RUN pip install --no-cache-dir pip-tools && \
    pip-compile pyproject.toml --output-file requirements.txt && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .
COPY .env /app/.env

# Stage 2: Runtime stage
FROM python:3.12-slim AS runtime

WORKDIR /app

# Create non-root user
RUN useradd -m -u 1000 appuser

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=8000 \
    PATH="/home/appuser/.local/bin:$PATH" \
    PYTHONPATH="/app"

# Copy only necessary files from builder
COPY --from=builder /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=builder /app/*.py /app/
COPY --from=builder /app/.env /app/

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Run the server
CMD ["python", "/app/server.py"]