ARG TARGET_PLATFORM=cpu

# Use NVIDIA CUDA base image for GPU
#FROM nvidia/cuda:12.5.0-runtime-ubuntu22.04 AS gpu-base
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04 AS gpu-base

# Use Ubuntu base image for CPU
FROM ubuntu:22.04 AS cpu-base

# Final stage
FROM ${TARGET_PLATFORM}-base

# Set working directory
WORKDIR /opt/ml/code

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3.10-venv \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create and activate virtual environment
RUN python3.10 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install common dependencies
RUN pip install --no-cache-dir \
    fastapi==0.68.0 \
    uvicorn==0.15.0 \
    pillow \
    boto3==1.26.137 \
    requests==2.31.0

RUN pip uninstall torch && pip cache purge

# Install PyTorch with CUDA 12.5 support for GPU, CPU version for CPU
RUN if [ "${TARGET_PLATFORM}" = "gpu" ]; then \
        pip install --no-cache-dir flatbuffers numpy packaging protobuf sympy && \
        pip install --no-cache-dir onnxruntime-gpu && \
        pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 && \
        #pip install --no-cache-dir torch torchvision torchaudio && \
        pip install --no-cache-dir rembg[gpu]==2.0.50; \
    else \
        pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
        pip install --no-cache-dir rembg==2.0.50; \
    fi

# Copy inference code
COPY inference.py /opt/ml/code/
COPY serve /opt/ml/code/

# Make serve script executable
RUN chmod +x /opt/ml/code/serve

# Set environment variables
ENV PYTHONUNBUFFERED=TRUE
ENV PYTHONDONTWRITEBYTECODE=TRUE
ENV MODEL_PATH=/opt/ml/model
ENV CUDA_ENABLED=${TARGET_PLATFORM}
ENV CUDA_VISIBLE_DEVICES=0

# Expose port 8080
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["python", "-u", "/opt/ml/code/serve"]