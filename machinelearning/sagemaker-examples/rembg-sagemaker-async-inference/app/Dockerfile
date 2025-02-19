ARG TARGET_PLATFORM=cpu

# Base stage for system dependencies
FROM ubuntu:22.04 AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3.10-venv \
    build-essential \
    curl \
    libexpat1 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3.10 /usr/bin/python

# Use NVIDIA CUDA base image for GPU
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04 AS gpu-base

# Install Python and pip directly in gpu-base
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3.10-venv \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3.10 /usr/bin/python \
    && ln -s /usr/bin/python3.10 /usr/local/bin/python3 \
    && ln -s /usr/bin/python3.10 /usr/local/bin/python

# Set environment variables
ENV PYTHONPATH=/usr/lib/python3/dist-packages:/usr/lib/python3.10:/usr/lib/python3.10/lib-dynload
ENV PATH="/usr/local/bin:${PATH}"

RUN pip uninstall -y torch && pip cache purge
RUN pip install --no-cache-dir flatbuffers numpy packaging protobuf sympy && \
    pip install --no-cache-dir onnxruntime-gpu && \
    pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip install --no-cache-dir rembg[gpu]==2.0.50

# Use Ubuntu base image for CPU
FROM base AS cpu-base

RUN pip uninstall -y torch && pip cache purge
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir rembg==2.0.50

# Final stage
FROM ${TARGET_PLATFORM}-base

# Set working directory
WORKDIR /opt/ml/code

# Install dependencies directly without virtual environment
RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    pillow \
    boto3 \
    requests \
    starlette

# Copy inference code
COPY inference.py /opt/ml/code/
COPY inference_processor.py /opt/ml/code/
COPY rembg_handler.py /opt/ml/code/
COPY cloudwatch_metrics.py /opt/ml/code/
COPY serve /opt/ml/code/

# Make serve script executable
RUN chmod +x /opt/ml/code/serve

# Set environment variables
ENV PYTHONUNBUFFERED=TRUE
ENV PYTHONDONTWRITEBYTECODE=TRUE
ENV MODEL_PATH=/opt/ml/model
ENV CUDA_ENABLED=${TARGET_PLATFORM}
ENV CUDA_VISIBLE_DEVICES=0
ENV MODEL_CHECKSUM_DISABLED=1

# Create model directory
RUN mkdir -p ${MODEL_PATH}

# Expose port 8080
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["python", "-u", "/opt/ml/code/serve"]
