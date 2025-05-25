#!/bin/bash

echo "================================================"
echo "WanVace Model Downloader Only"
echo "================================================"
echo ""

export GIT_TERMINAL_PROMPT=0

# Check for Hugging Face token
if [ -z "$HF_TOKEN" ]; then
    echo "❌ ERROR: Hugging Face token (HF_TOKEN) is not set."
    echo "Please set it in your RunPod environment variables."
    exit 1
fi

# Locate ComfyUI directory
if [ -d "/workspace/ComfyUI" ]; then
    COMFYUI_DIR="/workspace/ComfyUI"
elif [ -d "/workspace/comfyui" ]; then
    COMFYUI_DIR="/workspace/comfyui"
else
    echo "❌ Error: ComfyUI not found!"
    exit 1
fi

echo "✅ Found ComfyUI at: $COMFYUI_DIR"
cd "$COMFYUI_DIR"

# Ensure model folders exist
mkdir -p models/diffusion_models models/vae models/clip models/loras input

echo ""
echo "⏬ Downloading models (this may take 10-20 minutes)..."
echo ""

# UNET
if [ ! -f "models/diffusion_models/Wan2.1-VACE-14B-Q8_0.gguf" ]; then
    echo "Downloading UNET model (~15GB)..."
    wget --header="Authorization: Bearer $HF_TOKEN" --progress=bar:force \
        -O "models/diffusion_models/Wan2.1-VACE-14B-Q8_0.gguf" \
        "https://huggingface.co/QuantStack/Wan2.1-VACE-14B-GGUF/resolve/main/Wan2.1-VACE-14B-Q8_0.gguf"
else
    echo "✓ UNET model already exists"
fi

# VAE
if [ ! -f "models/vae/wan_2.1_vae.safetensors" ]; then
    echo "Downloading VAE model..."
    wget --header="Authorization: Bearer $HF_TOKEN" --progress=bar:force \
        -O "models/vae/wan_2.1_vae.safetensors" \
        "https://huggingface.co/calcuis/wan-gguf/resolve/2f41e77bfc957eab2020821463d0cd7b15804bb9/wan_2.1_vae.safetensors"
else
    echo "✓ VAE model already exists"
fi

# CLIP
if [ ! -f "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then
    echo "Downloading CLIP model..."
    wget --header="Authorization: Bearer $HF_TOKEN" --progress=bar:force \
        -O "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        "https://huggingface.co/ratoenien/umt5_xxl_fp8_e4m3fn_scaled/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
else
    echo "✓ CLIP model already exists"
fi

# LoRA
if [ ! -f "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" ]; then
    echo "Downloading LoRA model..."
    wget --header="Authorization: Bearer $HF_TOKEN" --progress=bar:force \
        -O "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" \
        "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_CausVid_14B_T2V_lora_rank32.safetensors?download=true"
else
    echo "✓ LoRA model already exists"
fi

# ✅ Verify all models downloaded
echo ""
echo "🔍 Verifying all model files..."
missing_files=()
check_file() {
    if [ ! -f "$1" ]; then
        echo "❌ Missing: $1"
        missing_files+=("$1")
    else
        echo "✓ Found: $1"
    fi
}
check_file "models/diffusion_models/Wan2.1-VACE-14B-Q8_0.gguf"
check_file "models/vae/wan_2.1_vae.safetensors"
check_file "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
check_file "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors"

if [ ${#missing_files[@]} -ne 0 ]; then
    echo ""
    echo "🚨 ERROR: One or more required files are missing!"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    echo ""
    echo "Please check your Hugging Face token or re-run the script."
    exit 1
fi

echo ""
echo "✅ All required models downloaded successfully."
echo "================================================"
echo ""
