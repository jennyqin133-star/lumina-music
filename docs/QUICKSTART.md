# 5 步发布 Lumina Music — 速记

> 已经把每一步浓缩到一行命令。卡住任何一步,把报错粘给 Claude。

---

## 准备 (做一次)

```bash
# 1) Homebrew (如果没装)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2) gh CLI 登录
brew install gh && gh auth login
```

---

## Phase 1-2 一键脚本

```bash
cd ~/.minimax-agent-cn/projects/lumina-music
./scripts/first-time-setup.sh
```

这一个脚本搞定:
- 替换 USERPLACEHOLDER 为你的 GitHub username
- 创建 GitHub 仓库
- 推送 main
- 生成 Sparkle EdDSA 密钥对 + 上传到 GitHub Secrets
- (可选) 引导你配 Apple Developer 6 个 secrets

---

## Phase 3 — JWT (5 分钟)

浏览器打开 https://platform.minimaxi.com → API Keys → 新建 → 复制完整 JWT + Group ID。

```bash
mkdir -p ~/.config/lumina && chmod 700 ~/.config/lumina
cat > ~/.config/lumina/secrets.env <<EOF
MINIMAX_API_KEY=粘贴JWT
MINIMAX_GROUP_ID=粘贴GroupID
MINIMAX_API_BASE=https://api.minimaxi.com
EOF
chmod 600 ~/.config/lumina/secrets.env
```

---

## Phase 4 — 启用 GitHub Pages (1 分钟)

浏览器打开 https://github.com/你的名/lumina-music/settings/pages
- Source = **Deploy from a branch**
- Branch = **gh-pages**  (CI 第一次跑会自动建)
- 保存

---

## Phase 5 — 发版

```bash
./scripts/release.sh v0.1.1 "First distribution build"
# 答 y 推送

gh run watch       # 5-10 分钟,等绿
gh release view v0.1.1 --web   # 浏览器看产物
```

---

## 用另一台 Mac 验证

1. 浏览器打开 `https://github.com/你的名/lumina-music/releases/latest`
2. 下载 `Lumina-Music-0.1.1.dmg`
3. 双击挂载 → 把 Lumina Music.app 拖到 Applications → 启动
   - 签了 Apple Dev: 直接打开
   - ad-hoc 签的: 右键 → 打开 → 一次确认
4. ⌘, 粘 JWT → ⌘O 选首歌 → Agent 自动分析
5. ⌘⇧G → 选语言 → 生成

成功的话 v0.1.1 这条线已经打通。我会接着推 v0.2.0 / v0.3.0,你的 Sparkle 24h 内会自动弹"有更新"。

---

## 后续每次发版

```bash
git pull
./scripts/release.sh v0.2.0 "what's new in 0.2.0"
gh run watch
```
