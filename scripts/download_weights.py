#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MiniMax-H3 权重预下载：字节级校验 + 断点续传。

仅用于本地预热或离线环境，Phala 上由 ComfyUI 工作流按需下载。
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from huggingface_hub import hf_hub_download

COMFY_HOME = Path("/workspace/ComfyUI")
CACHE_HOME = Path(os.environ.get("HF_HOME", "/workspace/hf_cache"))
os.environ["HF_HOME"] = str(CACHE_HOME)
os.environ.setdefault("HF_HUB_ENABLE_HF_TRANSFER", "0")

REPO_ID = "Comfy-Org/MiniMax-H3"

FILE_SIZES = {
    "diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors":  20970379616,
    "diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors": 20970379616,
    "text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors":         15687142551,
    "vae/minimax_h3_video_vae_fp16.safetensors":                           5207808496,
    "vae/minimax_h3_audio_vae_fp32.safetensors":                            605254808,
}

PROFILE = os.environ.get("WEIGHT_PROFILE", "T2V").upper()
if PROFILE not in ("T2V", "R2V"):
    sys.exit('WEIGHT_PROFILE 只能是 "T2V" 或 "R2V"')

DIT = (
    "diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors"
    if PROFILE == "T2V"
    else "diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
)
NEED_FILES = [
    DIT,
    "text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors",
    "vae/minimax_h3_video_vae_fp16.safetensors",
    "vae/minimax_h3_audio_vae_fp32.safetensors",
]

MODELS_DIR = COMFY_HOME / "models"
MODELS_DIR.mkdir(parents=True, exist_ok=True)

total_gib = sum(FILE_SIZES[f] for f in NEED_FILES) / 1024 ** 3
print(f"套餐「{PROFILE}」共 {total_gib:.2f} GiB，目标目录：{MODELS_DIR}")

for rel in NEED_FILES:
    expected = FILE_SIZES[rel]
    dst = MODELS_DIR / rel
    dst.parent.mkdir(parents=True, exist_ok=True)

    if dst.exists() and dst.stat().st_size == expected:
        print(f"[跳过] {rel} 已完整")
        continue
    if dst.exists():
        print(f"[重下] {rel} 大小不符，删除残档")
        dst.unlink()

    print(f"[下载] {rel} ...")
    got = Path(
        hf_hub_download(
            repo_id=REPO_ID,
            filename=rel,
            local_dir=MODELS_DIR,
            token=os.environ.get("HF_TOKEN") or None,
        )
    )
    actual = got.stat().st_size
    if actual != expected:
        raise RuntimeError(f"{rel} 校验失败：{actual} != {expected}")
    print(f"[完成] {rel}（{actual / 1024 ** 3:.2f} GiB）")

print("\n权重全部就绪 ✔")
