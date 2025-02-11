# Base images for CPU and GPU
FROM pytorch/pytorch:2.6.0-cuda12.6-cudnn9-runtime as cpu-base
ENV MYPLATFORM=cpu

FROM pytorch/pytorch:2.6.0-cuda12.6-cudnn9-runtime as gpu-base
ENV MYPLATFORM=gpu

# Common setup for both CPU and GPU
FROM ${TARGET_PLATFORM:-cpu-base} as final

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/conda/bin:$PATH"

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
# Note: onnxruntime-gpu will be installed for GPU target, onnxruntime for CPU
RUN if [ "${TARGET_PLATFORM}" = "gpu-base" ]; then \
        pip install --no-cache-dir \
        rembg[gpu] \
        pillow \
        fastapi \
        uvicorn \
        gunicorn \
        sagemaker-inference \
        numpy \
        onnxruntime-gpu; \
    else \
        pip install --no-cache-dir \
        rembg[cpu] \
        pillow \
        fastapi \
        uvicorn \
        gunicorn \
        sagemaker-inference \
        numpy \
        onnxruntime; \
    fi

# Set up directories
RUN mkdir -p /opt/ml/model \
    /opt/ml/input/data \
    /opt/ml/processing \
    /opt/program \
    /var/log/nginx

# Copy inference code
COPY inference.py /opt/program/
COPY serve /opt/program/

# Make scripts executable
RUN chmod +x /opt/program/serve

# Set working directory
WORKDIR /opt/program

# Set entrypoint
ENTRYPOINT ["./serve"]