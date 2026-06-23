# Lumina Music · 发布工作流操作指南

> 这份文档是给项目所有人（你）看的。教你从零拉通 GitHub Release + 自动更新链路。
> Claude 已经把所有脚本和 CI workflow 写好了，你只需要按顺序做这里列的几步。

---

## 0. 全景：DMG 发布到自动更新的完整链路

```
你 (本地)                                GitHub                          用户 (任何 Mac)
─────────────                            ────────                        ──────────────
git tag v0.1.1     ─────push tag────►   .github/workflows/release.yml
                                        │
                                        ├─→ swift build (Linux/macOS runner)
                                        ├─→ codesign w/ Developer ID
                                        ├─→ create DMG
                                        ├─→ xcrun notarytool submit + staple
                                        ├─→ generate_appcast → appcast.xml
                                        ├─→ git push appcast.xml → gh-pages branch
                                        └─→ gh release create
                                            │
                                        ┌───┴────────────────┐
                                        ▼                    ▼
                                GitHub Releases      GitHub Pages
                                (DMG download)       https://USER.github.io/lumina-music/appcast.xml
                                        │                    │
                                        ▼                    │
                                  下载 DMG ──→ Sparkle 框架 ──┘
                                                每 24h 拉一次 appcast.xml
                                                有新版 → 弹出"立即更新"
```

---

## Phase 1 — GitHub 仓库 & gh CLI（10 分钟）

### 1.1 注册 GitHub
浏览器打开 https://github.com/signup ， 用你常用邮箱注册。Username 自己挑，下面叫它 `<USER>`。

### 1.2 装 gh CLI
```bash
# 装 Homebrew（如果没装的话）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 装 gh
brew install gh

# 登录（会弹浏览器，按提示授权）
gh auth login
# 选: GitHub.com → HTTPS → Login with a web browser
```

### 1.3 创建仓库 & 推上去
在项目根目录（你的 lumina-music 目录）里：
```bash
cd ~/.minimax-agent-cn/projects/lumina-music

# 创建公开仓库（公开仓 CI 配额无限）
gh repo create lumina-music --public --source=. --remote=origin --description="AI music studio for macOS"

# 推主分支
git push -u origin main
```

到这一步 `https://github.com/<USER>/lumina-music` 就有了。

### 1.4 启用 GitHub Pages（自动更新需要）
打开 `https://github.com/<USER>/lumina-music/settings/pages` ：
- Source 选 **Deploy from a branch**
- Branch 选 **gh-pages** （还没有这个分支，第一次 release 跑完会自动创建）
- 路径 **/ (root)**
- 保存

第一次 release.yml 跑完会自动建 `gh-pages` 分支，几分钟后 Pages 就可用了。

### 1.5 替换 USER 占位符
项目里有几个文件还写着 `USER` 占位符，等你拿到自己的 GitHub username 后替换：
```bash
# 在项目根:
GITHUB_USER="<你的GitHub用户名>"
sed -i '' "s|USERPLACEHOLDER|${GITHUB_USER}|g" Resources/Info.plist
sed -i '' "s|USER/lumina-music|${GITHUB_USER}/lumina-music|g" README.md
sed -i '' "s|USER\\.github\\.io|${GITHUB_USER}.github.io|g" README.md scripts/sparkle-appcast.sh
git commit -am "config: replace USER placeholder with ${GITHUB_USER}"
git push
```

---

## Phase 2 — Sparkle 自动更新签名密钥（一次性，5 分钟）

Sparkle 用 EdDSA 数字签名校验更新包，确保用户下到的 DMG 没被中间人篡改。
你需要生成一次密钥对：

```bash
cd ~/.minimax-agent-cn/projects/lumina-music

# 一行命令，生成 keypair 并存到 ~/.config/lumina/
./scripts/sparkle-tools.sh generate-keys

# 看到 "Public key:" 后面那一长串 base64 字符串，复制下来
```

把公钥+私钥配置成 GitHub secrets：
```bash
# 公钥（从上面输出复制）
gh secret set SPARKLE_PUBLIC_KEY -b "粘贴公钥"

# 私钥（用文件读，不暴露在 shell 历史）
gh secret set SPARKLE_PRIV_KEY < ~/.config/lumina/sparkle_ed_priv_key
```

**重要：** `~/.config/lumina/sparkle_ed_priv_key` 务必备份（密码管理器存一份）。
万一这个文件丢了，所有已发布版本的用户**无法自动更新**到新版本（要重下 DMG）。

---

## Phase 3 — JWT API key（5 分钟）

这是本地开发用的，不进 git，也不进 GitHub secrets（因为 app 是在用户 Mac 上跑的，
不需要 CI 拿到）。

```bash
mkdir -p ~/.config/lumina
chmod 700 ~/.config/lumina

# 浏览器打开 https://platform.minimaxi.com 拿 JWT + Group ID, 然后:
cat > ~/.config/lumina/secrets.env <<EOF
MINIMAX_API_KEY=粘贴 JWT (eyJhbGciOi... 一长串)
MINIMAX_GROUP_ID=粘贴 Group ID
MINIMAX_API_BASE=https://api.minimaxi.com
EOF

chmod 600 ~/.config/lumina/secrets.env
```

---

## Phase 4 — Apple Developer 签名（可选 · 等批准期可跳过）

没 Apple Developer 也能发 DMG，只是用户第一次打开要右键 → 打开。
等你 $99 下来之后再补这一段：

### 4.1 拿 Team ID
登 https://developer.apple.com/account → Membership Details → 看 **Team ID**（10 字符）

### 4.2 在 Keychain 里申请 Developer ID Application 证书
Mac 上 Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority...
- Email: 你的 Apple ID
- Common Name: `Developer ID Application: <你的名字> (TEAMID)`
- Saved to disk → 保存 .certSigningRequest 文件

到 https://developer.apple.com/account/resources/certificates/add 上传 .certSigningRequest
→ 选 "Developer ID Application" → 下载 .cer 双击导入 Keychain。

### 4.3 导出 .p12 给 CI
Keychain 里找到 "Developer ID Application: ..." → 右键 → Export → 选 .p12 格式 → 设密码。

把 .p12 转成 base64 + 配 GitHub secrets：
```bash
base64 -i "~/Downloads/Developer ID Application.p12" | gh secret set DEVELOPER_ID_CERT_P12_BASE64

gh secret set DEVELOPER_ID_CERT_PASSWORD       # 提示输入 .p12 密码
gh secret set DEVELOPER_ID -b "Developer ID Application: 你的名字 (TEAMID)"
gh secret set APPLE_TEAM_ID -b "你的10位TeamID"
gh secret set APPLE_ID -b "你@email.com"
```

### 4.4 App-Specific Password (用于 notarization)
打开 https://appleid.apple.com → 登录 → 安全 → App-Specific Passwords → 生成
→ 标签写 `lumina-notary` → 拿到 16 字符密码：
```bash
gh secret set APPLE_APP_PASSWORD       # 提示输入 16 字符密码
```

---

## Phase 5 — 发布第一个版本 v0.1.1（5 分钟）

```bash
cd ~/.minimax-agent-cn/projects/lumina-music
./scripts/release.sh v0.1.1 "First dry-run distribution build"
# → 它会:
#   1. 改 Info.plist 版本号
#   2. 改 CHANGELOG.md
#   3. git commit + tag
#   4. 问你"现在推 origin 吗?" — 输 y
```

推上去后实时看 CI：
```bash
gh run watch
```
约 5-10 分钟。CI 跑完后看 release：
```bash
gh release view v0.1.1 --web
# 浏览器打开, DMG 已经挂在 release 上
```

---

## Phase 6 — 在另一台 Mac 验证（10 分钟）

在你电脑外的任意 Mac 上：

1. 浏览器打开 `https://github.com/<USER>/lumina-music/releases/latest`
2. 下载 `Lumina-Music-0.1.1.dmg`
3. 双击挂载 → 把 Lumina Music.app 拖到 Applications
4. 启动：
   - **有 Apple Developer 签名 + 公证：** 双击直接打开
   - **没签名 (ad-hoc)：** 右键 → 打开 → 在弹窗里点"打开"。这是 macOS 第一次警告，
     以后双击就直接开了。

启动后看到 4 个 tab，全是 mock 数据 —— 这就对了，v0.1.1 还没接 API。
但**分发链路已经打通**，后面只需要往 main 推代码 + 发新 tag，所有用户的 Lumina
都会自动弹窗"有新版"。

---

## Phase 7 — 之后的迭代节奏

```bash
# 1. 开发新功能, 比如接通 Agent 对话
git checkout -b feat/agent-real
# ... 改代码 ...
git commit -am "feat: wire ChatService to AgentTabView"
git push origin feat/agent-real

# 2. 开 PR 让 CI 跑一遍（验证编译过 + smoke screenshot ok）
gh pr create --title "Wire real Agent dialogue" --body "MVP Sprint 1"

# 3. PR merge 后
git checkout main && git pull

# 4. 发新版
./scripts/release.sh v0.2.0 "MVP Sprint 1: Agent dialogue connected"
# CI 自动构建签名公证发版,gh-pages 上 appcast.xml 更新

# 5. 用户那边
# 24h 内 (或者用户主动菜单点 "Check for Updates")
# Sparkle 弹窗: "Lumina 0.2.0 is available — Install Update"
# 点 → 自动下载、退出、重启、新版本上
```

---

## 故障排查

### "create-dmg 命令未找到"（本地）
你想本地跑 DMG 打包：`brew install create-dmg`。
CI 里 release.yml 自动装，本地不装也行（让 CI 跑）。

### CI 失败：notarization "Invalid Apple ID"
检查 GitHub Secrets:
- `APPLE_ID` 是你的 Apple ID 邮箱
- `APPLE_APP_PASSWORD` 是 App-Specific Password 不是登录密码
- `APPLE_TEAM_ID` 是 10 字符 Team ID 不是公司全名

### 用户那边"无法验证开发者"
说明 CI 还没拿到 Apple Developer 签名。两个办法：
1. 让用户右键 → 打开 (一次性即可)
2. 你完成 Phase 4 后重发版本

### Sparkle 没弹更新
- 检查 `Resources/Info.plist` 的 `SUFeedURL` 是不是真的你的 GitHub Pages 地址
- 检查 `https://<USER>.github.io/lumina-music/appcast.xml` 浏览器能不能访问
- 命令行测试: `curl https://<USER>.github.io/lumina-music/appcast.xml`

### 想强制立刻检查更新
用户 Mac 上启动 Lumina → Menu Bar → Lumina Music → Check for Updates...

---

## 第一周的目标

- [x] 工作目录重组 + SwiftPM 切换 (我做完了)
- [x] App Icon 生成 (我做完了)
- [x] Sparkle 集成代码 (我做完了)
- [x] 所有 build/sign/package/notarize/release 脚本 (我做完了)
- [x] GitHub Actions CI + Release workflows (我做完了)
- [ ] 你: 注册 GitHub + 创建仓库 + 推 main (Phase 1)
- [ ] 你: 生成 Sparkle keypair + 配 GitHub secrets (Phase 2)
- [ ] 你: 拿 JWT API key (Phase 3)
- [ ] 你: 发 v0.1.1 dry-run (Phase 5)
- [ ] 我们: 在另一台 Mac 验证下载 + 启动 (Phase 6)
- [ ] 之后: 接 API 真实化, 持续发版

— Claude, 2026-06-23
