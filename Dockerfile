# Multi-stage build for SRE Agent
FROM public.ecr.aws/docker/library/python:3.12-slim AS builder

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set working directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies using uv with lockfile
RUN uv pip install --system --no-cache --compile-bytecode -r uv.lock

# Final stage
FROM public.ecr.aws/docker/library/python:3.12-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY sre_agent/ ./sre_agent/
COPY backend/ ./backend/
COPY gateway/ ./gateway/
COPY scripts/ ./scripts/

# Set Python path
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Create non-root user
RUN useradd -m -u 1000 sre-agent && \
    chown -R sre-agent:sre-agent /app

USER sre-agent

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sre_agent; print('healthy')" || exit 1

# Default command
CMD ["python", "-m", "sre_agent.cli"]
