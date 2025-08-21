
# syntax=docker/dockerfile:1
# Single-stage build for Python application supporting both ARM64 and AMD64

FROM python:3.12-slim

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files first for better cache
COPY pyproject.toml README.md ./

# Install pip-tools to generate requirements.txt
RUN pip install --no-cache-dir pip-tools && \
    pip-compile pyproject.toml --output-file requirements.txt

# Install runtime dependencies (built for the target architecture)
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=8000 \
    PATH="/home/appuser/.local/bin:$PATH" \
    PYTHONPATH="/app"

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Run the server
CMD ["python", "/app/server.py"]