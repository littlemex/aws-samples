#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${HOME}/ComfyUI"
VENV_DIR="${HOME}/comfyui-env"
USER=$(whoami)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ComfyUI Installation Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Configuration:"
echo "  User: ${USER}"
echo "  Install Directory: ${INSTALL_DIR}"
echo "  Virtual Environment: ${VENV_DIR}"
echo ""

# Function to print step
print_step() {
    echo -e "${YELLOW}===> $1${NC}"
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
        exit 1
    fi
}

# Function to check if GPU is available
check_gpu() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi &> /dev/null
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi
    return 1
}

# Step 1: Check prerequisites
print_step "Step 1: Checking prerequisites"
echo "Checking Python version..."
python3 --version
check_status

echo "Checking pip..."
pip3 --version
check_status

echo "Checking git..."
git --version
check_status

if check_gpu; then
    echo -e "${GREEN}✓ GPU detected${NC}"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
    echo -e "${YELLOW}⚠ Warning: GPU not detected or nvidia-smi not available${NC}"
    echo -e "${YELLOW}  This script will continue, but GPU features may not work${NC}"
fi

# Step 2: Install system dependencies
print_step "Step 2: Installing system dependencies"
sudo apt-get update -qq
sudo apt-get install -y -qq \
    git \
    wget \
    curl \
    python3-pip \
    python3-venv \
    libgl1-mesa-glx \
    libglib2.0-0 \
    build-essential \
    python3-dev
check_status

# Step 3: Create Python virtual environment
print_step "Step 3: Creating Python virtual environment"
if [ -d "${VENV_DIR}" ]; then
    echo "Virtual environment already exists at ${VENV_DIR}"
    echo "Skipping creation..."
else
    python3 -m venv "${VENV_DIR}"
    check_status
fi

# Activate virtual environment
source "${VENV_DIR}/bin/activate"
echo "Virtual environment activated: ${VIRTUAL_ENV}"

# Step 4: Install PyTorch with CUDA support
print_step "Step 4: Installing PyTorch with CUDA 12.1 support"
if check_gpu; then
    echo "Installing PyTorch with CUDA support..."
    pip install torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cu121 --quiet
else
    echo "Installing PyTorch CPU-only version..."
    pip install torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cpu --quiet
fi
check_status

# Verify PyTorch installation
echo "Verifying PyTorch installation..."
python3 -c "import torch; print(f'PyTorch version: {torch.__version__}')"
if check_gpu; then
    python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')"
fi
check_status

# Step 5: Clone ComfyUI repository
print_step "Step 5: Cloning ComfyUI repository"
if [ -d "${INSTALL_DIR}" ]; then
    echo "ComfyUI directory already exists at ${INSTALL_DIR}"
    echo "Updating repository..."
    cd "${INSTALL_DIR}"
    git pull
else
    git clone https://github.com/comfyanonymous/ComfyUI.git "${INSTALL_DIR}"
    check_status
    cd "${INSTALL_DIR}"
fi

# Step 6: Install ComfyUI dependencies
print_step "Step 6: Installing ComfyUI dependencies"
pip install -r requirements.txt --quiet
check_status

# Install additional recommended packages
echo "Installing additional packages..."
pip install opencv-python pillow matplotlib numpy --quiet
check_status

# Step 7: Install ComfyUI Manager
print_step "Step 7: Installing ComfyUI Manager"
MANAGER_DIR="${INSTALL_DIR}/custom_nodes/ComfyUI-Manager"
if [ -d "${MANAGER_DIR}" ]; then
    echo "ComfyUI Manager already exists"
    cd "${MANAGER_DIR}"
    git pull
else
    mkdir -p "${INSTALL_DIR}/custom_nodes"
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "${MANAGER_DIR}"
    check_status
    cd "${MANAGER_DIR}"
fi

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt --quiet
    check_status
fi

# Step 8: Install ControlNet Preprocessors
print_step "Step 8: Installing ControlNet Preprocessors"
CONTROLNET_DIR="${INSTALL_DIR}/custom_nodes/comfyui_controlnet_aux"
if [ -d "${CONTROLNET_DIR}" ]; then
    echo "ControlNet Preprocessors already exist"
    cd "${CONTROLNET_DIR}"
    git pull
else
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git "${CONTROLNET_DIR}"
    check_status
    cd "${CONTROLNET_DIR}"
fi

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt --quiet
    check_status
fi

# Step 9: Create directory structure
print_step "Step 9: Creating model directory structure"
cd "${INSTALL_DIR}"
mkdir -p models/{checkpoints,vae,loras,controlnet,clip,upscale_models,embeddings}
mkdir -p input output workflows
check_status

echo "Directory structure:"
tree -L 2 models/ 2>/dev/null || ls -la models/

# Step 10: Create startup script
print_step "Step 10: Creating startup script"
cat > "${INSTALL_DIR}/start-comfyui.sh" << 'EOF'
#!/bin/bash

# Activate virtual environment
VENV_DIR="${HOME}/comfyui-env"
if [ -d "${VENV_DIR}" ]; then
    source "${VENV_DIR}/bin/activate"
else
    echo "Error: Virtual environment not found at ${VENV_DIR}"
    exit 1
fi

# Start ComfyUI
cd "${HOME}/ComfyUI"

# Check if GPU is available
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    echo "Starting ComfyUI with GPU support..."
    python main.py --listen 0.0.0.0 --port 8188 "$@"
else
    echo "Starting ComfyUI in CPU mode..."
    python main.py --listen 0.0.0.0 --port 8188 --cpu "$@"
fi
EOF

chmod +x "${INSTALL_DIR}/start-comfyui.sh"
check_status

# Step 11: Create environment activation script
print_step "Step 11: Creating environment activation helper"
cat > "${HOME}/.comfyui_activate" << EOF
# ComfyUI Environment Activation
source ${VENV_DIR}/bin/activate
export COMFYUI_DIR=${INSTALL_DIR}
alias comfyui='${INSTALL_DIR}/start-comfyui.sh'
alias comfyui-update='cd ${INSTALL_DIR} && git pull'
echo "ComfyUI environment activated"
echo "  Virtual Env: ${VENV_DIR}"
echo "  ComfyUI Dir: ${INSTALL_DIR}"
echo ""
echo "Available commands:"
echo "  comfyui         - Start ComfyUI server"
echo "  comfyui-update  - Update ComfyUI to latest version"
EOF

# Add to .bashrc if not already present
if ! grep -q ".comfyui_activate" "${HOME}/.bashrc"; then
    echo "" >> "${HOME}/.bashrc"
    echo "# ComfyUI environment" >> "${HOME}/.bashrc"
    echo "# source ~/.comfyui_activate  # Uncomment to auto-activate" >> "${HOME}/.bashrc"
fi

check_status

# Step 12: Create systemd service (optional)
print_step "Step 12: Creating systemd service (optional)"
cat > "/tmp/comfyui.service" << EOF
[Unit]
Description=ComfyUI Server
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${INSTALL_DIR}
Environment="PATH=${VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=${VENV_DIR}/bin/python main.py --listen 0.0.0.0 --port 8188
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "Systemd service file created at /tmp/comfyui.service"
echo "To enable automatic startup, run:"
echo "  sudo cp /tmp/comfyui.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable comfyui"
echo "  sudo systemctl start comfyui"

# Final summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Installation Summary:${NC}"
echo "  ✓ ComfyUI installed at: ${INSTALL_DIR}"
echo "  ✓ Virtual environment: ${VENV_DIR}"
echo "  ✓ ComfyUI Manager installed"
echo "  ✓ ControlNet Preprocessors installed"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Activate environment: source ~/.comfyui_activate"
echo "  2. Download models: ./scripts/download-models.sh"
echo "  3. Start ComfyUI: comfyui"
echo "  4. Access UI: http://localhost:8188 or http://<instance-ip>:8188"
echo ""
echo -e "${BLUE}Model Directory Structure:${NC}"
echo "  ${INSTALL_DIR}/models/"
echo "    ├── checkpoints/     # Place SDXL/FLUX models here"
echo "    ├── vae/             # Place VAE models here"
echo "    ├── loras/           # Place LoRA models here"
echo "    ├── controlnet/      # Place ControlNet models here"
echo "    ├── clip/            # Place CLIP models here (for FLUX)"
echo "    └── upscale_models/  # Place upscaling models here"
echo ""

if ! check_gpu; then
    echo -e "${YELLOW}⚠ Warning: No GPU detected${NC}"
    echo -e "${YELLOW}  ComfyUI will run in CPU mode (very slow)${NC}"
    echo -e "${YELLOW}  For production use, ensure you're on a GPU instance${NC}"
    echo ""
fi

echo -e "${GREEN}Happy generating!${NC}"
echo ""
