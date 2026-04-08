#!/usr/bin/env python3
"""Install ComfyUI + FLUX.1 Dev GGUF for icon generation.

Works on Linux and Windows. Requires:
  - Python 3.10+
  - Git
  - NVIDIA GPU with CUDA support (8GB+ VRAM recommended)
  - ~20GB free disk space

Usage:
    python3 scripts/setup_comfyui.py              # full install
    python3 scripts/setup_comfyui.py --models-only # download models only (ComfyUI already installed)
    python3 scripts/setup_comfyui.py --check       # verify installation

The script will:
  1. Clone ComfyUI into ~/ComfyUI (or %USERPROFILE%\\ComfyUI on Windows)
  2. Create a Python venv and install PyTorch + ComfyUI dependencies
  3. Install the ComfyUI-GGUF custom node
  4. Download FLUX.1 Dev Q5 GGUF model (~8.3GB)
  5. Download T5XXL fp8 text encoder (~4.9GB)
  6. Download CLIP-L text encoder (~246MB)
  7. Download FLUX VAE (~168MB)
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import urllib.request
import urllib.error

# ── Configuration ────────────────────────────────────────────────────────

IS_WINDOWS = platform.system() == "Windows"
HOME = os.environ.get("USERPROFILE") if IS_WINDOWS else os.path.expanduser("~")
COMFYUI_DIR = os.path.join(HOME, "ComfyUI")

MODELS = {
    "unet": [
        {
            "filename": "flux1-dev-Q5_K_S.gguf",
            "url": "https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q5_K_S.gguf",
            "size_mb": 8300,
            "description": "FLUX.1 Dev Q5_K_S GGUF (~8.3GB)",
        },
    ],
    "clip": [
        {
            "filename": "clip_l.safetensors",
            "url": "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors",
            "size_mb": 246,
            "description": "CLIP-L text encoder (~246MB)",
        },
        {
            "filename": "t5xxl_fp8_e4m3fn.safetensors",
            "url": "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors",
            "size_mb": 4900,
            "description": "T5XXL fp8 text encoder (~4.9GB)",
        },
    ],
    "vae": [
        {
            "filename": "ae.safetensors",
            "url": "https://huggingface.co/camenduru/FLUX.1-dev-diffusers/resolve/main/vae/diffusion_pytorch_model.safetensors",
            "size_mb": 168,
            "description": "FLUX VAE (~168MB)",
        },
    ],
}

# PyTorch CUDA index for pip
PYTORCH_INDEX = "https://download.pytorch.org/whl/cu124"

# ── Helpers ──────────────────────────────────────────────────────────────

def run(cmd, cwd=None, check=True):
    """Run a shell command, print it, and return the result."""
    print(f"  $ {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=False)
    if check and result.returncode != 0:
        print(f"  ERROR: Command failed with exit code {result.returncode}")
        sys.exit(1)
    return result


def get_venv_python():
    """Return path to the venv Python executable."""
    if IS_WINDOWS:
        return os.path.join(COMFYUI_DIR, "venv", "Scripts", "python.exe")
    return os.path.join(COMFYUI_DIR, "venv", "bin", "python3")


def get_venv_pip():
    """Return path to the venv pip executable."""
    if IS_WINDOWS:
        return os.path.join(COMFYUI_DIR, "venv", "Scripts", "pip.exe")
    return os.path.join(COMFYUI_DIR, "venv", "bin", "pip")


def download_file(url, dest_path, description=""):
    """Download a file with progress reporting."""
    if os.path.exists(dest_path):
        size_mb = os.path.getsize(dest_path) / 1024 / 1024
        print(f"  [SKIP] {description} already exists ({size_mb:.0f}MB)")
        return True

    print(f"  [DOWNLOAD] {description}")
    print(f"    URL: {url}")
    print(f"    Dest: {dest_path}")

    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    tmp_path = dest_path + ".downloading"

    try:
        # Use curl/wget for large files (better resume support), urllib for small
        if shutil.which("curl"):
            result = subprocess.run(
                ["curl", "-L", "--progress-bar", "-o", tmp_path, url],
                capture_output=False,
            )
            if result.returncode != 0:
                raise RuntimeError(f"curl failed with exit code {result.returncode}")
        elif shutil.which("wget"):
            result = subprocess.run(
                ["wget", "--progress=bar:force", "-O", tmp_path, url],
                capture_output=False,
            )
            if result.returncode != 0:
                raise RuntimeError(f"wget failed with exit code {result.returncode}")
        else:
            # Fallback to urllib (no progress bar for large files)
            print("    (no curl/wget found, using Python urllib — no progress bar)")
            urllib.request.urlretrieve(url, tmp_path)

        os.rename(tmp_path, dest_path)
        size_mb = os.path.getsize(dest_path) / 1024 / 1024
        print(f"    OK ({size_mb:.0f}MB)")
        return True

    except Exception as e:
        print(f"    FAILED: {e}")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        return False


# ── Installation steps ───────────────────────────────────────────────────

def install_comfyui():
    """Clone ComfyUI and set up Python venv."""
    print("\n=== Step 1: ComfyUI ===")

    if os.path.isdir(os.path.join(COMFYUI_DIR, ".git")):
        print(f"  ComfyUI already cloned at {COMFYUI_DIR}")
        run(f"git pull", cwd=COMFYUI_DIR, check=False)
    else:
        print(f"  Cloning ComfyUI to {COMFYUI_DIR}...")
        run(f"git clone https://github.com/comfyanonymous/ComfyUI.git \"{COMFYUI_DIR}\"")

    # Create venv
    venv_dir = os.path.join(COMFYUI_DIR, "venv")
    if not os.path.isdir(venv_dir):
        print("  Creating Python virtual environment...")
        run(f"\"{sys.executable}\" -m venv \"{venv_dir}\"")
    else:
        print("  Venv already exists.")

    # Install PyTorch with CUDA
    pip = get_venv_pip()
    print("  Installing PyTorch with CUDA support...")
    run(f"\"{pip}\" install torch torchvision torchaudio --index-url {PYTORCH_INDEX}")

    # Install ComfyUI requirements
    req_file = os.path.join(COMFYUI_DIR, "requirements.txt")
    if os.path.exists(req_file):
        print("  Installing ComfyUI dependencies...")
        run(f"\"{pip}\" install -r \"{req_file}\"")


def install_gguf_node():
    """Install ComfyUI-GGUF custom node for loading GGUF models."""
    print("\n=== Step 2: ComfyUI-GGUF custom node ===")

    node_dir = os.path.join(COMFYUI_DIR, "custom_nodes", "ComfyUI-GGUF")
    if os.path.isdir(os.path.join(node_dir, ".git")):
        print("  ComfyUI-GGUF already installed.")
        run(f"git pull", cwd=node_dir, check=False)
    else:
        print("  Installing ComfyUI-GGUF...")
        run(f"git clone https://github.com/city96/ComfyUI-GGUF.git \"{node_dir}\"")

    # Install GGUF node requirements
    req_file = os.path.join(node_dir, "requirements.txt")
    if os.path.exists(req_file):
        pip = get_venv_pip()
        run(f"\"{pip}\" install -r \"{req_file}\"")


def download_models():
    """Download all required model files."""
    print("\n=== Step 3: Model downloads ===")

    total_mb = sum(m["size_mb"] for group in MODELS.values() for m in group)
    print(f"  Total download size: ~{total_mb / 1024:.1f}GB\n")

    all_ok = True
    for folder, model_list in MODELS.items():
        dest_dir = os.path.join(COMFYUI_DIR, "models", folder)
        os.makedirs(dest_dir, exist_ok=True)

        for model in model_list:
            dest_path = os.path.join(dest_dir, model["filename"])
            ok = download_file(model["url"], dest_path, model["description"])
            if not ok:
                all_ok = False

    return all_ok


def install_pillow():
    """Install Pillow in the venv for post-processing."""
    print("\n=== Step 4: Pillow (for post-processing) ===")
    pip = get_venv_pip()
    run(f"\"{pip}\" install Pillow", check=False)


def check_installation():
    """Verify all components are installed."""
    print("\n=== Checking installation ===\n")
    ok = True

    # ComfyUI
    if os.path.isdir(os.path.join(COMFYUI_DIR, ".git")):
        print("  [OK] ComfyUI cloned")
    else:
        print("  [MISSING] ComfyUI not found at", COMFYUI_DIR)
        ok = False

    # Venv
    venv_python = get_venv_python()
    if os.path.exists(venv_python):
        print("  [OK] Python venv")
    else:
        print("  [MISSING] Python venv")
        ok = False

    # GGUF node
    node_dir = os.path.join(COMFYUI_DIR, "custom_nodes", "ComfyUI-GGUF")
    if os.path.isdir(node_dir):
        print("  [OK] ComfyUI-GGUF node")
    else:
        print("  [MISSING] ComfyUI-GGUF node")
        ok = False

    # Models
    for folder, model_list in MODELS.items():
        for model in model_list:
            path = os.path.join(COMFYUI_DIR, "models", folder, model["filename"])
            if os.path.exists(path):
                size_mb = os.path.getsize(path) / 1024 / 1024
                expected = model["size_mb"]
                if size_mb > expected * 0.9:
                    print(f"  [OK] {model['filename']} ({size_mb:.0f}MB)")
                else:
                    print(f"  [INCOMPLETE] {model['filename']} ({size_mb:.0f}MB, expected ~{expected}MB)")
                    ok = False
            else:
                print(f"  [MISSING] {model['filename']}")
                ok = False

    # Summary
    if ok:
        print("\n  All components installed!")
        print(f"\n  To start ComfyUI:")
        if IS_WINDOWS:
            print(f"    cd {COMFYUI_DIR}")
            print(f"    venv\\Scripts\\activate")
            print(f"    python main.py --novram")
        else:
            print(f"    cd {COMFYUI_DIR} && source venv/bin/activate && python main.py --novram")
        print(f"\n  Then generate icons:")
        print(f"    python3 scripts/generate_icons.py")
    else:
        print("\n  Some components are missing. Run setup again without --check.")

    return ok


# ── Main ─────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Install ComfyUI + FLUX.1 Dev for Merge Arena icon generation"
    )
    parser.add_argument("--models-only", action="store_true",
                        help="Only download models (skip ComfyUI install)")
    parser.add_argument("--check", action="store_true",
                        help="Verify installation without changing anything")
    args = parser.parse_args()

    print("=" * 60)
    print("  ComfyUI + FLUX.1 Dev Setup for Icon Generation")
    print(f"  Platform: {platform.system()} {platform.machine()}")
    print(f"  Install dir: {COMFYUI_DIR}")
    print("=" * 60)

    if args.check:
        sys.exit(0 if check_installation() else 1)

    # Check prerequisites
    if not shutil.which("git"):
        print("\nERROR: git is required. Install it first:")
        if IS_WINDOWS:
            print("  https://git-scm.com/download/win")
        else:
            print("  sudo apt install git  (Ubuntu/Debian)")
            print("  sudo dnf install git  (Fedora)")
        sys.exit(1)

    if not args.models_only:
        install_comfyui()
        install_gguf_node()
        install_pillow()

    success = download_models()

    if not success:
        print("\nSome downloads failed. You can re-run this script to retry.")
        print("Existing files will be skipped automatically.")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("  Setup complete!")
    print("=" * 60)
    check_installation()


if __name__ == "__main__":
    main()
