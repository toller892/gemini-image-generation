# 🖼️ Gemini Image Generation (with Live Visualization)

使用 Gemini 的 nano banana 模型自动生成图像的 OpenClaw skill。

集成 noVNC 实时浏览器可视化 + Cloudflare Tunnel 临时公网访问。**专为云端 OpenClaw 实例设计**。

## ✨ 功能

- 🤖 **自动化生图** — agent-browser 自动操作 Gemini 网页端
- 🖥️ **实时可视化** — noVNC + Cloudflare Tunnel，通过浏览器实时观看
- 🔒 **登录持久化** — 首次手动登录后，Chromium profile 保存登录态
- ⏰ **自动超时** — 10 分钟无连接自动关闭全部进程
- 🎨 **风格选择** — Cinematic、Oil painting、Sketch 等多种风格

## 架构

```
User Browser ──HTTPS──▶ Cloudflare Tunnel (临时随机 URL)
                              │
                    noVNC + websockify (:6080)
                              │
                    x11vnc → Xvfb (:99)
                              ▲
                    Chromium (持久化 profile)
                              ▲
                    agent-browser (自动化)
```

## 快速开始

```bash
# 1. 安装依赖（需要 root）
sudo bash scripts/install-deps.sh

# 2. 首次登录（手动）
bash scripts/start-viz.sh --login
# 打开输出的 URL → 登录 Google 账号 → 登录态自动保存

# 3. 之后生图（自动化）
# 在 OpenClaw 对话中直接说：
# "帮我生成一张猫咪编程的图片"
```

## 可用风格

| 风格 | 描述 |
|---|---|
| Cinematic | 电影感，写实 |
| Monochrome | 黑白单色 |
| Oil painting | 油画 |
| Sketch | 素描 |
| Technicolor | 鲜艳色彩 |
| Color block | 色块 |

## 环境要求

- Node.js 18+
- apt 包：xvfb, x11vnc, novnc, websockify
- cloudflared
- agent-browser（含 Chromium）

运行 `scripts/install-deps.sh` 一键安装。

## License

MIT
