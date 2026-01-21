#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
COMFYUI_DIR="${HOME}/ComfyUI"
VENV_DIR="${HOME}/comfyui-env"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ComfyUI Environment Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test function
test_check() {
    local description="$1"
    local command="$2"
    local is_critical="${3:-true}"

    echo -n "Testing: ${description}... "

    if eval "${command}" &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
        return 0
    else
        if [ "${is_critical}" = "true" ]; then
            echo -e "${RED}✗ FAIL${NC}"
            ((FAILED++))
        else
            echo -e "${YELLOW}⚠ WARNING${NC}"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Test function with output
test_check_verbose() {
    local description="$1"
    local command="$2"
    local is_critical="${3:-true}"

    echo "Testing: ${description}"

    output=$(eval "${command}" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        echo "${output}" | sed 's/^/  /'
        ((PASSED++))
        echo ""
        return 0
    else
        if [ "${is_critical}" = "true" ]; then
            echo -e "${RED}✗ FAIL${NC}"
            echo "${output}" | sed 's/^/  /'
            ((FAILED++))
        else
            echo -e "${YELLOW}⚠ WARNING${NC}"
            echo "${output}" | sed 's/^/  /'
            ((WARNINGS++))
        fi
        echo ""
        return 1
    fi
}

# Section 1: System Requirements
echo -e "${YELLOW}=== Section 1: System Requirements ===${NC}"
echo ""

test_check "Python 3 installed" "command -v python3"
test_check_verbose "Python version" "python3 --version"
test_check "pip installed" "command -v pip3"
test_check "git installed" "command -v git"
test_check "wget installed" "command -v wget"

echo ""

# Section 2: GPU Check
echo -e "${YELLOW}=== Section 2: GPU Availability ===${NC}"
echo ""

if test_check "nvidia-smi available" "command -v nvidia-smi" "false"; then
    test_check_verbose "GPU information" "nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv"
    test_check_verbose "CUDA version" "nvidia-smi | grep 'CUDA Version'"
else
    echo -e "${YELLOW}  GPU not detected - will run in CPU mode${NC}"
    echo ""
fi

echo ""

# Section 3: Python Environment
echo -e "${YELLOW}=== Section 3: Python Environment ===${NC}"
echo ""

test_check "Virtual environment exists" "[ -d ${VENV_DIR} ]"

if [ -d "${VENV_DIR}" ]; then
    # Activate venv for tests
    source "${VENV_DIR}/bin/activate" 2>/dev/null

    test_check_verbose "PyTorch installed" "python3 -c 'import torch; print(f\"PyTorch {torch.__version__}\")'"

    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        test_check_verbose "PyTorch CUDA support" "python3 -c 'import torch; print(f\"CUDA available: {torch.cuda.is_available()}\"); print(f\"CUDA version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}\")'"
    fi

    test_check "torchvision installed" "python3 -c 'import torchvision'" "false"
    test_check "PIL/Pillow installed" "python3 -c 'import PIL'"
    test_check "numpy installed" "python3 -c 'import numpy'"
    test_check "OpenCV installed" "python3 -c 'import cv2'" "false"
else
    echo -e "${RED}  Virtual environment not found at ${VENV_DIR}${NC}"
    ((FAILED++))
fi

echo ""

# Section 4: ComfyUI Installation
echo -e "${YELLOW}=== Section 4: ComfyUI Installation ===${NC}"
echo ""

test_check "ComfyUI directory exists" "[ -d ${COMFYUI_DIR} ]"

if [ -d "${COMFYUI_DIR}" ]; then
    test_check "ComfyUI main.py exists" "[ -f ${COMFYUI_DIR}/main.py ]"
    test_check "ComfyUI requirements.txt exists" "[ -f ${COMFYUI_DIR}/requirements.txt ]"
    test_check "ComfyUI Manager installed" "[ -d ${COMFYUI_DIR}/custom_nodes/ComfyUI-Manager ]" "false"
    test_check "ControlNet Preprocessors installed" "[ -d ${COMFYUI_DIR}/custom_nodes/comfyui_controlnet_aux ]" "false"
else
    echo -e "${RED}  ComfyUI not found at ${COMFYUI_DIR}${NC}"
    ((FAILED++))
fi

echo ""

# Section 5: Directory Structure
echo -e "${YELLOW}=== Section 5: Directory Structure ===${NC}"
echo ""

test_check "models/checkpoints directory" "[ -d ${COMFYUI_DIR}/models/checkpoints ]"
test_check "models/vae directory" "[ -d ${COMFYUI_DIR}/models/vae ]"
test_check "models/loras directory" "[ -d ${COMFYUI_DIR}/models/loras ]"
test_check "models/controlnet directory" "[ -d ${COMFYUI_DIR}/models/controlnet ]"
test_check "input directory" "[ -d ${COMFYUI_DIR}/input ]" "false"
test_check "output directory" "[ -d ${COMFYUI_DIR}/output ]" "false"

echo ""

# Section 6: Models Check
echo -e "${YELLOW}=== Section 6: Models Check ===${NC}"
echo ""

echo "Checking for downloaded models..."
echo ""

# Check for base models
echo "Base Models:"
sdxl_count=$(find ${COMFYUI_DIR}/models/checkpoints -name "*sdxl*.safetensors" 2>/dev/null | wc -l)
flux_count=$(find ${COMFYUI_DIR}/models/checkpoints -name "*flux*.safetensors" 2>/dev/null | wc -l)

if [ ${sdxl_count} -gt 0 ]; then
    echo -e "  ${GREEN}✓ SDXL models found: ${sdxl_count}${NC}"
    find ${COMFYUI_DIR}/models/checkpoints -name "*sdxl*.safetensors" -exec basename {} \; | sed 's/^/    - /'
elif [ ${flux_count} -gt 0 ]; then
    echo -e "  ${GREEN}✓ FLUX models found: ${flux_count}${NC}"
    find ${COMFYUI_DIR}/models/checkpoints -name "*flux*.safetensors" -exec basename {} \; | sed 's/^/    - /'
else
    echo -e "  ${YELLOW}⚠ No base models found${NC}"
    echo -e "    Run: ./scripts/download-models.sh"
    ((WARNINGS++))
fi

echo ""

# Check for VAE
echo "VAE Models:"
vae_count=$(find ${COMFYUI_DIR}/models/vae -name "*.safetensors" 2>/dev/null | wc -l)
if [ ${vae_count} -gt 0 ]; then
    echo -e "  ${GREEN}✓ VAE models found: ${vae_count}${NC}"
    find ${COMFYUI_DIR}/models/vae -name "*.safetensors" -exec basename {} \; | sed 's/^/    - /'
else
    echo -e "  ${YELLOW}⚠ No VAE models found${NC}"
    ((WARNINGS++))
fi

echo ""

# Check for ControlNet
echo "ControlNet Models:"
cn_count=$(find ${COMFYUI_DIR}/models/controlnet -name "*.safetensors" 2>/dev/null | wc -l)
if [ ${cn_count} -gt 0 ]; then
    echo -e "  ${GREEN}✓ ControlNet models found: ${cn_count}${NC}"
    find ${COMFYUI_DIR}/models/controlnet -name "*.safetensors" -exec basename {} \; | sed 's/^/    - /'
else
    echo -e "  ${YELLOW}⚠ No ControlNet models found${NC}"
    echo -e "    ControlNet models are optional"
    ((WARNINGS++))
fi

echo ""

# Section 7: ComfyUI Server Check
echo -e "${YELLOW}=== Section 7: ComfyUI Server Check ===${NC}"
echo ""

if nc -z localhost 8188 2>/dev/null; then
    echo -e "${GREEN}✓ ComfyUI server is running on port 8188${NC}"
    ((PASSED++))

    # Try to access API
    if command -v curl &> /dev/null; then
        if curl -s http://localhost:8188/ &> /dev/null; then
            echo -e "${GREEN}✓ ComfyUI API is accessible${NC}"
            ((PASSED++))
        else
            echo -e "${YELLOW}⚠ ComfyUI server running but API not responding${NC}"
            ((WARNINGS++))
        fi
    fi
else
    echo -e "${YELLOW}⚠ ComfyUI server is not running${NC}"
    echo "  To start: cd ${COMFYUI_DIR} && source ${VENV_DIR}/bin/activate && python main.py --listen 0.0.0.0 --port 8188"
    ((WARNINGS++))
fi

echo ""

# Section 8: Disk Space
echo -e "${YELLOW}=== Section 8: Disk Space ===${NC}"
echo ""

echo "Disk usage for ComfyUI directory:"
du -sh ${COMFYUI_DIR} 2>/dev/null || echo "  Unable to calculate"

echo ""
echo "Available disk space:"
df -h ${COMFYUI_DIR} | tail -1 | awk '{print "  " $4 " free out of " $2 " (" $5 " used)"}'

# Check if less than 10GB free
available_gb=$(df -BG ${COMFYUI_DIR} | tail -1 | awk '{print $4}' | sed 's/G//')
if [ ${available_gb} -lt 10 ]; then
    echo -e "${YELLOW}⚠ Low disk space warning: Less than 10GB free${NC}"
    ((WARNINGS++))
fi

echo ""

# Final Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Tests Passed:    ${GREEN}${PASSED}${NC}"
echo -e "Tests Failed:    ${RED}${FAILED}${NC}"
echo -e "Warnings:        ${YELLOW}${WARNINGS}${NC}"
echo ""

if [ ${FAILED} -eq 0 ] && [ ${WARNINGS} -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Environment is ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Start ComfyUI: source ~/.comfyui_activate && comfyui"
    echo "  2. Access UI: http://localhost:8188"
    echo "  3. Load a workflow from ~/aws-samples/machinelearning/comfyui-infographic-generator/workflows/"
    exit 0
elif [ ${FAILED} -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with warnings.${NC}"
    echo ""
    echo "Common warnings:"
    echo "  - Missing models: Run ./scripts/download-models.sh"
    echo "  - ComfyUI not running: Start with 'comfyui' command"
    echo "  - Optional packages: Most features will still work"
    exit 0
else
    echo -e "${RED}✗ Validation failed. Please fix critical issues.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  - Run: ./scripts/install-comfyui.sh"
    echo "  - Check Python and GPU drivers"
    echo "  - Ensure sufficient disk space"
    exit 1
fi
