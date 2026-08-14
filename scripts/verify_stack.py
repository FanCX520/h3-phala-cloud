#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
启动前自检：GPU 可用性 + 三件套版本一致性。

任何一项不满足立即抛错，避免 ComfyUI 启动后因 ABI / CUDA runtime 不匹配
再中途崩溃并陷入重启循环。
"""
from __future__ import annotations

import sys

import torch
import torchvision  # noqa: F401  验证二进制扩展可加载
import torchaudio  # noqa: F401  验证二进制扩展可加载


def fail(msg: str) -> "NoReturn":  # type: ignore[name-defined]
    raise SystemExit(f"[verify_stack] {msg}")


def main() -> int:
    if not torch.cuda.is_available():
        fail("NVIDIA GPU 不可用，请检查 DStack GPU 声明或 nvidia-smi")

    props = torch.cuda.get_device_properties(0)
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"VRAM: {props.total_memory / 1024 ** 3:.1f} GiB")
    print(f"Compute capability: {props.major}.{props.minor}")
    print(f"torch:       {torch.__version__}")
    print(f"torchvision: {torchvision.__version__}")
    print(f"torchaudio:  {torchaudio.__version__}")
    print(f"CUDA (torch): {torch.version.cuda}")

    if not torch.__version__.startswith("2.8.0"):
        fail(f"torch 版本应为 2.8.0.x，实际 {torch.__version__}")
    if not torchvision.__version__.startswith("0.23.0"):
        fail(f"torchvision 版本应为 0.23.0.x，实际 {torchvision.__version__}")
    if not torchaudio.__version__.startswith("2.8.0"):
        fail(f"torchaudio 版本应为 2.8.0.x，实际 {torchaudio.__version__}")
    if torch.version.cuda != "12.8":
        fail(f"CUDA runtime 应为 12.8，实际 {torch.version.cuda}")

    print("[verify_stack] OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
