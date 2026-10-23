#!/usr/bin/env bash
# 把 ~/.aiglobal 的「规则 + 技能」桥接到 Trae CN。
#
# 为什么需要这个脚本：
#   rulesync 对 Trae 只支持「项目级」`<项目>/.trae/rules/`，官方明确不支持
#   Trae 的用户级 rules（且它写的是国际版路径 ~/.trae/，而 Trae CN 读 ~/.trae-cn/）。
#   因此用户级规则由本脚本聚合后写入 ~/.trae-cn/user_rules/，技能软链到 ~/.trae-cn/skills/。
#
# 唯一规则源仍是 ~/.aiglobal/.rulesync/rules/ —— 本脚本只做搬运，不要手改产物。

set -euo pipefail

SRC="$HOME/.aiglobal"
TRAE_CN="$HOME/.trae-cn"
RULES_SRC="$SRC/.rulesync/rules"
SKILLS_SRC="$SRC/.rulesync/skills"

# 1. 先生成各 agent 产物（opencode / Claude Code / trae 项目级）
(cd "$SRC" && rulesync generate)

# 2. 用户级规则：Trae CN 读单个 .md，这里做聚合
mkdir -p "$TRAE_CN/user_rules"
AGGREGATED="$TRAE_CN/user_rules/rule-aiglobal.md"
{
  echo "<!-- 由 ~/.aiglobal/scripts/sync-trae-cn.sh 自动生成，勿手改。"
  echo "     改规则请改 ~/.aiglobal/.rulesync/rules/ 后重跑 airules。 -->"
  echo
  # 按文件名排序拼接规则源（去掉 YAML frontmatter），保证与其它 agent 内容一致
  # 聚合逻辑与 magpie 推送共用 aggregate-rules.sh，两条通道永远同一份文本
  bash "$SRC/scripts/aggregate-rules.sh" "$RULES_SRC"
} > "$AGGREGATED"

# 3. 技能：软链到 Trae CN 用户技能目录（已存在的真实目录不覆盖）
mkdir -p "$TRAE_CN/skills"
linked=0
skipped=0
for d in "$SKILLS_SRC"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  dest="$TRAE_CN/skills/$name"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "跳过（Trae 已有同名技能，不覆盖）：$name"
    skipped=$((skipped + 1))
    continue
  fi
  ln -sfn "${d%/}" "$dest"
  linked=$((linked + 1))
done

echo "✓ 已同步到 Trae CN：规则 1 篇（$(wc -c < "$AGGREGATED" | tr -d ' ') 字节）+ 技能 ${linked} 个（跳过 ${skipped} 个）"
echo "  规则 → $AGGREGATED"
echo "  技能 → $TRAE_CN/skills/"
echo "  提示：Trae CN 需重载窗口才会读到新规则。"

# 4. 分发自检：核心硬规则必须真的出现在每个产物里，缺一个就报错退出
ANCHOR="涉及界面必走设计门"
missing=0
for f in "$HOME/.config/opencode/AGENTS.md" "$HOME/.claude/CLAUDE.md" "$AGGREGATED"; do
  if [ ! -f "$f" ]; then
    echo "✗ 分发自检：产物不存在 → $f" >&2
    missing=$((missing + 1))
    continue
  fi
  if ! grep -q "$ANCHOR" "$f"; then
    echo "✗ 分发自检：缺少界面设计门规则 → $f" >&2
    missing=$((missing + 1))
  fi
done
if [ "$missing" -gt 0 ]; then
  echo "✗ 分发自检失败：$missing 个产物缺少核心规则，检查 rules/overview.md 与 15-界面设计.md" >&2
  exit 1
fi
echo "✓ 分发自检通过：界面设计门规则已进入 opencode / Claude Code / Trae CN"