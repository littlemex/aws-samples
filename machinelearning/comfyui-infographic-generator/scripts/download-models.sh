#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
COMFYUI_DIR="${HOME}/ComfyUI"
MODELS_DIR="${COMFYUI_DIR}/models"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ComfyUI Model Download Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if ComfyUI is installed
if [ ! -d "${COMFYUI_DIR}" ]; then
    echo -e "${RED}Error: ComfyUI not found at ${COMFYUI_DIR}${NC}"
    echo "Please run install-comfyui.sh first"
    exit 1
fi

# Check disk space
print_disk_space() {
    echo -e "${BLUE}Available disk space:${NC}"
    df -h "${COMFYUI_DIR}" | tail -1 | awk '{print "  " $4 " free out of " $2}'
}

print_disk_space
echo ""

# Download function with retry
download_file() {
    local url="$1"
    local output="$2"
    local description="$3"

    echo -e "${CYAN}Downloading: ${description}${NC}"
    echo "  URL: ${url}"
    echo "  Output: ${output}"

    # Check if file already exists
    if [ -f "${output}" ]; then
        echo -e "${YELLOW}  File already exists, skipping...${NC}"
        return 0
    fi

    # Download with resume capability
    wget --continue --progress=bar:force --tries=3 --timeout=30 \
        "${url}" -O "${output}" 2>&1 | \
        grep --line-buffered -E "^.{0,100}%" | \
        sed -u 's/^/  /'

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}  ✓ Download complete${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Download failed${NC}"
        return 1
    fi
}

# Model selection menu
show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Select models to download:${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Base Models:"
    echo "  1) SDXL 1.0 Base (~7GB) - Recommended for beginners"
    echo "  2) SDXL 1.0 Base + Refiner (~13GB) - Higher quality"
    echo "  3) FLUX.1 schnell (~40GB) - Highest quality, commercial use"
    echo "  4) Both SDXL and FLUX (~53GB)"
    echo ""
    echo "ControlNet Models:"
    echo "  5) SDXL ControlNet - Canny (~2.5GB)"
    echo "  6) SDXL ControlNet - Depth (~2.5GB)"
    echo "  7) SDXL ControlNet - Scribble (~2.5GB)"
    echo "  8) SDXL ControlNet - All three (~7.5GB)"
    echo "  9) FLUX ControlNet - Canny (~3.6GB)"
    echo ""
    echo "Additional Models:"
    echo "  10) Upscale models (~130MB)"
    echo "  11) Full package - SDXL + ControlNets + Upscale (~28GB)"
    echo "  12) Full package - FLUX + ControlNets + Upscale (~57GB)"
    echo ""
    echo "  0) Custom selection (interactive)"
    echo "  q) Quit"
    echo ""
}

# Download SDXL Base
download_sdxl_base() {
    echo -e "${YELLOW}Downloading SDXL 1.0 Base...${NC}"
    download_file \
        "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" \
        "${MODELS_DIR}/checkpoints/sd_xl_base_1.0.safetensors" \
        "SDXL 1.0 Base Model"

    download_file \
        "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors" \
        "${MODELS_DIR}/vae/sdxl_vae.safetensors" \
        "SDXL VAE"
}

# Download SDXL Refiner
download_sdxl_refiner() {
    echo -e "${YELLOW}Downloading SDXL 1.0 Refiner...${NC}"
    download_file \
        "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors" \
        "${MODELS_DIR}/checkpoints/sd_xl_refiner_1.0.safetensors" \
        "SDXL 1.0 Refiner Model"
}

# Download FLUX
download_flux() {
    echo -e "${YELLOW}Downloading FLUX.1 schnell...${NC}"
    download_file \
        "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors" \
        "${MODELS_DIR}/checkpoints/flux1-schnell.safetensors" \
        "FLUX.1 schnell Model"

    mkdir -p "${MODELS_DIR}/clip"
    download_file \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors" \
        "${MODELS_DIR}/clip/t5xxl_fp16.safetensors" \
        "FLUX T5 Text Encoder"

    download_file \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
        "${MODELS_DIR}/clip/clip_l.safetensors" \
        "FLUX CLIP Text Encoder"

    download_file \
        "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors" \
        "${MODELS_DIR}/vae/ae.safetensors" \
        "FLUX VAE"
}

# Download SDXL ControlNet Canny
download_controlnet_canny() {
    echo -e "${YELLOW}Downloading SDXL ControlNet Canny...${NC}"
    download_file \
        "https://huggingface.co/diffusers/controlnet-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors" \
        "${MODELS_DIR}/controlnet/controlnet-canny-sdxl-1.0.safetensors" \
        "SDXL ControlNet Canny"
}

# Download SDXL ControlNet Depth
download_controlnet_depth() {
    echo -e "${YELLOW}Downloading SDXL ControlNet Depth...${NC}"
    download_file \
        "https://huggingface.co/diffusers/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors" \
        "${MODELS_DIR}/controlnet/controlnet-depth-sdxl-1.0.safetensors" \
        "SDXL ControlNet Depth"
}

# Download SDXL ControlNet Scribble
download_controlnet_scribble() {
    echo -e "${YELLOW}Downloading SDXL ControlNet Scribble...${NC}"
    download_file \
        "https://huggingface.co/xinsir/controlnet-scribble-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors" \
        "${MODELS_DIR}/controlnet/controlnet-scribble-sdxl-1.0.safetensors" \
        "SDXL ControlNet Scribble"
}

# Download FLUX ControlNet Canny
download_flux_controlnet_canny() {
    echo -e "${YELLOW}Downloading FLUX ControlNet Canny...${NC}"
    download_file \
        "https://huggingface.co/InstantX/FLUX.1-dev-Controlnet-Canny/resolve/main/diffusion_pytorch_model.safetensors" \
        "${MODELS_DIR}/controlnet/flux-controlnet-canny.safetensors" \
        "FLUX ControlNet Canny"
}

# Download Upscale models
download_upscale_models() {
    echo -e "${YELLOW}Downloading Upscale models...${NC}"
    download_file \
        "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth" \
        "${MODELS_DIR}/upscale_models/RealESRGAN_x4plus.pth" \
        "RealESRGAN x4plus"

    download_file \
        "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x4plus_anime_6B.pth" \
        "${MODELS_DIR}/upscale_models/RealESRGAN_x4plus_anime_6B.pth" \
        "RealESRGAN x4plus Anime"
}

# Main selection logic
while true; do
    show_menu
    read -p "Enter your choice: " choice
    echo ""

    case $choice in
        1)
            download_sdxl_base
            ;;
        2)
            download_sdxl_base
            download_sdxl_refiner
            ;;
        3)
            download_flux
            ;;
        4)
            download_sdxl_base
            download_flux
            ;;
        5)
            download_controlnet_canny
            ;;
        6)
            download_controlnet_depth
            ;;
        7)
            download_controlnet_scribble
            ;;
        8)
            download_controlnet_canny
            download_controlnet_depth
            download_controlnet_scribble
            ;;
        9)
            download_flux_controlnet_canny
            ;;
        10)
            download_upscale_models
            ;;
        11)
            download_sdxl_base
            download_controlnet_canny
            download_controlnet_depth
            download_controlnet_scribble
            download_upscale_models
            ;;
        12)
            download_flux
            download_flux_controlnet_canny
            download_controlnet_canny
            download_controlnet_depth
            download_controlnet_scribble
            download_upscale_models
            ;;
        0)
            echo "Custom selection mode:"
            read -p "Download SDXL Base? (y/n): " ans
            [[ $ans == "y" ]] && download_sdxl_base

            read -p "Download SDXL Refiner? (y/n): " ans
            [[ $ans == "y" ]] && download_sdxl_refiner

            read -p "Download FLUX? (y/n): " ans
            [[ $ans == "y" ]] && download_flux

            read -p "Download SDXL ControlNet Canny? (y/n): " ans
            [[ $ans == "y" ]] && download_controlnet_canny

            read -p "Download SDXL ControlNet Depth? (y/n): " ans
            [[ $ans == "y" ]] && download_controlnet_depth

            read -p "Download SDXL ControlNet Scribble? (y/n): " ans
            [[ $ans == "y" ]] && download_controlnet_scribble

            read -p "Download FLUX ControlNet Canny? (y/n): " ans
            [[ $ans == "y" ]] && download_flux_controlnet_canny

            read -p "Download Upscale models? (y/n): " ans
            [[ $ans == "y" ]] && download_upscale_models
            ;;
        q|Q)
            echo "Exiting..."
            break
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            continue
            ;;
    esac

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Download batch complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    print_disk_space
    echo ""
    echo "Downloaded models are located at:"
    echo "  ${MODELS_DIR}/"
    echo ""
    read -p "Download more models? (y/n): " continue_download
    [[ $continue_download != "y" ]] && break
    echo ""
done

echo ""
echo -e "${BLUE}Model directory structure:${NC}"
tree -L 2 "${MODELS_DIR}" 2>/dev/null || ls -lah "${MODELS_DIR}"/*/ 2>/dev/null || echo "Install 'tree' for better visualization"
echo ""
echo -e "${GREEN}All done! You can now start ComfyUI.${NC}"
echo ""
