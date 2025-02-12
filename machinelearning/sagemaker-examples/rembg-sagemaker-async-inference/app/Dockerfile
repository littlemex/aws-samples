FROM python:3.9-slim

# Accept build argument for platform (cpu-base or gpu-base)
ARG TARGET_PLATFORM=cpu-base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /opt/ml/code

# Copy inference code
COPY inference.py /opt/ml/code/
COPY serve /opt/ml/code/

# Install Python dependencies based on platform
RUN if [ "$TARGET_PLATFORM" = "gpu-base" ]; then \
        pip install --no-cache-dir \
            fastapi==0.68.0 \
            uvicorn==0.15.0 \
            pillow==8.3.1 \
            rembg[gpu]==2.0.50 \
            boto3==1.26.137 \
            requests==2.31.0; \
    else \
        pip install --no-cache-dir \
            fastapi==0.68.0 \
            uvicorn==0.15.0 \
            pillow==8.3.1 \
            rembg==2.0.50 \
            boto3==1.26.137 \
            requests==2.31.0; \
    fi

# Make serve script executable
RUN chmod +x /opt/ml/code/serve

# Set environment variables
ENV PYTHONUNBUFFERED=TRUE
ENV PYTHONDONTWRITEBYTECODE=TRUE
ENV MODEL_PATH=/opt/ml/model
ENV CUDA_ENABLED=${TARGET_PLATFORM:-cpu-base}

# Expose port 8080
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["python", "-u", "/opt/ml/code/serve"]