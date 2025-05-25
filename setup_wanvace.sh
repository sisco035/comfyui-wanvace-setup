#!/bin/bash

echo "================================================"
echo "WanVace Workflow Auto-Setup Script"
echo "================================================"
echo ""

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

# Install custom nodes
echo ""
echo "Installing custom nodes..."
cd custom_nodes

# Function to install node
install_node() {
    local folder="$1"
    local repo="$2"
    
    if [ ! -d "$folder" ]; then
        echo "  Installing $folder..."
        git clone -q "$repo" "$folder"
        if [ -f "$folder/requirements.txt" ]; then
            pip install -q -r "$folder/requirements.txt" 2>/dev/null
        fi
    else
        echo "  ✓ $folder already installed"
    fi
}

# Install all required nodes
install_node "rgthree-comfy" "https://github.com/rgthree/rgthree-comfy.git"
install_node "ComfyUI-VideoHelperSuite" "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
install_node "ComfyUI-GGUF" "https://github.com/city96/ComfyUI-GGUF.git"
install_node "comfyui_controlnet_aux" "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
install_node "ComfyUI-KJNodes" "https://github.com/kijai/ComfyUI-KJNodes.git"
install_node "ComfyUI-WanVace" "https://github.com/JettHu/ComfyUI-WanVace.git"

# Install sage-attention
echo ""
echo "Installing sage-attention..."
pip install -q sage-attention

# Return to ComfyUI root
cd "$COMFYUI_DIR"

# Create model directories
mkdir -p models/unet models/vae models/clip models/loras

# Download models
echo ""
echo "Downloading models (this will take 10-20 minutes)..."
echo ""

# UNET Model - Q8_0 version (large file)
if [ ! -f "models/unet/Wan2.1-VACE-14B-Q8_0.gguf" ]; then
    echo "Downloading UNET model (Q8_0 - ~15GB)..."
    wget -q --show-progress -O "models/unet/Wan2.1-VACE-14B-Q8_0.gguf" \
        "https://huggingface.co/JettHu/Wan2.1-VACE-14B-GGUF/resolve/main/Wan2.1-VACE-14B-Q8_0.gguf"
else
    echo "✓ UNET model already exists"
fi

# VAE Model
if [ ! -f "models/vae/wan_2.1_vae.safetensors" ]; then
    echo "Downloading VAE model..."
    wget -q --show-progress -O "models/vae/wan_2.1_vae.safetensors" \
        "https://huggingface.co/JettHu/Wan2.1-VACE-14B/resolve/main/vae/wan_2.1_vae.safetensors"
else
    echo "✓ VAE model already exists"
fi

# CLIP Model
if [ ! -f "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then
    echo "Downloading CLIP model..."
    wget -q --show-progress -O "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        "https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q8_0.gguf"
else
    echo "✓ CLIP model already exists"
fi

# LoRA Model
if [ ! -f "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" ]; then
    echo "Downloading LoRA model..."
    wget -q --show-progress -O "models/loras/Wan21_CausVid_14B_T2V_lora_rank32.safetensors" \
        "https://huggingface.co/JettHu/Wan21_CausVid_14B_T2V_LoRA/resolve/main/Wan21_CausVid_14B_T2V_lora_rank32.safetensors"
else
    echo "✓ LoRA model already exists"
fi

# Create directories
mkdir -p input workflows

# Create workflow file
echo ""
echo "Creating workflow file..."
cat > "workflows/WanVace_Q8_Workflow.json" << 'EOF'
{
  "3": {
    "inputs": {
      "seed": 859911411659251,
      "steps": 12,
      "cfg": 1,
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
      "text": "The boy throws a steak",
      "clip": ["109", 1]
    },
    "class_type": "CLIPTextEncode",
    "_meta": {"title": "CLIP Text Encode (Positive Prompt)"}
  },
  "7": {
    "inputs": {
      "text": "Overexposure, blurred, subtitles, paintings, poorly drawn hands/faces, deformed limbs, cluttered background",
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
      "width": ["157", 0],
      "height": ["156", 0],
      "length": ["158", 0],
      "batch_size": 1,
      "strength": 1,
      "positive": ["6", 0],
      "negative": ["7", 0],
      "vae": ["39", 0],
      "control_video": ["129", 0],
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
      "image": "Vote For Pedro.png"
    },
    "class_type": "LoadImage",
    "_meta": {"title": "Load Image"}
  },
  "75": {
    "inputs": {
      "images": ["129", 0]
    },
    "class_type": "PreviewImage",
    "_meta": {"title": "Preview Image"}
  },
  "107": {
    "inputs": {
      "unet_name": "Wan2.1-VACE-14B-Q8_0.gguf"
    },
    "class_type": "UnetLoaderGGUF",
    "_meta": {"title": "Unet Loader (GGUF)"}
  },
  "108": {
    "inputs": {
      "sage_attention": "auto",
      "model": ["124", 0]
    },
    "class_type": "PathchSageAttentionKJ",
    "_meta": {"title": "Patch Sage Attention KJ"}
  },
  "109": {
    "inputs": {
      "PowerLoraLoaderHeaderWidget": {"type": "PowerLoraLoaderHeaderWidget"},
      "lora_1": {
        "on": true,
        "lora": "Wan21_CausVid_14B_T2V_lora_rank32.safetensors",
        "strength": 0.7
      },
      "➕ Add Lora": "",
      "model": ["108", 0],
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
      "video": "Napolean Dynamite Dance - 16 by 9.mp4",
      "force_rate": 16,
      "custom_width": 0,
      "custom_height": 0,
      "frame_load_cap": 0,
      "skip_first_frames": 0,
      "select_every_nth": 1,
      "format": "AnimateDiff"
    },
    "class_type": "VHS_LoadVideo",
    "_meta": {"title": "Load Video (Upload) 🎥🅥🅗🅢"}
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
      "any_02": ["107", 0]
    },
    "class_type": "Any Switch (rgthree)",
    "_meta": {"title": "Model switch"}
  },
  "129": {
    "inputs": {
      "detect_hand": "enable",
      "detect_body": "enable",
      "detect_face": "enable",
      "resolution": 512,
      "scale_stick_for_xinsr_cn": "disable",
      "image": ["114", 0]
    },
    "class_type": "OpenposePreprocessor",
    "_meta": {"title": "OpenPose Pose"}
  },
  "156": {"inputs": {"value": 960}, "class_type": "INTConstant", "_meta": {"title": "Height"}},
  "157": {"inputs": {"value": 544}, "class_type": "INTConstant", "_meta": {"title": "Width"}},
  "158": {"inputs": {"value": 156}, "class_type": "INTConstant", "_meta": {"title": "Length"}},
  "187": {"inputs": {"video_info": ["114", 3]}, "class_type": "VHS_VideoInfo", "_meta": {"title": "Video Info 🎥🅥🅗🅢"}},
  "188": {"inputs": {"output": "", "source": ["187", 4]}, "class_type": "Display Any (rgthree)", "_meta": {"title": "Height"}},
  "189": {"inputs": {"output": "", "source": ["187", 3]}, "class_type": "Display Any (rgthree)", "_meta": {"title": "Width"}},
  "190": {"inputs": {"output": "", "source": ["187", 2]}, "class_type": "Display Any (rgthree)", "_meta": {"title": "Duration"}},
  "191": {"inputs": {"output": "", "source": ["187", 0]}, "class_type": "Display Any (rgthree)", "_meta": {"title": "FPS"}},
  "192": {"inputs": {"output": "", "source": ["187", 1]}, "class_type": "Display Any (rgthree)", "_meta": {"title": "NUMBER OF FRAMES"}}
}
EOF

# Create instructions file
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
echo ""
echo "📁 ComfyUI is at: $COMFYUI_DIR"
echo ""
echo "📋 To use the workflow:"
echo ""
echo "1. Upload your files to: $COMFYUI_DIR/input/"
echo "   • Vote For Pedro.png"
echo "   • Napolean Dynamite Dance - 16 by 9.mp4"
echo ""
echo "2. In ComfyUI web interface:"
echo "   • Click 'Load'"
echo "   • Select: workflows/WanVace_Q8_Workflow.json"
echo ""
echo "3. Click 'Queue Prompt' to generate!"
echo ""
echo "💡 GPU Requirements: 24GB+ VRAM recommended"
echo "================================================"
