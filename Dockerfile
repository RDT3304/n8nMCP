# Start with the specified Python base image for mcpo
FROM python:3.12-slim-bookworm

# Set environment variables for non-interactive installations
ENV DEBIAN_FRONTEND=noninteractive

# Install uv (from official binary)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Install base dependencies (git, curl, ca-certificates)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# --- Dependencies for n8n-mcp (Node.js) ---
# Install Node.js v22.x and npm via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- MCPO Python Virtual Environment Setup ---
WORKDIR /app
ENV VIRTUAL_ENV=/app/.venv
RUN uv venv "$VIRTUAL_ENV"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN uv pip install mcpo && rm -rf ~/.cache

# --- n8n-mcp Source Code & Build Steps ---
# Clone the n8n-mcp repository
WORKDIR /
RUN git clone https://github.com/czlonkowski/n8n-mcp.git /mcp_server_src

# Change to its directory
WORKDIR /mcp_server_src

# Install Node.js dependencies
RUN npm install

# Build the TypeScript code (outputs to dist/ directory)
RUN npm run build

# --- Final Configuration ---
# Set the primary working directory back to /app for mcpo execution
WORKDIR /app

# Expose the port mcpo will listen on
EXPOSE 8002

# Set default API keys and port for mcpo.
# IMPORTANT: These should be overridden with strong, unique keys
# in your deployment environment (e.g., Coolify, Kubernetes secrets, .env file).
ENV MCPO_API_KEY="your-secret-mcpo-api-key"
# Port for MCPO to listen on
ENV MCPO_PORT=8002

# Temporary CMD for debugging n8n-mcp startup.
# We're adding DEBUG=* and using 'npm start' to see more verbose output.
CMD DEBUG=* npm start --prefix /mcp_server_src
