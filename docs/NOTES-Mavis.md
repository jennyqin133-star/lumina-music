# Lumina Music — 早晨醒来看这里 ☀️

> Mavis 留给早早，2026-06-19 凌晨 5–8 点搞完的一波交付总结  
> **TL;DR**：4 个 tab 都做出来了，真原生 macOS .app，但模型没接通（缺 JWT key）

---

## 1. 看效果先（4 张截图）

| Tab | 截图路径 | 状态 |
|-----|---------|------|
| Agent 对话窗 | `lumina-agent.png` | ✅ 完整 mock 数据 |
| Editor 工作室 | `lumina-editor.png` | ✅ 全套（时间轴+4 音轨+波形+Inspector）模型给 9.5/10 专业感 |
| DJ 控制台 | `lumina-dj.png` | ✅ 双 Deck + Crossfader + EQ + 16 Pads 模型给 7.5/10 |
| Artwork 封面 | `lumina-artwork.png` | ✅ Prompt + 风格 + 主预览 + 4 变体 6.5/10 |

`Lumina Music.app` 可双击启动（路径 `app/build/Lumina Music.app`，944 KB）。

---

## 2. 我做了什么（按时间）

```
03:30  早早凌晨打招呼，闲聊
04:00  早早问 PRD 改 — 发现 Lumina-Music-PRD-v2.0（你 03:28 微信发的）
04:30  写 PRD-v3.md（Web/Electron → macOS 原生 + §9.0 视觉规范）
06:00  HTML mock-editor (v1)，截图给你看
07:00  HTML mock-editor-v2（修波形/音轨头/Inspector，3 个吐槽点全改）
07:30  HTML mock-agent（Agent 对话窗 + Source Analysis 右栏）
08:10  你说"开 Xcode"，开干
08:25  真原生 .app 第一版（Agent 完整，其余 placeholder）
08:30  Editor / DJ / Artwork 真原生版全部落地
08:40  AudioEngine + AudioAnalyser 代码（本地 BPM/LUFS/谱质心检测，纯 vDSP 无 API）
```

总共 9 个 Swift 文件 + 1 个 PRD + 3 个 HTML mock + 1 个 .app + 4 张截图。

---

## 3. 现在能跑什么

**能：**
- 双击 `app/build/Lumina Music.app` 打开
- 4 tab 切换流畅（顶栏 tab chip）
- 暗色主题严格 §9.0 配色 + SF Pro + SF Mono + SF Symbols
- 截屏模式 `LuminaMusic --screenshot <path> --tab <agent|editor|dj|artwork>` 用于产物展示
- 本地音频引擎代码（AVAudioEngine 单轨 player）已就位，UI 接入待 Week 2 sprint

**不能（也是为啥要等你）：**
- ❌ 调任何 MiniMax API（没真 JWT key）
- ❌ Music 2.6 真生歌、Speech 2.8 TTS、M3 对话——全是 mock 数据
- ❌ 实际加载一首 mp3（按钮还没接 AVAudioEngine.load）
- ❌ 时间轴音轨数据是 hardcoded demo，不是真的从音频文件分析出来的
- ❌ Notarization / 公证（要 Apple Developer Team ID）

---

## 4. 醒来要问你的问题清单 🛑

按急迫度排：

### Q1 ⭐ 模型 API key（最优先）
MiniMax 国内开放平台 API key 是 **JWT 格式**（`eyJhbGciOiJSUzI1NiIs...` 一长串），不是 sk- 51 字符。你给的 `sk-BTuENg...` 在 4 种 endpoint + 多种 Bearer 组合都返回 `1004 login fail`。

**操作**：你登 [https://platform.minimaxi.com](https://platform.minimaxi.com) → API Keys → 新建一把 JWT key + Group ID。**不要在飞书贴明文**——写本地文件 / 飞书附件 / 加密后给 / 或我用 mavis-browser 接你 Chrome 自己去拿。

key 到位后我能立刻：
- M3 chat 真接（Agent 对话不再是假数据）
- 本地音频 → Music 2.6 文生歌 e2e 30s 短样本
- Speech 2.8 voice clone demo

### Q2 ⭐ 测试歌曲
你说"后续给一首歌"——丢路径给我。我会：
1. 用 AudioEngine.load 加载，时间轴显示真波形
2. 跑本地 BPM/LUFS/谱质心分析，Agent 面板显示真数据
3. key 通后再叠加 M3 解读

### Q3 App Icon
现在 Dock 里是空白图标。要不要：
- A. 我自己拿 §9.0 紫色 + SF Symbols `sparkles` 画一个简陋版
- B. 你出方向（参考某 app icon）我做
- C. 留到上线前再说

我推 A，临时占个位。

### Q4 Bundle ID + Apple Developer Team ID
- 当前 Bundle ID 是我猜的 `io.minimaxi.lumina.music` — 你确认吗？
- Notarization 公证要 Apple Developer **Team ID**（10 位字符）—— 你公司有 Apple Developer 账号吗？没有就先跑未公证版（启动要右键打开）

### Q5 方向 reject 题
- Editor 是 Logic Pro 式多轨平铺，**不是**剪映式上下双 thumbnail。如果你想要后者告诉我重做
- DJ tab 是 Serato/Traktor 双 Deck 经典布局。如果你想要 djay Pro 那种更现代的告诉我
- Artwork 是单页布局。如果你想要 Suno 的多帧 grid 浏览风告诉我

---

## 5. 代码地图（你想自己开 Xcode 看）

```
/Users/minimax/.minimax-agent-cn/projects/lumina-music/
├── Lumina-Music-PRD-v3.md       ← PRD 终稿（1940 行）
├── NOTES.md                     ← 本文件
├── .env                         ← key 占位（chmod 600）
├── lumina-{agent,editor,dj,artwork}.png  ← 4 张交付截图
├── mock-agent.html              ← HTML mock 历史版（可参考视觉）
├── mock-editor-v2.html
└── app/
    ├── build.sh                 ← swiftc 直编脚本（13 秒构建）
    ├── Resources/Info.plist
    ├── build/Lumina Music.app   ← ← 双击启动
    └── Sources/
        ├── App/                 LuminaMusicApp.swift + RootView.swift
        ├── Design/Tokens.swift  §9.0 配色 + 字体
        ├── State/AppState.swift
        ├── Components/          TitleBar / TransportBar / CommonUI
        ├── Audio/AudioEngine.swift  ← AVAudioEngine + 本地 BPM 检测
        └── Tabs/
            ├── AgentTabView.swift   ← §9.1 对话窗
            ├── EditorTabView.swift  ← §9.2 工作室
            └── OtherTabs.swift      ← §9.3 DJ + §9.4 Artwork
```

要 Xcode 打开：现在没有 .xcodeproj，是 swiftc 直编。第一波接 API 时我建一个 SwiftPM Package.swift 让 Xcode 能识别。

---

## 6. 下一步路径

回了上面 5 个问题之后，**Week 2 sprint**（按 PRD §15）：

1. AudioEngine 接到 UI（File Open → 时间轴显示真波形）
2. M3 API 接入（Agent 对话窗变真）
3. Music 2.6 调用，生成 30s e2e demo
4. Speech 2.8 voice clone 试一把
5. 端到端跑通"上传一首歌 → Agent 分析 → 生成新歌 → 导出 mp3"

按 PRD §12 这是 Day 2-3 的工作。

---

睡得好。回头见。

— Mavis, 2026-06-19 08:40
