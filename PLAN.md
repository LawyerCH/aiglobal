# AI 开发环境纪律系统 · 实施计划

> **执行方式：** 本计划由当前会话直接执行（native）。
> **Goal:** 落地 mise 环境基线 + 统一规则包，让 opencode/Claude Code/Copilot/Trae CN 共享一套可自我维护的开发纪律。
> **Architecture（2026-10-23 更新）：** 已移除 rulesync。规则源在 `~/.aiglobal/rules/`，技能源在 `~/.aiglobal/skills/`；分发由 magpie Library（Claude/OpenCode）+ `scripts/sync.sh` 直写（Copilot/Trae CN）+ 软链（技能）完成；mise 管运行时基线。
> **Spec:** `~/.aiglobal/DESIGN.md`
> **状态：** 全部完成（2026-10-11 勾选）；2026-10-23 完成 rulesync 移除。后续变更走 `90-维护协议.md`，由 AI 改源 + `airules` 分发。

## 全局约束
- 语言：Python 3.12、Node 24（mise 管理）
- 禁止全局装依赖 / sudo 装包（规则层面）
- 生成产物不得手改，只改规则源
- 目标 agent：opencode、claudecode（规则）；trae 仅项目级（暂不在本次范围）

---

### Task 1: 环境基线（mise）
**Files:** Modify `~/.config/mise/config.toml`
- [x] Step 1: 追加 python 3.12 与安全设置
```bash
mise use -g node@24
mise use -g python@3.12
mise settings set minimum_release_age 3d
```
- [x] Step 2: 验证
```bash
mise ls --global        # 应含 node 24 / python 3.12
node -v; python3 -v     # 生效
```
- [x] Step 3: 确认既存项目仍能取到所需 node（必要时项目内 mise.toml 锁定）

### Task 2: 安装 rulesync
**Files:** mise 全局工具
- [x] Step 1: `mise use -g npm:rulesync`
- [x] Step 2: `rulesync --version`（确认可用，当前 27.0.0）

### Task 3: 初始化规则源
**Files:** Create `~/.aiglobal/rulesync.jsonc`, `~/.aiglobal/.rulesync/**`
- [x] Step 1: `cd ~/.aiglobal && rulesync init`
- [x] Step 2: 改写 `rulesync.jsonc` 为：
```jsonc
{
  "$schema": "https://github.com/dyoshikawa/rulesync/releases/latest/download/config-schema.json",
  "global": true,
  "features": ["rules", "skills"],
  "targets": ["opencode", "claudecode"]
}
```
- [x] Step 3: 验证 `rulesync config ls` 或 generate --dry-run 无报错

### Task 4: 并入现有全局规则（不丢失）
**Files:** `.rulesync/rules/*`（导入生成）
- [x] Step 1: `cd ~/.aiglobal && rulesync import --global --targets opencode`
- [x] Step 2: 检查 `.rulesync/rules/` 出现导入文件，内容含原 `~/.config/opencode/AGENTS.md` 的条款

### Task 5: 写规则源（3 个文件）
**Files:** Create `.rulesync/rules/00-环境纪律.md`, `10-项目流程.md`, `90-维护协议.md`
> 实际落地 6 个文件：00/10/20/30/90 + overview.md（后续按同目录习惯继续编号）
- [x] Step 1: 写 `00-环境纪律.md`
- [x] Step 2: 写 `10-项目流程.md` + `20-工程规范.md` + `30-配置与语言规范.md`
- [x] Step 3: 写 `90-维护协议.md`

### Task 6: 生成与校验
- [x] Step 1: `cd ~/.aiglobal && rulesync generate`
- [x] Step 2: 确认生成 `~/.config/opencode/AGENTS.md`、`~/.claude/CLAUDE.md`
- [x] Step 3: `rulesync generate --check`（应无漂移）
- [x] Step 4: 保留旧 AGENTS.md 备份（后续已作为 `docs: 备份已清理` 提交清理，githistory 可回溯）

### Task 7: 分发兜底命令 `airules`
**Files:** Modify `~/.zshrc`
- [x] Step 1: 追加别名（最终实现：指向 Trae CN 桥接脚本，见 `scripts/sync-trae-cn.sh`）
```bash
alias airules='bash ~/.aiglobal/scripts/sync-trae-cn.sh'
```
- [x] Step 2: 验证 `zsh -i -c 'type airules'`

### Task 8: 端到端验证
- [x] Step 1: 新开 shell：`zsh -lic 'echo ok'` 无报错
- [x] Step 2: 检查 `~/.config/opencode/AGENTS.md` 同时含原条款 + 新纪律
- [x] Step 3: 模拟"让 AI 加一条规则"，确认维护协议可被执行

### Task 9: 提交
- [x] Step 1: `git add -A && git commit -m "feat: 落地环境纪律系统（mise 基线 + rulesync 规则包 + airules）"`（含后续 follow-up 提交）

## Self-Review
- Spec 覆盖：环境基线(T1)、规则包(T3/T5)、并入现有(T4)、分发(T6)、维护协议(T5.3)、airules 兜底(T7)、验证(T8) ✓
- 无占位符 ✓
- Trae 明确排除在本次范围（已知限制）✓