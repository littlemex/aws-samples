FROM ghcr.io/astral-sh/uv:python3.10-bookworm-slim
WORKDIR /app

# ビルド時引数（デフォルト値を設定）
ARG AWS_REGION=us-east-1
ARG BEDROCK_MODEL_ID=us.anthropic.claude-3-7-sonnet-20250219-v1:0

# All environment variables in one layer
ENV UV_SYSTEM_PYTHON=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_NO_PROGRESS=1 \
    PYTHONUNBUFFERED=1 \
    DOCKER_CONTAINER=1 \
    AWS_REGION=${AWS_REGION} \
    AWS_DEFAULT_REGION=${AWS_REGION} \
    BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID}



COPY requirements.txt requirements.txt
# Install from requirements file
RUN uv pip install -r requirements.txt




RUN uv pip install aws-opentelemetry-distro>=0.10.1


# Signal that this is running in Docker for host binding logic
ENV DOCKER_CONTAINER=1

# Create non-root user
RUN useradd -m -u 1000 bedrock_agentcore
USER bedrock_agentcore

EXPOSE 9000
EXPOSE 8000
EXPOSE 8080

# Copy entire project (respecting .dockerignore)
COPY . .

# Use the full module path

CMD ["opentelemetry-instrument", "python", "-m", "runtime_agent"]
