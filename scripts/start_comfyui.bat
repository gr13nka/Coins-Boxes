@echo off
REM Start ComfyUI for icon generation (Windows)
REM Usage: scripts\start_comfyui.bat

set COMFYUI_DIR=%USERPROFILE%\ComfyUI

if not exist "%COMFYUI_DIR%" (
    echo ComfyUI not found at %COMFYUI_DIR%
    echo Run: python scripts\setup_comfyui.py
    exit /b 1
)

echo Starting ComfyUI with --novram (full CPU offloading)...
echo Web UI: http://127.0.0.1:8188
echo Press Ctrl+C to stop.
echo.

cd /d "%COMFYUI_DIR%"
call venv\Scripts\activate.bat
python main.py --novram
