# AI 开发环境纪律系统

> 最后更新：2026-10-23（已移除 rulesync）
> 入口文档：先读这份。改了什么、为什么、怎么维护、还剩什么，都在这。

---

## 一、初心（为什么做这件事）

我**全流程用 AI 做开发**（Node / Python 为主），但一直是"每次 AI 会话都是无状态的、凭公开资料或自身知识自由发挥"，结果：

1. **依赖越装越多**：每建新项目就反复装，磁盘越滚越大
2. **AI 无系统性约束**：随手 `npm i -g`、全局 `pip install`，环境越来越重
3. **克隆的项目不体检就跑**：不明脚本直接执行，有安全风险
4. **技能（skill）越管越乱**：散在 40+ 个 agent 各自的目录里，大量重复、没有唯一源
5. **凭记忆维护**：换个会话就忘，问题反复

**目标**：建一套**可跨 agent 复用、且能自我维护**的"开发环境纪律"——一处写规范 → opencode / Claude Code / Trae 都自动加载 → AI 在"建项目 / 装依赖 / 克隆体检 / 清理"时都守同一套规矩。**日常由 AI 维护，我不手动改文件。**

**成功标准**：新开任意 agent 会话都读到并遵守；建/克隆项目自动按流程走；磁盘不再被构建产物持续吞噬；我不需要记东西。

---

## 二、现在这套系统长什么样

```
mise          → 管所有语言运行时版本（全局基线）
magpie        → 分发通道（把规则写进 Claude Code / OpenCode）+ 模型网关
sync.sh       → 重新分发的一句话命令（Copilot / Trae CN / 技能由它直写）
macOS 钥匙串   → 存密钥，不落明文
```

### 1. 环境基线（mise）
文件：`~/.config/mise/config.toml`
- 默认版本：`node = "24"`、`python = "3.12"`
- 安全：`minimum_release_age = "3d"`（只用发布满 3 天的版本，挡投毒）
- 运行时全局共享一份，不再每个项目重下
- 已卸载旧的多版本管理器：nvm、asdf、volta（统一到 mise）

### 2. 统一规范（自管，不再依赖 rulesync）
- **唯一源**：`~/.aiglobal/rules/`（9 条规则）+ `~/.aiglobal/skills/`（4 个技能），git 版本化
  - `00-环境纪律.md`：运行时/依赖/磁盘纪律
  - `10-项目流程.md`：新建 / 克隆体检 / 清理
  - `15-界面设计.md`：设计读法 + dial + 18 条 pre-flight
  - `20-工程规范.md`：Google eng-practices + Conventional Commits
  - `30-配置与语言规范.md`：12-Factor + Google 风格要点
  - `40-MCP调用预算.md`：按次计费工具的单任务消费上限
  - `45-终端命令安全.md`：`</dev/null`、`safe`、禁交互程序
  - `90-维护协议.md`：告诉 AI 怎么维护这套规范本身
  - `overview.md`：全局规则 / 语言 / 工具优先级 / 交付规范
- **分发产物（勿手改）**：
  - `~/.claude/CLAUDE.md`、`~/.config/opencode/AGENTS.md` — 由 magpie Library 写（marker block）
  - `~/.copilot/copilot-instructions.md` — `sync.sh` 直写（magpie 要求本机有 copilot CLI 才认）
  - `~/.trae-cn/user_rules/rule-aiglobal.md` — `sync.sh` 聚合直写（magpie 不支持 Trae CN）
  - 各 agent 的 `skills/<名>` — 软链回 `~/.aiglobal/skills/`
- 生成命令：`airules`（= `bash ~/.aiglobal/scripts/sync.sh`）

### 3. 密钥（macOS 钥匙串）
- 8 个密钥存于钥匙串，`service = "shell:<变量名>"`
- `~/.config/zsh/secrets.zsh` 启动时从钥匙串读取，**文件内零明文**
- 管理：`security add-generic-password -U -a "$USER" -s "shell:XXX" -T /usr/bin/security -w '值'`

### 4. 维护命令
```bash
airules                        # 全量重新分发（= bash ~/.aiglobal/scripts/sync.sh）
bash scripts/sync.sh --check   # 只体检，不写
bash scripts/sync.sh --no-magpie  # 跳过 magpie，只刷直写部分与技能
```

> **Trae CN**：magpie 不支持它，由 `sync.sh` 聚合后直写 `~/.trae-cn/user_rules/`，技能做软链。改完需在 Trae CN **重载窗口**才生效。
>
> **为什么技能用软链**：magpie 的技能只能从 GitHub 拉或在 App 里添加，没有本地目录入口。软链让 4 个 agent 读同一份 git 源，不会漂移。

### 5. 约定
- 新项目统一放 `~/Documents/vibecoding/Projects/`
- 运行时版本用 mise 锁定（项目内 `mise.toml`）

---

## 三、日常怎么维护（我几乎不用动手）

| 情况 | 我做什么 | 谁干活 |
|---|---|---|
| 想加/改规矩 | 直接跟任意 agent 说 | AI 改 `~/.aiglobal/rules/` 后跑 `airules` |
| AI 没照做 | 敲 `airules` | 全量重新分发（内容没变自动跳过 magpie 那步） |
| 改密钥 | 用上面的 security 命令 | 存钥匙串，立即生效 |
| magpie/mise 升级 | 交给 App/brew，或让 AI 定期做 | 无需操心 |

**规范里内置了"维护协议"**（`90-维护协议.md`），任何 agent 读到后都知道该改哪、怎么分发 → 形成自更新闭环。

---

## 四、待办 / 未完成（后续接着做）

- [ ] **收尾体检**：确认这几小时的全局改动没把系统弄坏（新终端、node/pnpm/uv/claude、密钥、规则都正常）
- [x] **magpie 分工评估**：确认 magpie 不能替代本仓库（不支持 Trae CN、无本地 skill 发布、无 git 历史）
- [x] **移除 rulesync**：规则源迁到 `rules/`、`skills/`；分发改由 magpie（Claude/OpenCode）+ `sync.sh` 直写（Copilot/Trae CN）+ 软链（技能）
- [ ] **Skill 收敛**：把散在 40+ 个 agent 目录里的 skill 收成"一个源 + 分发"（初心第 4 条，中等工程，需设计）
- [ ] **磁盘大扫除续**：iOS 模拟器 38G（最安全）、Docker 52G（看是否还用）、缓存 ~118G、微信/飞书 30G
- [ ] **试跑纪律系统**：建一个真实小项目，验证 AI 真的按规范走（证明它有用）

---

## 五、经验教训（踩过的坑，别再犯）

1. **分发工具会"孤儿清扫"**：rulesync 的 `delete: true` 会删掉输出目录里**不是它产出**的文件。
   - 事件：2026-10-10 启用 skills 分发时，它把 `~/.config/opencode/skills` 与 `~/.claude/skills` 里**别人装的 skill 全清了**（`~/.claude` 是软链，已恢复；`~/.config/opencode` 丢了 11 个网页质量类 skill，决定不恢复）。
   - **结论**：已移除 rulesync。现在的 `sync.sh` 遇到同名真实目录是**备份后让位**（`backups/skills-*`），从不直接删。
2. **让 AI 推荐工具/包时先核实**：曾经有建议里出现不存在的包（chaff）和极冷门无人验证的包（cleard），照装有风险。
3. **全局改动先备份**：本次改动完成后，旧的 shell 配置备份已清理；**下次再动全局配置前，记得先备份**。
4. **整体覆写 + marker block 混用会产生重复全文**：magpie 只在 `<!-- magpie:begin -->` 块里写，旧的整体覆写产物会残留在块外。迁移当天 `CLAUDE.md` 一度变成 879 行（434 行旧文 + 434 行新块）。现在 `sync.sh` 每次分发都会清理 marker 之外的残留。
5. **magpie 认 agent 需要对应 CLI 存在**：本机没装 `copilot` CLI，`magpie library instructions agents …copilot` 直接报错。所以 Copilot 走直写，不依赖 magpie。

---

## 六、备份与回滚

旧的 shell 配置备份已清理，不再保留。规范系统的版本历史在 `~/.aiglobal/.git`。

回滚某条规则：`git -C ~/.aiglobal revert <commit>` 后 `airules`；或直接改 `~/.aiglobal/rules/` 再分发。
分发前的 magpie 旧内容与技能旧副本都在 `~/.aiglobal/backups/`（已 gitignore）。

---

## 七、分发通道一览

| agent | 指令文件 | 谁写 | 技能 |
|---|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | magpie（marker block） | 软链 |
| OpenCode | `~/.config/opencode/AGENTS.md` | magpie（marker block） | 软链 |
| Copilot | `~/.copilot/copilot-instructions.md` | `sync.sh` 直写 | 软链 |
| Trae CN | `~/.trae-cn/user_rules/rule-aiglobal.md` | `sync.sh` 直写 | 软链 |

Copilot 与 Trae CN 不走 magpie 的原因：

- **Copilot**：magpie 要求本机装有 `copilot` CLI 才认这个目标（本机只有 VS Code 扩展），会直接报错。两者读的是同一个文件，所以直写。
- **Trae CN**：magpie 源码 `internal/library/targets.go` 里没有这个目标，也没有 `~/.trae-cn` 路径。

### 为什么技能用软链

magpie 的技能只能从 GitHub 拉取或在 App 的 Library 页添加，**没有本地目录入口**。软链让 4 个 agent 读同一份 git 版本化源，改一处即全生效，不会漂移。

### 命令

```bash
bash scripts/sync.sh              # 全量分发（airules 就是它）
bash scripts/sync.sh --check      # 只体检：内容是否一致、技能是否就位
bash scripts/sync.sh --no-magpie  # 跳过 magpie（只刷直写与技能）
```

`scripts/aggregate-rules.sh` 把 `rules/*.md` 拼成一份文本，所有通道共用，保证内容一致。

> 注意：`magpie library instructions set` 会顺带做全量 sync，实测约 **90 秒**；内容未变时脚本会跳过。

---

## 八、相关文档

- `~/.aiglobal/rules/` — 规则唯一源（9 条）
- `~/.aiglobal/skills/` — 技能唯一源（4 个）
- `~/.aiglobal/scripts/sync.sh` — 唯一分发入口（`airules`）
- `~/.aiglobal/scripts/aggregate-rules.sh` — 规则聚合器
- `~/.aiglobal/DESIGN.md` — 设计文档（历史背景）
- `~/.aiglobal/PLAN.md` — 落地实施计划（历史记录）
- `~/.aiglobal/backups/` — 分发前备份（gitignore）
