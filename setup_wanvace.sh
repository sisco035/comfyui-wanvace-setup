#!/bin/bash

echo "================================================"
echo "WanVace Workflow Auto-Setup Script"
echo "================================================"
echo ""

export GIT_TERMINAL_PROMPT=0

# Find ComfyUI directory
if [ -d "/workspace/ComfyUI" ]; then
    COMFYUI_DIR="/workspace/ComfyUI"
elif [ -d "/workspace/comfyui" ]; then
    COMFYUI_DIR="/workspace/comfyui"
else
    echo "Error: ComfyUI not found!"
    exit 1
fi

echo "Found ComfyUI at: $COMFYUI_DIR"
cd "$COMFYUI_DIR"

echo ""
echo "Installing custom nodes..."
cd custom_nodes

install_node() {
    local folder="$1"
    local repo="$2"

    if [ ! -d "$folder" ]; then
        echo "  Installing $folder..."
        GIT_TERMINAL_PROMPT=0 git clone --depth 1 --single-branch "$repo" "$folder"
        if [ -f "$folder/requirements.txt" ]; then
            pip install -q -r "$folder/requirements.txt" 2>/dev/null
        fi
    else
        echo "  ✓ $folder already installed"
    fi
}

install_node "rgthree-comfy" "https://github.com/rgthree/rgthree-comfy.git"
install_node "ComfyUI-VideoHelperSuite" "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
install_node "ComfyUI-GGUF" "https://github.com/city96/ComfyUI-GGUF.git"
install_node "comfyui_controlnet_aux" "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
install_node "ComfyUI-KJNodes" "https://github.com/kijai/ComfyUI-KJNodes.git"
install_node "ComfyUI-WanVace" "https://github.com/JettHu/ComfyUI-WanVace.git"

cd "$COMFYUI_DIR"
mkdir -p models/unet models/vae models/clip models/loras input workflows

echo ""
echo "Downloading models (this may take 10-20 minutes)..."
echo ""

# UNET
if [ ! -f "models/unet/Wan2.1-VACE-14B-Q8_0.gguf" ]; then
    echo "Downloading UNET model (Q8_0 - ~15GB)..."
    wget --progress=bar:force -O "models/unet/Wan2.1-VACE-14B-Q8_0.gguf" \
        "https://huggingface.co/JettHu/Wan2.1-VACE-14B-GGUF/resolve/main/Wan2.1-VACE-14B-Q8_0.gguf"
else
    echo "✓ UNET model already exists"
fi

# VAE
if [ ! -f "models/vae/wan_2.1_vae.safetensors" ]; then
    echo "Downloading VAE model..."
    wget --progress=bar:force -O "models/vae/wan_2.1_vae.safetensors" \
        "https://huggingface.co/JettHu/Wan2.1-VACE-14B/resolve/main/vae/wan_2.1_vae.safetensors"
else
    echo "✓ VAE model already exists"
fi

# CLIP
if [ ! -f "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then
    echo "Downloading CLIP model..."
    wget --progress=bar:force -O "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        "https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q8_0.gguf"
else
    echo "✓ CLIP model already exists"
fi

# LoRA
if [ ! -f "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" ]; then
    echo "Downloading LoRA model..."
    wget --progress=bar:force -O "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" \
        "https://huggingface.co/JettHu/Wan21_CausVid_14B_T2V_LoRA/resolve/main/Wan21_CausVid_14B_T2V_lora_rank32.safetensors"
else
    echo "✓ LoRA model already exists"
fi

# Create input instructions
cat > "input/README.txt" << 'EOF'
UPLOAD THESE FILES TO THIS DIRECTORY:
=====================================
1. Vote For Pedro.png
2. Napolean Dynamite Dance - 16 by 9.mp4

The workflow is configured to use these exact filenames.
EOF

echo ""
echo "================================================"
echo "✅ Setup Complete!"
echo "================================================"
echo "📁 ComfyUI is at: $COMFYUI_DIR"
echo ""
echo "📋 To use the workflow:"
echo "1. Upload your files to: $COMFYUI_DIR/input/"
echo "   • Vote For Pedro.png"
echo "   • Napolean Dynamite Dance - 16 by 9.mp4"
echo "2. In ComfyUI web interface:"
echo "   • Click 'Load'"
echo "   • Select: workflows/WanVace_Q8_Workflow.json"
echo "3. Click 'Queue Prompt' to generate!"
echo ""
echo "💡 GPU Requirements: 24GB+ VRAM recommended"
echo "================================================"
