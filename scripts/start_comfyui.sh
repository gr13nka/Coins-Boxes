#!/bin/bash
# Start ComfyUI for icon generation (Linux/macOS)
# Usage: ./scripts/start_comfyui.sh

COMFYUI_DIR="$HOME/ComfyUI"

if [ ! -d "$COMFYUI_DIR" ]; then
    echo "ComfyUI not found at $COMFYUI_DIR"
    echo "Run: python3 scripts/setup_comfyui.py"
    exit 1
fi

echo "Starting ComfyUI with --novram (full CPU offloading)..."
echo "Web UI: http://127.0.0.1:8188"
echo "Press Ctrl+C to stop."
echo ""

cd "$COMFYUI_DIR" && source venv/bin/activate && python main.py --novram
