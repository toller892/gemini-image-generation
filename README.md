# Gemini Image Generation Skill

🖼️ 使用 Gemini 的 nano banana 模型自动生成图像的 OpenClaw skill。

## 简介

这个 skill 通过 `agent-browser` 命令行工具自动化 Gemini 网页端的图像生成工作流程，包括：
- 登录 Gemini
- 选择图像风格（style）
- 输入提示词
- 等待生成
- 下载图像

## 安装

### 前置要求

1. **OpenClaw** - 已安装并配置
2. **agent-browser** - OpenClaw 内置工具
3. **Gemini 账号** - 需要 Google 账号登录

### 安装步骤

```bash
# 克隆或复制此 skill 到 OpenClaw skills 目录
cp -r gemini-image-generation ~/.openclaw/skills/

# 或者克隆到全局 skills 目录
cp -r gemini-image-generation ~/.npm-global/lib/node_modules/openclaw/skills/
```

## 使用方法

### 基本用法

在 OpenClaw 对话中，当需要生成图像时，系统会自动调用此 skill：

```
用户：帮我生成一张猫咪在电脑前编程的图片
```

### 指定风格

```
用户：用油画风格生成一个机器人在花园浇花的图片
```

### 可用风格

Gemini 提供多种图像风格：
- **Cinematic** - 电影感，写实戏剧化
- **Monochrome** - 黑白单色
- **Oil painting** - 油画艺术风格
- **Sketch** - 手绘素描
- **Technicolor** - 鲜艳色彩
- **Color block** - 色块风格

## 工作流程

```
1. 检查登录状态 → 未登录则手动登录
2. 打开 Gemini 并保存会话
3. 点击 "Create image" 工具
4. 输入图像描述提示词
5. 从 UI 选择风格（重要！）
6. 发送请求
7. 等待 30-60 秒生成
8. 下载生成的图像
```

## 技术细节

### 核心命令

```bash
# 打开 Gemini（使用保存的会话）
agent-browser --session-name gemini open "https://gemini.google.com"

# 截图查看页面元素
agent-browser snapshot -i

# 点击创建图像按钮
agent-browser click @eN

# 填写提示词
agent-browser fill @eN "你的提示词"

# 选择风格（需要 -C 标志查看可点击元素）
agent-browser snapshot -i -C
agent-browser click @eN

# 发送请求
agent-browser click @eN

# 等待生成
agent-browser wait 30000

# 下载图像
agent-browser download @eN ./output.png
```

### 会话管理

**首次使用（需要手动登录）：**
```bash
agent-browser --headed --session-name gemini open "https://gemini.google.com"
# 等待用户登录，会话自动保存
```

**后续使用（自动登录）：**
```bash
agent-browser --session-name gemini open "https://gemini.google.com"
```

**查看保存的会话：**
```bash
agent-browser state list
```

## 常见问题

### 图像不生成
- 检查是否有 "Stop response" 按钮（表示正在生成）
- 等待更长时间（复杂图像可能需要 60 秒）
- 截图调试：`agent-browser screenshot status.png`

### 找不到风格选项
- 使用 `agent-browser snapshot -i -C` 查看可点击元素
- 风格在点击 "Create image" 后才会显示

### 找不到下载按钮
- 查找 "Download full size image" 或 "Copy image" 按钮
- 可能需要滚动：`agent-browser scroll up 500`

### 会话丢失
- 使用 `--headed` 模式重新登录
- 使用 `--session-name` 会自动保存会话

## 注意事项

⚠️ **重要：**
- 风格必须通过 UI 点击选择，**不要**把风格写在提示词里
- 点击风格后需要等待 2 秒让选择生效
- 图像生成至少等待 30 秒
- 使用 `--session-name` 避免重复登录

## 示例

### 示例 1：用户选择风格

```bash
# 打开会话
agent-browser --session-name gemini open "https://gemini.google.com"

# 点击创建图像
agent-browser snapshot -i
agent-browser click @e6

# 输入提示词
agent-browser fill @e10 "一只可爱的猫咪坐在电脑前编程"

# 获取可用风格并让用户选择
agent-browser snapshot -i -C
# 输出可用风格列表给用户选择

# 用户选择后点击对应风格
agent-browser click @e21
agent-browser wait 2000

# 发送并等待
agent-browser click @e13
agent-browser wait 30000

# 下载
agent-browser download @e12 ./cat-coding.png
```

### 示例 2：指定风格

```bash
# 用户说："用油画风格生成一个机器人在花园浇花"
agent-browser --session-name gemini open "https://gemini.google.com"
agent-browser click @e6
agent-browser fill @e10 "一个机器人在花园里浇花"
agent-browser click @e31  # 油画风格
agent-browser wait 2000
agent-browser click @e13
agent-browser wait 30000
agent-browser download @e12 ./robot-garden.png
```

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
