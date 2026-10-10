# AI 开发环境纪律系统 · 设计文档

> 日期：2026-10-10
> 目标读者：本人（非技术背景，全流程 AI 驱动开发）

## 一、背景与目标

**现状痛点**
- 每建新项目就反复装依赖，磁盘越滚越大（Node/Python 为主）
- AI 每次都凭公开资料/自身知识乱装东西，无系统性约束
- 克隆别人的项目不梳理就直接跑二次开发
- 结果：存储告急 + 效率低

**目标**
建立一套**可跨 agent 复用、且能自我维护**的开发纪律：一处写规范 → opencode / Claude Code / Trae 都自动加载 → AI 在"建项目 / 装依赖 / 克隆体检 / 清理"时都守同一套规矩。

**成功标准**
- 新开任意 agent 会话，都能读到并遵守这套规范
- 新建/克隆项目时，AI 自动按流程走，不再乱装依赖
- 磁盘不再被构建产物和缓存持续吞噬
- **日常维护由 AI 承担，本人无需手改文件**

## 二、系统组成（3 层）

### 第 1 层：环境基线（mise）
文件：`~/.config/mise/config.toml`
- 默认版本：`node = "24"`、`python = "3.12"`（Go 暂不设）
- 安全：`minimum_release_age = "3d"`（只用发布满 3 天的版本，挡投毒）
- 所有项目的运行时**全局共享一份**，不再重复下载

### 第 2 层：统一规则包（rulesync）
工具：`rulesync`（成熟开源，周下载 31.8 万，支持 40+ agent）
规则源目录：`~/.aiglobal/`（git 版本管理）
- `rulesync.jsonc`：`{ "global": true, "features": ["rules"], "targets": ["opencode", "claudecode"] }`
- `.rulesync/rules/00-环境纪律.md`（root）——核心约束
- `.rulesync/rules/10-项目流程.md`——新建/克隆/清理 的标准流程
- `.rulesync/rules/90-维护协议.md`——**告诉 AI 怎么维护这套规范本身**
- 现有 `~/.config/opencode/AGENTS.md` 通过 `rulesync import` **并入（不丢失）**
- 生成命令：`rulesync generate`
  → 写入 `~/.config/opencode/AGENTS.md` 和 `~/.claude/CLAUDE.md`

### 第 3 层：规则内容（约束条款）

**环境纪律**
1. 运行时版本一律用 mise，`mise use` 写进项目，禁止手动指定/另装
2. 装依赖：Node 只用 `pnpm`；Python 只用 `uv`（项目内 `.venv`）；禁止 `npm i -g` / 全局 `pip install` / `sudo` 装包
3. 装依赖前先看有无 lockfile，有则用 `--frozen-lockfile` 之类
4. 每次装完依赖，报告"装了什么 + 占多少盘"

**项目流程**
- **新建项目**：在 `~/Projects/<名>` 下建，`git init` + `mise use` 锁版本 + 最小 `AGENTS.md` + `.gitignore`
- **克隆陌生项目**：先体检再运行——列出包管理器、**将执行的安装脚本（postinstall 等）**、预估体积、依赖数量、可疑命令 → 给出"可跑/建议隔离"结论
- **清理**：定期扫描 `node_modules/.venv/target/vendor/build/dist` 及全局缓存（`pnpm store prune` / `uv cache prune`），列大小确认后删

## 三、闭环流程

```
新建项目 → AI 按「项目流程」自动 scaffold
克隆项目 → AI 先「体检」，你确认后才运行
装依赖   → 只用 pnpm/uv，隔离在项目内
长期     → AI 定期「清理」构建产物 + 全局缓存
```

## 四、维护方式（本人无需手动维护）

规范的唯一源文件 = `~/.aiglobal/.rulesync/rules/`。日常三种情况：

| 情况 | 你的操作 | 谁干活 |
|---|---|---|
| 想加/改规矩 | 直接跟任意 agent 说（如"以后 Node 都走 pnpm，写进规范"） | **AI 改源文件 + 运行 `rulesync generate` 分发** |
| AI 没照做 | 敲 `airules`（一句话重新分发） | 命令自动完成 |
| rulesync 工具升级 | 交给 mise/brew，或让 AI 定期做 | 无需操心 |

**自更新闭环**：`90-维护协议.md` 会把"源文件在哪、改完跑什么"写进规范，任何 agent 读到后都知道如何维护——形成"你说需求 → AI 改规范 → 自动分发到所有 agent"的循环。

**兜底**：`airules` 别名（写进 `.zshrc`）= 进入源目录 → 重新 `rulesync generate`。万一 AI 没做，你说一个词即可，仍不用手改文件。

## 五、已知限制（重要）

- **Trae 没有全局规则**：只在项目级生成（新项目时顺带写入）
- **rulesync 全局「命令」仅 Claude Code 支持**：因此本设计把流程写进**规则**，不依赖 `/命令`
- **规则是软约束**：AI 绝大多数情况会遵守，但非系统级强制。（要硬约束需容器隔离，见"范围外"）

## 六、范围外（暂不做）

- 容器/沙箱隔离（太重，以后真需要再加）
- Go 基线（当前无长期 Go 项目）

## 七、验证方式

1. `rulesync generate --check` 通过（生成内容与源一致）
2. 新开 opencode 与 Claude Code 会话，确认读到规则
3. 建一个测试项目，走一遍"新建 → 装依赖 → 清理"流程，确认 AI 行为符合规范
4. 对 AI 说"加一条规则：X"，确认 AI 能改源文件并重新分发

## 八、涉及文件清单

| 文件/目录 | 作用 |
|---|---|
| `~/.config/mise/config.toml` | 环境基线 |
| `~/.aiglobal/rulesync.jsonc` | rulesync 配置（全局模式） |
| `~/.aiglobal/.rulesync/rules/*.md` | 规则源（唯一要维护的地方，且交给 AI 维护） |
| `~/.config/opencode/AGENTS.md` | 生成产物（自动，勿手改） |
| `~/.claude/CLAUDE.md` | 生成产物（自动） |
| `~/.zshrc`（`airules` 别名） | 分发兜底命令 |
