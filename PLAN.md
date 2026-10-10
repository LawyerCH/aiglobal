# AI 开发环境纪律系统 · 实施计划

> **执行方式：** 本计划由当前会话直接执行（native）。
> **Goal:** 落地 mise 环境基线 + rulesync 统一规则包，让 opencode/Claude Code/Trae 共享一套可自我维护的开发纪律。
> **Architecture:** rulesync 作为"一处写、多处分发"层；规则源在 `~/.aiglobal/.rulesync/rules/`；mise 管运行时基线。
> **Spec:** `~/.aiglobal/DESIGN.md`

## 全局约束
- 语言：Python 3.12、Node 24（mise 管理）
- 禁止全局装依赖 / sudo 装包（规则层面）
- 生成产物不得手改，只改规则源
- 目标 agent：opencode、claudecode（规则）；trae 仅项目级（暂不在本次范围）

---

### Task 1: 环境基线（mise）
**Files:** Modify `~/.config/mise/config.toml`
- [ ] Step 1: 追加 python 3.12 与安全设置
```bash
mise use -g node@24
mise use -g python@3.12
mise settings set minimum_release_age 3d
```
- [ ] Step 2: 验证
```bash
mise ls --global        # 应含 node 24 / python 3.12
node -v; python3 -v     # 生效
```
- [ ] Step 3: 确认 oh-my-ppt 等既有项目仍能取到所需 node（必要时项目内 mise.toml 锁定）

### Task 2: 安装 rulesync
**Files:** mise 全局工具
- [ ] Step 1: `mise use -g npm:rulesync`
- [ ] Step 2: `rulesync --version`（确认可用）

### Task 3: 初始化规则源
**Files:** Create `~/.aiglobal/rulesync.jsonc`, `~/.aiglobal/.rulesync/**`
- [ ] Step 1: `cd ~/.aiglobal && rulesync init`
- [ ] Step 2: 改写 `rulesync.jsonc` 为：
```jsonc
{
  "$schema": "https://github.com/dyoshikawa/rulesync/releases/latest/download/config-schema.json",
  "global": true,
  "features": ["rules"],
  "targets": ["opencode", "claudecode"]
}
```
- [ ] Step 3: 验证 `rulesync config ls` 或 generate --dry-run 无报错

### Task 4: 并入现有全局规则（不丢失）
**Files:** `.rulesync/rules/*`（导入生成）
- [ ] Step 1: `cd ~/.aiglobal && rulesync import --global --targets opencode`
- [ ] Step 2: 检查 `.rulesync/rules/` 出现导入文件，内容含原 `~/.config/opencode/AGENTS.md` 的条款

### Task 5: 写规则源（3 个文件）
**Files:** Create `.rulesync/rules/00-环境纪律.md`, `10-项目流程.md`, `90-维护协议.md`
- [ ] Step 1: 写 `00-环境纪律.md`
```md
---
root: true
---
# 全局开发环境纪律

## 运行时版本
- 所有语言运行时由 mise 管理（基线：~/.config/mise/config.toml 中 node 24 / python 3.12）
- 新项目用 `mise use node@X python@Y` 把版本写进项目 mise.toml，不要手动指定或另装运行时
- 不要改用 nvm/volta/asdf 等（已统一到 mise）

## 依赖安装
- Node：只用 `pnpm`；禁止 `npm i -g`、禁止全局安装
- Python：只用 `uv`（`uv sync` / `uv add`），依赖装在项目内 `.venv`；禁止全局 `pip install`
- 禁止用 `sudo` 安装任何语言包/运行时
- 装依赖前先看是否有 lockfile（pnpm-lock.yaml / uv.lock），有则锁定安装（`pnpm install --frozen-lockfile` / `uv sync --frozen`）
- 装完依赖后，报告「装了哪些包 + 大约占用多少磁盘」

## 磁盘纪律
- 不在每个项目重复下载运行时，不把依赖装到全局
- 优先复用共享缓存（pnpm store / uv cache）
```
- [ ] Step 2: 写 `10-项目流程.md`
```md
---
root: true
---
# 项目标准流程

## 新建项目
- 位置：~/Projects/<项目名>
- 步骤：mkdir → git init → `mise use node@<版本>`（生成 mise.toml）→ 写最小 AGENTS.md → 写 .gitignore（node_modules、.venv、dist、build）
- 依赖按「环境纪律」用 pnpm/uv 安装

## 克隆/运行陌生项目（先体检）
安装依赖或运行任何脚本前，先输出体检报告：
1. 识别包管理器与语言（package.json / pyproject.toml / go.mod …）
2. 列出「将要执行的安装脚本」（package.json 的 pre/postinstall 等）——风险点
3. 预估依赖数量与安装体积
4. 标出可疑命令（网络下载、curl|bash、sudo、写系统目录）
5. 给出结论：可安全运行 / 建议隔离
未经用户确认，不得对陌生项目执行安装或运行。

## 清理
- 定期（或克隆大项目前）扫描构建产物：node_modules、.venv、target、vendor、build、dist
- 列出各项大小，用户确认后删除
- 全局缓存清理：`pnpm store prune`、`uv cache prune`、`npm cache clean --force`
```
- [ ] Step 3: 写 `90-维护协议.md`
```md
---
root: true
---
# 本规范的维护协议（供 AI 读取）

本套「开发环境纪律」由 rulesync 管理，唯一源文件在：
`~/.aiglobal/.rulesync/rules/`

当用户要求新增/修改规则时：
1. 编辑 `~/.aiglobal/.rulesync/rules/` 下对应的 .md（新规则可新建文件）
2. 运行 `cd ~/.aiglobal && rulesync generate` 重新分发到所有 agent
3. 用 `rulesync generate --check` 确认无漂移
4. 不要手改生成产物 ~/.config/opencode/AGENTS.md、~/.claude/CLAUDE.md

即：用户只说需求，AI 负责改源文件 + 分发。
```

### Task 6: 生成与校验
- [ ] Step 1: `cd ~/.aiglobal && rulesync generate`
- [ ] Step 2: 确认生成 `~/.config/opencode/AGENTS.md`、`~/.claude/CLAUDE.md`
- [ ] Step 3: `rulesync generate --check`（应无漂移）
- [ ] Step 4: 保留旧 AGENTS.md 备份（`~/.shell-backup-20261010/` 已有；再存一份到 `~/.aiglobal/backup/`）

### Task 7: 分发兜底命令 `airules`
**Files:** Modify `~/.zshrc`
- [ ] Step 1: 追加别名
```bash
alias airules='cd ~/.aiglobal && rulesync generate && echo "已分发到 opencode/Claude Code"'
```
- [ ] Step 2: 验证 `zsh -i -c 'type airules'`

### Task 8: 端到端验证
- [ ] Step 1: 新开 shell：`zsh -lic 'echo ok'` 无报错
- [ ] Step 2: 检查 `~/.config/opencode/AGENTS.md` 同时含原条款 + 新纪律
- [ ] Step 3: 模拟"让 AI 加一条规则"，确认维护协议可被执行（人工确认规则文本）

### Task 9: 提交
- [ ] Step 1: `cd ~/.aiglobal && git add -A && git commit -m "feat: 落地环境纪律系统（mise 基线 + rulesync 规则包 + airules）"`

## Self-Review
- Spec 覆盖：环境基线(T1)、规则包(T3/T5)、并入现有(T4)、分发(T6)、维护协议(T5.3)、airules 兜底(T7)、验证(T8) ✓
- 无占位符 ✓
- Trae 明确排除在本次范围（已知限制）✓
