# AI 开发环境纪律系统

> 最后更新：2026-10-10
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
rulesync      → 一处写"规范(rules)"，分发到各 agent
macOS 钥匙串   → 存密钥，不落明文
airules       → 重新分发规范的一句话命令（兜底）
```

### 1. 环境基线（mise）
文件：`~/.config/mise/config.toml`
- 默认版本：`node = "24"`、`python = "3.12"`
- 安全：`minimum_release_age = "3d"`（只用发布满 3 天的版本，挡投毒）
- 运行时全局共享一份，不再每个项目重下
- 已卸载旧的多版本管理器：nvm、asdf、volta（统一到 mise）

### 2. 统一规范（rulesync）
- **唯一源**：`~/.aiglobal/.rulesync/rules/`（6 条规则）
  - `00-环境纪律.md`：运行时/依赖/磁盘纪律
  - `10-项目流程.md`：新建 / 克隆体检 / 清理
  - `20-工程规范.md`：Google eng-practices + Conventional Commits
  - `30-配置与语言规范.md`：12-Factor + Google 风格要点
  - `90-维护协议.md`：告诉 AI 怎么维护这套规范本身
  - `overview.md`：原有全局规则（已并入）
- **分发产物（勿手改）**：
  - `~/.config/opencode/AGENTS.md`（opencode）
  - `~/.claude/CLAUDE.md`（Claude Code）
  - `~/.trae-cn/user_rules/rule-aiglobal.md`（**Trae CN** 用户级规则，由桥接脚本聚合）
- 生成命令：`airules`（内部 = `cd ~/.aiglobal && rulesync generate` + Trae CN 桥接）

### 3. 密钥（macOS 钥匙串）
- 8 个密钥存于钥匙串，`service = "shell:<变量名>"`
- `~/.config/zsh/secrets.zsh` 启动时从钥匙串读取，**文件内零明文**
- 管理：`security add-generic-password -U -a "$USER" -s "shell:XXX" -T /usr/bin/security -w '值'`

### 4. 维护命令
```bash
airules     # 重新分发规范到所有 agent（含 Trae CN 桥接）；兜底用，通常不用手动跑
```

> **Trae CN**：rulesync 不支持它的用户级规则（且只认国际版路径 `~/.trae/`）。由 `~/.aiglobal/scripts/sync-trae-cn.sh` 把规则聚合、技能软链到 `~/.trae-cn/`。改完需在 Trae CN **重载窗口**才生效。

### 5. 约定
- 新项目统一放 `~/Documents/vibecoding/Projects/`
- 运行时版本用 mise 锁定（项目内 `mise.toml`）

---

## 三、日常怎么维护（我几乎不用动手）

| 情况 | 我做什么 | 谁干活 |
|---|---|---|
| 想加/改规矩 | 直接跟任意 agent 说 | AI 改 `~/.aiglobal/.rulesync/rules/` 并 `rulesync generate` |
| AI 没照做 | 敲 `airules` | 命令重新分发 |
| 想让 magpie 也拿到规则 | `push-to-magpie.sh --write` | 推给 magpie Library（内容没变自动跳过） |
| 改密钥 | 用上面的 security 命令 | 存钥匙串，立即生效 |
| rulesync/mise 升级 | 交给 mise/brew，或让 AI 定期做 | 无需操心 |

**规范里内置了"维护协议"**（`90-维护协议.md`），任何 agent 读到后都知道该改哪、怎么分发 → 形成自更新闭环。

---

## 四、待办 / 未完成（后续接着做）

- [ ] **收尾体检**：确认这几小时的全局改动没把系统弄坏（新终端、node/pnpm/uv/claude、密钥、规则都正常）
- [x] **magpie 分工评估**：确认 magpie 不能替代本仓库（不支持 Trae CN、无本地 skill 发布、无 git 历史），已加 `push-to-magpie.sh` 作为可选通道
- [ ] **决定是否交给 magpie 分发**：若要，先改 `rulesync.jsonc` 的 targets，再跑 `push-to-magpie.sh --write --agents …`（两者不可同时写同一文件）
- [ ] **Skill 收敛**：把散在 40+ 个 agent 目录里的 skill 收成"一个源 + 分发"（初心第 4 条，中等工程，需设计）
- [ ] **Skill 归属决定**：建议 **rulesync 只管 rules**；skills 仍交回 `npx skills` / skillhub 管（避免 `delete` 冲突，见"教训"）
- [ ] **磁盘大扫除续**：iOS 模拟器 38G（最安全）、Docker 52G（看是否还用）、缓存 ~118G、微信/飞书 30G
- [ ] **试跑纪律系统**：建一个真实小项目，验证 AI 真的按规范走（证明它有用）

---

## 五、经验教训（踩过的坑，别再犯）

1. **rulesync 的 `delete` 会"孤儿清扫"**：删除输出目录里**不是 `.rulesync/` 源产出**的文件。`init` 默认就开 `delete: true`。
   - 事件：2026-10-10 我启用 skills 分发时，它把 `~/.config/opencode/skills` 与 `~/.claude/skills` 里**别人装的 skill 全清了**（`~/.claude` 是软链，已恢复；`~/.config/opencode` 丢了 11 个网页质量类 skill，决定不恢复）。
   - **现状**：`delete` 已改为 `false`。**在共享目录上永远别开 `delete`。**
2. **让 AI 推荐工具/包时先核实**：曾经有建议里出现不存在的包（chaff）和极冷门无人验证的包（cleard），照装有风险。
3. **全局改动先备份**：本次改动完成后，旧的 shell 配置备份已清理；**下次再动全局配置前，记得先备份**。
4. **两套分发工具不能写同一个文件**：rulesync 整体覆写、magpie 插 marker block。曾出现过 magpie 的 Library 里存着 7 条个人偏好、而 aiglobal 里没有其中 3 条的情况——若直接让 magpie 接管，这 3 条会被整体替换掉。**接管前必须先做内容比对**（`push-to-magpie.sh` 默认 dry-run 就是干这个）。已把这 3 条（自主决策 / 命名规范 / 结果导向）合并进 `overview.md`。

---

## 六、备份与回滚

旧的 shell 配置备份已清理，不再保留。规范系统的版本历史在 `~/.aiglobal/.git`。

回滚某条规则：编辑 `~/.aiglobal/.rulesync/rules/` 后 `airules`，或用 git 回退。

---

## 七、与 magpie 的分工

[magpie](https://github.com/yetone/magpie) 是**模型网关 + 配置写入器**，本仓库是**规则正文 + 版本历史**。两者不冲突，但有一处会互相踩。

| 能力 | `~/.aiglobal` | magpie |
|---|---|---|
| 规则正文（452 行 / 8 条） | ✅ 唯一真源 | ❌（Library 只是个空容器） |
| 写 `CLAUDE.md` / `AGENTS.md` / `copilot-instructions.md` | ✅ 整体覆写 | ✅ 插 marker block |
| **Trae CN 用户级规则** | ✅ `sync-trae-cn.sh` | ❌ 源码里无 trae |
| 本地 skills 分发 | ✅ 目录直发 | ⚠️ 只从 GitHub 拉 |
| MCP / hooks / subagents 分发 | ❌ | ✅ |
| 模型路由与额度 | ❌ | ✅ |

**唯一冲突点**：rulesync 对指令文件是**整体覆写**，magpie 是**按 `<!-- magpie:begin -->` 块插入**。同一个 agent 不能两边都写，否则互相清掉。所以：

- 默认：三个 agent 由 rulesync 管，magpie 只做模型层
- 要让 magpie 接管：先从 `rulesync.jsonc` 的 `targets` 移除对应项 → `airules` → 再 `push-to-magpie.sh --write --agents claude,opencode,copilot`
- **Trae CN 永远走桥接脚本**，magpie 没有这个能力

### 命令

```bash
bash scripts/push-to-magpie.sh                 # 体检：对比两边内容、报冲突（默认不写）
bash scripts/push-to-magpie.sh --write         # 备份旧内容后推给 magpie（内容没变则跳过）
bash scripts/push-to-magpie.sh --agents a,b    # 让指定 agent 从 magpie 取规则（有冲突守卫）
```

`scripts/aggregate-rules.sh` 是 Trae 桥接与 magpie 推送**共用的聚合器**，保证两条通道永远同一份文本。

> 注意：`magpie library instructions set` 会顺带做全量 sync，实测约 **90 秒**；脚本在内容未变时会跳过。

---

## 八、相关文档

- `~/.aiglobal/DESIGN.md` — 这套系统的设计文档
- `~/.aiglobal/PLAN.md` — 落地实施计划
- `~/.aiglobal/rulesync.jsonc` — rulesync 配置（global 模式，targets: opencode/claudecode/copilot）
- `~/.aiglobal/scripts/aggregate-rules.sh` — 规则聚合器（两条通道共用）
- `~/.aiglobal/scripts/push-to-magpie.sh` — 推送给 magpie Library（带冲突守卫）
