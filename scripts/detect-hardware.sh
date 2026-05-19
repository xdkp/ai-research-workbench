#!/usr/bin/env bash
# Hardware Detection Script for Pentest Workbench

set -e

# Default values
GPU_AVAILABLE=false
VRAM_GB=0
RAM_GB=0
RECOMMENDED_MODEL="cloud (no local gpu)"
GPU_NAME="None"

# Check System RAM
if command -v free &> /dev/null; then
    RAM_KB=$(free -k | awk '/^Mem:/ {print $2}')
    RAM_GB=$((RAM_KB / 1024 / 1024))
elif command -v sysctl &> /dev/null; then
    RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
fi

# Check GPU and VRAM
if command -v nvidia-smi &> /dev/null; then
    # Try to get VRAM in MB
    VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)
    
    if [[ "$VRAM_MB" =~ ^[0-9]+$ ]]; then
        GPU_AVAILABLE=true
        VRAM_GB=$((VRAM_MB / 1024))
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
        
        # Recommendation Logic
        if [ "$VRAM_GB" -ge 24 ]; then
            RECOMMENDED_MODEL="qwen2.5:32b"
        elif [ "$VRAM_GB" -ge 16 ]; then
            RECOMMENDED_MODEL="qwen2.5:14b"
        elif [ "$VRAM_GB" -ge 8 ]; then
            RECOMMENDED_MODEL="llama3:8b"
        else
            RECOMMENDED_MODEL="cloud (insufficient vram)"
        fi
    fi
elif command -v system_profiler &> /dev/null; then
    # Mac Apple Silicon check
    CHIP=$(system_profiler SPHardwareDataType | awk -F': ' '/Chip/ {print $2}')
    if [[ "$CHIP" == *"Apple"* ]]; then
        GPU_AVAILABLE=true
        GPU_NAME="$CHIP"
        VRAM_GB=$RAM_GB # Unified memory
        
        if [ "$VRAM_GB" -ge 32 ]; then
            RECOMMENDED_MODEL="qwen2.5:32b"
        elif [ "$VRAM_GB" -ge 16 ]; then
            RECOMMENDED_MODEL="qwen2.5:14b"
        else
            RECOMMENDED_MODEL="llama3:8b"
        fi
    fi
fi

# Output JSON
cat <<EOF
{
  "gpu_available": $GPU_AVAILABLE,
  "gpu_name": "$GPU_NAME",
  "vram_gb": $VRAM_GB,
  "ram_gb": $RAM_GB,
  "recommended_model": "$RECOMMENDED_MODEL"
}
EOF
