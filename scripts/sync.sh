#!/usr/bin/env bash
# 把 ~/.aiglobal 的规则与技能分发到所有 agent。唯一的重新分发入口。
#
# 分发通道：
#   1. magpie Library → ~/.claude/CLAUDE.md、~/.config/opencode/AGENTS.md、~/.copilot/copilot-instructions.md
#   2. 脚本直写       → ~/.trae-cn/user_rules/rule-aiglobal.md（magpie 不支持 Trae CN）
#   3. 软链           → 4 个技能进入各 agent 的 skills 目录
#
# 唯一源仍是 ~/.aiglobal/rules/ 与 ~/.aiglobal/skills/ —— 本脚本只做搬运，不要手改产物。
#
# 用法：
#   bash scripts/sync.sh              # 全量重新分发
#   bash scripts/sync.sh --check      # 只体检，不写入
#   bash scripts/sync.sh --no-magpie  # 跳过 magpie（只刷 Trae CN + 技能）

set -euo pipefail

SRC="$HOME/.aiglobal"
RULES_SRC="$SRC/rules"
SKILLS_SRC="$SRC/skills"
TRAE_CN="$HOME/.trae-cn"
BACKUP_DIR="$SRC/backups"
ANCHOR="涉及界面必走设计门"

MAGPIE_BIN="${MAGPIE_BIN:-/Applications/magpie.app/Contents/MacOS/magpie}"
[ -x "$MAGPIE_BIN" ] || MAGPIE_BIN="$(command -v magpie || true)"

MODE="sync"
USE_MAGPIE=1
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --no-magpie) USE_MAGPIE=0 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✗ 未知参数：$arg" >&2; exit 2 ;;
  esac
done

die() { echo "✗ $*" >&2; exit 1; }
say() { echo "  $*"; }

[ -d "$RULES_SRC" ] || die "规则源不存在：$RULES_SRC"
[ -d "$SKILLS_SRC" ] || die "技能源不存在：$SKILLS_SRC"

TMP="$(mktemp -t aiglobal-rules)"
trap 'rm -f "$TMP"' EXIT
{
  echo "<!-- 由 ~/.aiglobal 生成，勿手改。改规则请改 ~/.aiglobal/rules/。 -->"
  echo
  bash "$SRC/scripts/aggregate-rules.sh" "$RULES_SRC"
} > "$TMP"

grep -q "$ANCHOR" "$TMP" || die "聚合文本缺少界面设计门规则（$ANCHOR），拒绝分发"

# ---------- 1. magpie：Claude Code / OpenCode ----------
# Copilot 走直写：magpie 要求本机装有 copilot CLI 才认这个目标，
# 而 VS Code 的 Copilot 扩展读的是同一个 ~/.copilot/copilot-instructions.md
MAGPIE_AGENTS="claude,opencode"
if [ "$USE_MAGPIE" = "1" ]; then
  echo "→ magpie Library"
  if [ -z "$MAGPIE_BIN" ] || [ ! -x "$MAGPIE_BIN" ]; then
    say "⚠️  找不到 magpie，跳过（Claude / OpenCode 的规则不会更新）"
  else
    CURRENT="$("$MAGPIE_BIN" library instructions </dev/null || true)"
    HAVE="$(printf '%s\n' "$CURRENT" | grep -v '^<!-- 由 ~/.aiglobal' | sed '/^[[:space:]]*$/d')"
    WANT="$(tail -n +3 "$TMP" | sed '/^[[:space:]]*$/d')"

    if [ "$MODE" = "check" ]; then
      if [ "$HAVE" = "$WANT" ]; then say "✓ 已是最新"; else say "⚠️  内容有差异，需重新分发"; fi
    elif [ "$HAVE" = "$WANT" ]; then
      say "✓ 规则未变，跳过（省掉一次约 90 秒的全量 sync）"
    else
      if [ -n "${CURRENT//[[:space:]]/}" ]; then
        mkdir -p "$BACKUP_DIR"
        B="$BACKUP_DIR/magpie-instructions-$(date +%Y%m%d-%H%M%S).md"
        printf '%s\n' "$CURRENT" > "$B"
        say "✓ 旧内容已备份：$B"
      fi
      "$MAGPIE_BIN" library instructions set "$TMP" </dev/null >/dev/null
      say "✓ 已写入 magpie Library"
    fi

    if [ "$MODE" = "sync" ]; then
      NOW_AGENTS="$(python3 - "$HOME/.config/magpie/library.json" <<'PY'
import json, sys
try:
    print(','.join(json.load(open(sys.argv[1], encoding='utf-8'))['instructions']['agents']))
except Exception:
    print('')
PY
)"
      if [ "$NOW_AGENTS" != "$MAGPIE_AGENTS" ]; then
        if ERR="$("$MAGPIE_BIN" library instructions agents "$MAGPIE_AGENTS" </dev/null 2>&1 >/dev/null)"; then
          say "✓ 指令 agents 设为 $MAGPIE_AGENTS"
        else
          say "⚠️  设置 agents 失败：$(printf '%s' "$ERR" | head -2 | tr '\n' ' ')"
        fi
      else
        say "✓ 指令 agents 已是 $MAGPIE_AGENTS"
      fi
    fi
  fi
fi

# ---------- 2. 直写：Copilot + Trae CN（magpie 不支持或无 CLI） ----------
write_direct() {
  local target="$1" dest="$2" header="$3"
  mkdir -p "$(dirname "$dest")"
  if [ "$MODE" = "check" ]; then
    if [ -f "$dest" ] && diff -q <(tail -n +3 "$dest") <(tail -n +3 "$TMP") >/dev/null 2>&1; then
      say "✓ $target 已是最新"
    else
      say "⚠️  $target 需重新分发"
    fi
    return
  fi
  {
    printf '%s\n' "$header"
    echo
    tail -n +3 "$TMP"
  } > "$dest"
  say "✓ $target 已写入（$(wc -c < "$dest" | tr -d ' ') 字节）"
}

echo "→ 直写"
write_direct "Copilot" "$HOME/.copilot/copilot-instructions.md" \
  "<!-- 由 ~/.aiglobal/scripts/sync.sh 自动生成，勿手改。改规则请改 ~/.aiglobal/rules/ 后重跑 airules。 -->"
write_direct "Trae CN" "$TRAE_CN/user_rules/rule-aiglobal.md" \
  "<!-- 由 ~/.aiglobal/scripts/sync.sh 自动生成，勿手改。改规则请改 ~/.aiglobal/rules/ 后重跑 airules；Trae CN 需重载窗口才生效。 -->"

# ---------- 3. 技能：软链进各 agent ----------
echo "→ 技能"
link_skills() {
  local target="$1" dest_dir="$2" linked=0 skipped=0 backed=0
  mkdir -p "$dest_dir"
  for d in "$SKILLS_SRC"/*/; do
    [ -d "$d" ] || continue
    local name dest
    name="$(basename "$d")"
    dest="$dest_dir/$name"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      # 同名真实目录（旧 rulesync 副本或 agent 自装）：备份后让位，不直接删除
      local bk="$BACKUP_DIR/skills-$(date +%Y%m%d-%H%M%S)/$target"
      mkdir -p "$bk"
      mv "$dest" "$bk/$name"
      backed=$((backed + 1))
    fi
    if [ "$MODE" = "check" ]; then
      if [ -L "$dest" ] && [ "$(readlink "$dest")" = "${d%/}" ]; then
        linked=$((linked + 1))
      else
        skipped=$((skipped + 1))
      fi
      continue
    fi
    ln -sfn "${d%/}" "$dest"
    linked=$((linked + 1))
  done
  if [ "$MODE" = "check" ]; then
    say "$target: $linked 个正常，$skipped 个待修复（${dest_dir}）"
  else
    extra=""
    [ "$backed" -gt 0 ] && extra="，旧副本备份 $backed 个"
    say "$target: 链接 $linked 个${extra}（${dest_dir}）"
  fi
}

CLAUDE_SKILLS="$HOME/.claude/skills"
OPENCODE_SKILLS="$HOME/.config/opencode/skills"
COPILOT_SKILLS="$HOME/.copilot/skills"

for pair in "Claude Code|$CLAUDE_SKILLS" "OpenCode|$OPENCODE_SKILLS" "Copilot|$COPILOT_SKILLS" "Trae CN|$TRAE_CN/skills"; do
  link_skills "${pair%%|*}" "${pair#*|}"
done

# ---------- 4. 清理 magpie 指令文件里的重复内容 ----------
# magpie 只在自己的 marker 块里写；之前的整体覆写产物会残留在块外，导致全文重复一份。
normalize_magpie_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  grep -q 'magpie:begin' "$f" || return 0
  python3 - "$f" "$MODE" <<'PY'
import sys
p, mode = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf-8').read()
i = s.index('<!-- magpie:begin')
prefix = s[:i]
if prefix.strip():
    if mode == 'sync':
        open(p, 'w', encoding='utf-8').write(s[i:])
        print(f"  ✓ 已清理 marker 之外的重复内容（{len(prefix)} 字符）：{p}")
    else:
        print(f"  ⚠️  marker 之外有残留内容（{len(prefix)} 字符），需重新分发：{p}")
PY
}
normalize_magpie_file "$HOME/.claude/CLAUDE.md"
normalize_magpie_file "$HOME/.config/opencode/AGENTS.md"

# ---------- 5. 分发自检 ----------
echo "→ 自检"
missing=0
check_file() {
  local f="$1" label="$2"
  if [ ! -f "$f" ]; then
    echo "✗ $label 产物不存在 → $f" >&2
    missing=$((missing + 1))
  elif ! grep -q "$ANCHOR" "$f"; then
    echo "✗ $label 缺少界面设计门规则 → $f" >&2
    missing=$((missing + 1))
  else
    say "✓ $label"
  fi
}
check_file "$HOME/.claude/CLAUDE.md" "Claude Code"
check_file "$HOME/.config/opencode/AGENTS.md" "OpenCode"
check_file "$HOME/.copilot/copilot-instructions.md" "Copilot"
check_file "$TRAE_CN/user_rules/rule-aiglobal.md" "Trae CN"

for d in "$CLAUDE_SKILLS" "$OPENCODE_SKILLS" "$COPILOT_SKILLS" "$TRAE_CN/skills"; do
  for s in "$SKILLS_SRC"/*/; do
    [ -d "$s" ] || continue
    n="$(basename "$s")"
    if [ ! -e "$d/$n" ]; then
      echo "✗ 技能缺失：$d/$n" >&2
      missing=$((missing + 1))
    fi
  done
done

[ "$missing" -eq 0 ] || die "分发自检失败：$missing 处不一致"
[ "$MODE" = "check" ] && say "全部一致" || say "✓ 全部完成"
