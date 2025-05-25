#!/bin/bash

echo "================================================"
echo "WanVace Workflow Auto-Setup Script"
echo "================================================"
echo ""

export GIT_TERMINAL_PROMPT=0

# Check for Hugging Face token
if [ -z "$HF_TOKEN" ]; then
    echo "❌ ERROR: Hugging Face token (HF_TOKEN) is not set."
    echo "Please set it in your RunPod environment variables."
    exit 1
fi

# Find ComfyUI directory
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

echo ""
echo "🔧 Installing custom nodes..."
cd custom_nodes

install_node() {
    local folder="$1"
    local repo="$2"

    if [ ! -d "$folder" ]; then
        echo "  ➕ Installing $folder..."
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
echo "⏬ Downloading models (this may take 10-20 minutes)..."
echo ""

# UNET
if [ ! -f "models/unet/Wan2.1-VACE-14B-Q8_0.gguf" ]; then
    echo "Downloading UNET model (~15GB)..."
    wget --header="Authorization: Bearer $HF_TOKEN" --progress=bar:force -O "models/unet/Wan2.1-VACE-14B-Q8_0.gguf" \
        "https://huggingface.co/QuantStack/Wan2.1-VACE-14B-GGUF/resolve/main/Wan2.1-VACE-14B-Q8_0.gguf"
else
    echo "✓ UNET model already exists"
fi

# VAE
if [ ! -f "models/vae/wan_2.1_vae.safetensors" ]; then
    echo "Downloading VAE model..."
    wget --header="Authorization: Bearer $HF_TOKEN" --progress=bar:force -O "models/vae/wan_2.1_vae.safetensors" \
        "https://huggingface.co/calcuis/wan-gguf/resolve/2f41e77bfc957eab2020821463d0cd7b15804bb9/wan_2.1_vae.safetensors"
else
    echo "✓ VAE model already exists"
fi

# CLIP
if [ ! -f "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then
    echo "Downloading CLIP model..."
    wget --header="Authorization: Bearer $HF_TOKEN" --progress=bar:force -O "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        "https://huggingface.co/ratoenien/umt5_xxl_fp8_e4m3fn_scaled/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
else
    echo "✓ CLIP model already exists"
fi

# LoRA
if [ ! -f "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" ]; then
    echo "Downloading LoRA model..."
    wget --header="Authorization: Bearer $HF_TOKEN" --progress=bar:force -O "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" \
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
check_file "models/unet/Wan2.1-VACE-14B-Q8_0.gguf"
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

# 📄 Create instructions file
cat > "input/README.txt" << 'EOF'
UPLOAD THESE FILES TO THIS DIRECTORY:
=====================================
1. Vote For Pedro.png
2. Napolean Dynamite Dance - 16 by 9.mp4

The workflow is configured to use these exact filenames.
EOF

# 🧠 Create WanVace workflow using Q8_0 UNET
echo ""
echo "📄 Writing workflow to: workflows/WanVace_Q8_Workflow.json..."

cat > "workflows/WanVace_Q8_Workflow.json" << 'EOF'
{
  "3": {
    "inputs": {
      "seed": 859911411659251,
      "steps": 20,
      "cfg": 4,
      "sampler_name": "uni_pc",
      "scheduler": "normal",
      "denoise": 1,
      "model": ["48", 0],
      "positive": ["49", 0],
      "negative": ["49", 1],
      "latent_image": ["49", 2]
    },
    "class_type": "KSampler",
    "_meta": {"title": "KSampler"}
  },
  "6": {
    "inputs": {
      "text": "The girl is dancing in a sea of flowers, slowly moving her hands. There is a close - up shot of her upper body. The character is surrounded by other transparent glass flowers in the style of Nicoletta Ceccoli, creating a beautiful, surreal, and emotionally expressive movie scene with a white, transparent feel and a dreamy atmosphere.",
      "clip": ["109", 1]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {"title": "CLIP Text Encode (Positive Prompt)"}
  },
  "7": {
    "inputs": {
      "text": "Overexposure, blurred, subtitles, paintings, poorly drawn hands/faces, deformed limbs, cluttered background ",
      "clip": ["109", 1]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {"title": "CLIP Text Encode (Negative Prompt)"}
  },
  "8": {
    "inputs": {
      "samples": ["58", 0],
      "vae": ["39", 0]
    },
    "class_type": "VAEDecode",
    "_meta": {"title": "VAE Decode"}
  },
  "39": {
    "inputs": {
      "vae_name": "wan_2.1_vae.safetensors"
    },
    "class_type": "VAELoader",
    "_meta": {"title": "Load VAE"}
  },
  "48": {
    "inputs": {
      "shift": 8.000000000000002,
      "model": ["109", 0]
    },
    "class_type": "ModelSamplingSD3",
    "_meta": {"title": "ModelSamplingSD3"}
  },
  "49": {
    "inputs": {
      "width": ["115", 1],
      "height": ["115", 2],
      "length": 81,
      "batch_size": 1,
      "strength": 1,
      "positive": ["6", 0],
      "negative": ["7", 0],
      "vae": ["39", 0],
      "control_video": ["78", 0],
      "reference_image": ["73", 0]
    },
    "class_type": "WanVaceToVideo",
    "_meta": {"title": "WanVaceToVideo"}
  },
  "58": {
    "inputs": {
      "trim_amount": ["49", 3],
      "samples": ["3", 0]
    },
    "class_type": "TrimVideoLatent",
    "_meta": {"title": "TrimVideoLatent"}
  },
  "73": {
    "inputs": {
      "image": "example.png"
    },
    "class_type": "LoadImage",
    "_meta": {"title": "Load Image"}
  },
  "75": {
    "inputs": {
      "images": ["78", 0]
    },
    "class_type": "PreviewImage",
    "_meta": {"title": "Preview Image"}
  },
  "78": {
    "inputs": {
      "low_threshold": 0.4,
      "high_threshold": 0.8,
      "image": ["115", 0]
    },
    "class_type": "Canny",
    "_meta": {"title": "Canny"}
  },
  "109": {
    "inputs": {
      "PowerLoraLoaderHeaderWidget": {"type": "PowerLoraLoaderHeaderWidget"},
      "lora_1": {
        "on": false,
        "lora": "Wan21_CausVid_14B_T2V_lora_rank32.safetensors",
        "strength": 0.25
      },
      "➕ Add Lora": "",
      "model": ["124", 0],
      "clip": ["117", 0]
    },
    "class_type": "Power Lora Loader (rgthree)",
    "_meta": {"title": "Power Lora Loader (rgthree)"}
  },
  "112": {
    "inputs": {
      "frame_rate": 16,
      "loop_count": 0,
      "filename_prefix": "vace_14b",
      "format": "video/nvenc_h264-mp4",
      "pix_fmt": "yuv420p",
      "bitrate": 10,
      "megabit": true,
      "save_metadata": true,
      "pingpong": false,
      "save_output": true,
      "images": ["8", 0]
    },
    "class_type": "VHS_VideoCombine",
    "_meta": {"title": "Video Combine 🎥🅥🅗🅢"}
  },
  "114": {
    "inputs": {
      "video": "original.mp4",
      "force_rate": 0,
      "custom_width": 0,
      "custom_height": 0,
      "frame_load_cap": 0,
      "skip_first_frames": 0,
      "select_every_nth": 1,
      "format": "Wan"
    },
    "class_type": "VHS_LoadVideo",
    "_meta": {"title": "Load Video (Upload) 🎥🅥🅗🅢"}
  },
  "115": {
    "inputs": {
      "width": 720,
      "height": 720,
      "interpolation": "nearest-exact",
      "method": "fill / crop",
      "condition": "always",
      "multiple_of": 0,
      "image": ["114", 0]
    },
    "class_type": "ImageResize+",
    "_meta": {"title": "🔧 Image Resize"}
  },
  "117": {
    "inputs": {
      "clip_name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors",
      "type": "wan",
      "device": "default"
    },
    "class_type": "ClipLoaderGGUF",
    "_meta": {"title": "GGUF CLIP Loader"}
  },
  "124": {
    "inputs": {
      "any_01": ["125", 0]
    },
    "class_type": "Any Switch (rgthree)",
    "_meta": {"title": "Model switch"}
  },
  "125": {
    "inputs": {
      "unet_name": "Wan2.1-VACE-14B-Q8_0.gguf"
    },
    "class_type": "UnetLoaderGGUF",
    "_meta": {"title": "Unet Loader (GGUF)"}
  }
}
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
