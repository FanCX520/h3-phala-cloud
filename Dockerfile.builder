# syntax=docker/dockerfile:1
# ═══════════════════════════════════════════════════════════════════
#  MiniMax H3 + ComfyUI v0.30.1 · H200/H300 运行时
#
#  此镜像在本地 / GitHub Actions 构建后推送到 GHCR，
#  Phala Cloud DStack 通过 image: 直接拉取，不再现场构建。
#
#  本地构建:
#    docker build -t ghcr.io/fancx520/h3-phala-cloud:latest .
#
#  Mac ARM:
#    docker buildx build --platform linux/amd64 \
#      -t ghcr.io/fancx520/h3-phala-cloud:latest .
# ═══════════════════════════════════════════════════════════════════
ARG BASE_IMAGE=pytorch/pytorch:2.8.0-cuda12.8-cudnn9-runtime

# ───────────────────────── 1. 运行时依赖 ─────────────────────────
FROM ${BASE_IMAGE} AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/workspace/hf_cache

ARG HTTP_PROXY=""
ARG HTTPS_PROXY=""
ARG NO_PROXY=""
ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        git \
        curl \
        ffmpeg \
        libgl1 \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
        libgomp1 \
        ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# ───────────────────────── 2. ComfyUI v0.30.1 ─────────────────────────
WORKDIR /workspace
ARG COMFYUI_TAG=v0.30.1
RUN git clone --depth 1 --branch ${COMFYUI_TAG} \
        https://github.com/comfyanonymous/ComfyUI.git

# ───────────────────────── 3. ComfyUI-Manager ─────────────────────────
ARG COMFYUI_MANAGER_REPO=https://github.com/ltdrdata/ComfyUI-Manager.git
ARG COMFYUI_MANAGER_REF=main
RUN git clone --depth 1 --branch ${COMFYUI_MANAGER_REF} ${COMFYUI_MANAGER_REPO} \
        /workspace/ComfyUI/custom_nodes/ComfyUI-Manager

# ───────────────────────── 4. Python 依赖 ─────────────────────────
# 锁定 torch / torchvision / torchaudio 到镜像同源版本，避免 ComfyUI
# requirements.txt 引入不兼容的 wheel（CUDA ABI 错配是常见崩溃点）。
WORKDIR /workspace/ComfyUI
RUN grep -Eiv '^(torch|torchvision|torchaudio)([<>=~! ].*)?$' requirements.txt \
        > /tmp/comfyui-requirements.txt \
 && pip install --no-cache-dir -r /tmp/comfyui-requirements.txt \
 && pip install --no-cache-dir -r custom_nodes/ComfyUI-Manager/requirements.txt \
 && pip install --no-cache-dir -U \
        huggingface_hub \
        hf_transfer \
        psutil \
        requests \
 && pip cache purge

# ───────────────────────── 5. 启动脚本 ─────────────────────────
COPY scripts/ /workspace/scripts/
RUN sed -i 's/\r$//' /workspace/scripts/entrypoint.sh \
 && chmod +x /workspace/scripts/entrypoint.sh

# ───────────────────────── 6. 运行时配置 ─────────────────────────
VOLUME ["/workspace/ComfyUI/models", \
        "/workspace/ComfyUI/output", \
        "/workspace/ComfyUI/input", \
        "/workspace/ComfyUI/user", \
        "/workspace/ComfyUI/custom_nodes", \
        "/workspace/hf_cache", \
        "/workspace/tmp"]

EXPOSE 8188

HEALTHCHECK --interval=30s --timeout=5s --start-period=5m --retries=10 \
    CMD curl -fsS http://127.0.0.1:8188/system_stats || exit 1

CMD ["/workspace/scripts/entrypoint.sh"]
