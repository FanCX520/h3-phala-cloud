# MiniMax H3 + ComfyUI · Phala Cloud 镜像方案

| 硬件 | 规格 |
|---|---|
| GPU | NVIDIA H200 / H300 · 141 GB VRAM (sm90, int8/NVFP4) |
| CPU | 24 vCPU |
| RAM | 170 GB |
| 存储 | 1 TB SSD (DStack 加密盘) |
| 网络 | US 机房 (HuggingFace / GitHub 直连) |
| TEE | Intel TDX + NVIDIA CC |

## ★ 思路：GitHub Actions 构建镜像 → Phala 直接 pull ★

不再让 Phala 在容器启动时现场安装依赖。镜像在 GitHub Actions 一次性构建好推送到 **GHCR** (`ghcr.io/fancx520/h3-phala-cloud:<tag>`)，Phala Cloud DStack 部署时只负责 `docker pull`，启动即用。

| 原方案 | 本方案 |
|---|---|
| 容器启动时 apt + clone + pip + 下载权重 | ❌ 不需要 — 全部预构建 |
| NGC CUDA 13 镜像 + torchaudio ABI 冲突 | ❌ 不存在 — 用官方 PyTorch 2.8 CUDA 12.8 |
| 首次启动 10-15 分钟 | ⚡ 首次启动 < 1 分钟 (仅下载工作流需要的权重) |
| 升级 ComfyUI 要等容器重启 | ✅ 推新 tag → CVM 拉新镜像 |

## 文件清单

```
h3-phala-cloud/
├── Dockerfile.builder         # 构建镜像 (本地或 CI)
├── docker-compose.yml         # Phala DStack 部署入口 (只 pull)
├── scripts/
│   ├── entrypoint.sh          # 容器内启动入口
│   ├── verify_stack.py        # 启动前 GPU + 三件套自检
│   └── download_weights.py    # 可选：预下载 MiniMax H3 权重
├── .github/workflows/build.yml  # GitHub Actions: 自动构建 + 推 GHCR
├── .dockerignore
├── .gitignore
└── README.md
```

## 镜像特性

- **基础镜像**：`pytorch/pytorch:2.8.0-cuda12.8-cudnn9-runtime`
  - 官方 PyTorch 2.8 + CUDA 12.8，H200/H300 全功能支持
  - 预装 `torch` / `torchvision` / `torchaudio` 三件套 (CUDA ABI 完全匹配)
- **ComfyUI**：固定 `v0.30.1`
- **ComfyUI-Manager**：固定 `main` 分支
- **Python 依赖**：通过 grep 排除 `torch*` 行，避免 ComfyUI 的 requirements 把官方三件套覆盖成不兼容版本
- **数据卷**：`models` / `output` / `input` / `user` / `custom_nodes` / `hf_cache` / `tmp`
- **启动前自检**：`verify_stack.py` 校验 GPU 可用 + 版本一致 + CUDA runtime = 12.8，任何不满足立即报错退出，避免运行期崩溃

## 部署步骤

### 第 1 步：把仓库推到 GitHub

```bash
cd h3-phala-cloud
git add -A
git commit -m "feat: MiniMax H3 + ComfyUI Phala 镜像"
gh repo create h3-phala-cloud --public --source=. --remote=origin --push
```

第一次 push 后 GitHub Actions 会自动构建镜像并推送到 GHCR。Tag 规则：

| 触发事件 | 生成的 tag |
|---|---|
| push 到 main | `latest` + 分支名 |
| 打 tag `vX.Y.Z` | `vX.Y.Z` + `vX.Y` + `latest` |
| Pull Request | 仅构建不推送 (`pr-NN`) |

### 第 2 步：把镜像设为公开

仓库 → Settings → Packages → `h3-phala-cloud` → Package settings → Change visibility → Public

### 第 3 步：在 Phala Cloud 部署

1. 登录 [cloud.phala.com](https://cloud.phala.com)
2. **GPU TEE** → **Custom Configuration** (Advanced 模式)
3. 把 `docker-compose.yml` 全部内容粘贴进编辑器
4. **不需要**任何 prelaunch 脚本 / build context / 私有 registry 凭据 — 镜像是公开的
5. 选 H200 / H300 实例 → **Deploy**

如果想用其它 tag，把 Compose 第 4 行：
```yaml
IMAGE: &IMAGE ghcr.io/<你的用户名>/h3-phala-cloud:latest
```

### 第 4 步：访问

容器启动后用 Phala 默认公网域名即可访问 ComfyUI (端口 8188 已映射到容器 80 端口)。

## 首次启动时间线

| 阶段 | 耗时 | 说明 |
|---|---|---|
| DStack 初始化 | ~1 分钟 | 加密盘、WireGuard、网络 |
| 公开镜像拉取 | ~1-2 分钟 | 镜像已构建好，免现场安装 |
| GPU + 三件套自检 | < 5 秒 | verify_stack.py |
| ComfyUI 启动 | ~10 秒 | 直接 `python main.py` |
| **合计** | **~3 分钟** | |

模型权重仍由 ComfyUI 工作流在第一次使用时通过 `huggingface_hub` 下载（约 38.6 GiB），写到 `/workspace/ComfyUI/models`，会持久化到 `comfyui-models` 卷。

## 本地构建

```bash
# amd64 (Linux 服务器)
docker build -f Dockerfile.builder -t ghcr.io/<你的用户名>/h3-phala-cloud:dev .

# Apple Silicon
docker buildx build --platform linux/amd64 \
  -f Dockerfile.builder \
  -t ghcr.io/<你的用户名>/h3-phala-cloud:dev .
```

构建过程约 8-12 分钟（克隆 ComfyUI + pip 装依赖）。

## 镜像升级

```bash
# 改完代码，提交并打 tag
git tag v0.30.2
git push origin v0.30.2
# GitHub Actions 自动构建并推送 v0.30.2 / v0.30 / latest 三个 tag

# Phala 端重启 CVM，docker compose 自动拉 latest
```

## 常见问题

| 现象 | 处理 |
|---|---|
| `pull access denied for ghcr.io/...` | GHCR 包未设为 Public，或 repo 名跟用户名不一致 |
| `verify_stack` 报 CUDA 版本不匹配 | 镜像被覆盖构建了；用本仓库的 Dockerfile.builder |
| `libcudart.so.12 not found` | 镜像用 PyTorch 官方 runtime tag，CUDA 12.8；不要换成 NGC CUDA 13 镜像 |
| 想关掉 Manager | 删除 Dockerfile.builder 中 `ComfyUI-Manager` clone 那一段 |
| 想换 ComfyUI 版本 | 改 `ARG COMFYUI_TAG=v0.30.1`，Actions 重新构建 |

## 开源协议

- Apache License 2.0
- 模型权重版权归原作者 (Comfy-Org/MiniMax-H3)
