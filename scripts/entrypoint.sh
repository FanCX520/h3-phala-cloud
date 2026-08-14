#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  ComfyUI v0.30.1 + MiniMax H3 启动入口（H200/H300 单卡）
#  流程：① 启动前校验 GPU 与三件套 → ② 启动 ComfyUI
#
#  模型权重由 ComfyUI 工作流在运行期内通过 huggingface_hub
#  按需下载；这里不主动下载，避免网络抖动拖垮容器启动。
# ═══════════════════════════════════════════════════════════
set -euo pipefail

export HF_HOME="${HF_HOME:-/workspace/hf_cache}"
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-0}"
export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"

echo "======================================================"
echo " [1/2] 校验 GPU / PyTorch / TorchAudio"
echo "======================================================"
python /workspace/scripts/verify_stack.py

echo
echo "======================================================"
echo " [2/2] 启动 ComfyUI（v0.30.1）"
echo "======================================================"
cd /workspace/ComfyUI

exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --output-directory /workspace/ComfyUI/output \
    --input-directory /workspace/ComfyUI/input \
    --temp-directory /workspace/tmp \
    ${COMFYUI_EXTRA_ARGS:-}
