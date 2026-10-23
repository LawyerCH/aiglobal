#!/usr/bin/env bash
# 把 ~/.aiglobal 的规则正文推送给 magpie 的 Library（instructions），
# 由 magpie 负责写进 Claude Code / OpenCode / Copilot CLI 的指令文件。
#
# 为什么不直接删掉 rulesync：
#   - magpie 完全不支持 Trae CN（targets.go 里没有 trae），Trae 仍走 sync-trae-cn.sh
#   - aiglobal 是规则正文的 git 版本化真源，magpie 的 Library 只是分发通道
#   - magpie 支持本地目录发布 skill 的能力有限，aiglobal 的 4 个技能仍由 rulesync 分发
#
# 冲突警告（本脚本会拦截）：
#   rulesync 对指令文件是「整体覆写」，magpie 是「按 marker block 插入」。
#   同一个 agent 不能同时由两者写入 —— 启用 magpie 分发前，必须先把该 agent 从
#   rulesync.jsonc 的 targets 里移除，否则两边互相踩。
#
# 用法：
#   bash scripts/push-to-magpie.sh                # 只体检，不写入（默认）
#   bash scripts/push-to-magpie.sh --write        # 备份旧内容后写入 magpie
#   bash scripts/push-to-magpie.sh --agents claude,opencode,copilot
#                                                # 让这些 agent 从 magpie 拿规则（带守卫）
#   bash scripts/push-to-magpie.sh --help

set -euo pipefail

SRC="$HOME/.aiglobal"
RULES_SRC="$SRC/.rulesync/rules"
BACKUP_DIR="$SRC/backups"
ANCHOR="涉及界面必走设计门"   # 与 sync-trae-cn.sh 相同的分发自检锚点

MAGPIE_BIN="${MAGPIE_BIN:-/Applications/magpie.app/Contents/MacOS/magpie}"
if [ ! -x "$MAGPIE_BIN" ]; then
  MAGPIE_BIN="$(command -v magpie || true)"
fi

die() { echo "✗ $*" >&2; exit 1; }
info() { echo "  $*"; }

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

# ---------- 参数 ----------
MODE="status"
AGENTS_TO_SET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --write)  MODE="write" ;;
    --agents) AGENTS_TO_SET="${2:-}"; [ -n "$AGENTS_TO_SET" ] || die "--agents 需要一个逗号分隔的列表" ; shift ;;
    --agents=*) AGENTS_TO_SET="${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1（用 --help 查看用法）" ;;
  esac
  shift
done

[ -n "$MAGPIE_BIN" ] && [ -x "$MAGPIE_BIN" ] || die "找不到 magpie 可执行文件（可用 MAGPIE_BIN=... 指定）"
[ -d "$RULES_SRC" ] || die "规则源不存在：$RULES_SRC"

# ---------- rulesync 当前 targets ----------
rulesync_targets() {
  python3 - "$SRC/rulesync.jsonc" <<'PY'
import json, re, sys
s = open(sys.argv[1], encoding='utf-8').read().replace('://', '\x00')
s = re.sub(r'//[^\n]*', '', s).replace('\x00', '://')
print(','.join(json.loads(s).get('targets', [])))
PY
}

TARGETS="$(rulesync_targets)"
CONFLICTS=""
case ",$TARGETS," in
  *,claudecode,*) CONFLICTS="$CONFLICTS claude" ;;
esac
case ",$TARGETS," in
  *,opencode,*) CONFLICTS="$CONFLICTS opencode" ;;
esac
case ",$TARGETS," in
  *,copilot,*) CONFLICTS="$CONFLICTS copilot" ;;
esac
CONFLICTS="${CONFLICTS# }"

# ---------- 聚合文本 ----------
TMP="$(mktemp -t aiglobal-magpie)"
trap 'rm -f "$TMP"' EXIT
{
  echo "<!-- 由 ~/.aiglobal 生成，勿手改。改规则请改 ~/.aiglobal/.rulesync/rules/。 -->"
  echo
  bash "$SRC/scripts/aggregate-rules.sh" "$RULES_SRC"
} > "$TMP"

NEW_LINES="$(wc -l < "$TMP" | tr -d ' ')"
NEW_BYTES="$(wc -c < "$TMP" | tr -d ' ')"

# ---------- 体检 ----------
echo "rulesync targets : ${TARGETS:-（空）}"
echo "magpie 当前指令  : $(printf '%s' "$("$MAGPIE_BIN" library instructions </dev/null)" | wc -l | tr -d ' ') 行"
echo "aiglobal 聚合后  : ${NEW_LINES} 行 / ${NEW_BYTES} 字节"
MAGPIE_AGENTS="$(python3 - "$HOME/.config/magpie/library.json" <<'PY'
import json, sys
try:
    print(','.join(json.load(open(sys.argv[1], encoding='utf-8'))['instructions']['agents']) or '（空）')
except Exception:
    print('（未知）')
PY
)"
echo "magpie 指令 agents: $MAGPIE_AGENTS"
echo

if grep -q "$ANCHOR" "$TMP"; then
  info "✓ 聚合文本含界面设计门锚点"
else
  echo "✗ 聚合文本缺少界面设计门规则（$ANCHOR），拒绝继续" >&2
  exit 1
fi

if [ -n "$CONFLICTS" ]; then
  echo "⚠️  rulesync 仍在写这些 agent：$CONFLICTS"
  echo "    同一个指令文件不能两边都写（rulesync 整体覆写 / magpie 插 marker block）。"
  echo "    要让 magpie 接管，先从 rulesync.jsonc 的 targets 移除对应项并重跑 airules。"
else
  info "✓ rulesync targets 不含 claude/opencode/copilot，可以交由 magpie 接管"
fi
echo

# ---------- 写入 ----------
if [ "$MODE" = "write" ]; then
  CURRENT="$("$MAGPIE_BIN" library instructions </dev/null || true)"
  WANT="$(tail -n +3 "$TMP")"   # 跳过生成头注释，只比正文
  HAVE="$(printf '%s\n' "$CURRENT" | grep -v '^<!-- 由 ~/.aiglobal' | sed '/^[[:space:]]*$/d')"
  WANT_C="$(printf '%s\n' "$WANT" | sed '/^[[:space:]]*$/d')"

  if [ "$HAVE" = "$WANT_C" ]; then
    info "✓ magpie 已是同一份规则，跳过写入（省掉一次 ~90s 的全量 sync）"
  else
    if [ -n "${CURRENT//[[:space:]]/}" ]; then
      mkdir -p "$BACKUP_DIR"
      B="$BACKUP_DIR/magpie-instructions-$(date +%Y%m%d-%H%M%S).md"
      printf '%s\n' "$CURRENT" > "$B"
      info "✓ 旧内容已备份：$B"
      echo "  ⚠️  magpie 现有指令会被整体替换（不是追加）。若里面有 aiglobal 未覆盖的个人偏好，"
      echo "      先从备份里手工合并进 .rulesync/rules/ 再跑一次。"
    fi
    "$MAGPIE_BIN" library instructions set "$TMP" </dev/null
    echo

    if "$MAGPIE_BIN" library instructions </dev/null | grep -q "$ANCHOR"; then
      info "✓ 推送后自检通过：magpie 已含界面设计门规则"
    else
      die "推送后自检失败：magpie 指令里找不到界面设计门规则"
    fi
  fi
else
  info "（dry-run）加 --write 才会真正写入 magpie"
fi

# ---------- 设置 agents ----------
if [ -n "$AGENTS_TO_SET" ]; then
  echo
  IFS=',' read -r -a REQ <<< "$AGENTS_TO_SET"
  for a in "${REQ[@]}"; do
    a="${a// /}"
    case " $CONFLICTS " in
      *" $a "*)
        die "拒绝把 $a 交给 magpie：rulesync 仍在写它，会互相覆盖。先改 rulesync.jsonc。"
        ;;
    esac
    # magpie 的 agent 名：claude 是 Claude Code；Trae CN 不支持
    if [ "$a" = "trae-cn" ] || [ "$a" = "trae" ]; then
      die "magpie 不支持 Trae CN，规则继续由 sync-trae-cn.sh 负责"
    fi
  done
  "$MAGPIE_BIN" library instructions agents "$AGENTS_TO_SET" </dev/null
  info "✓ 已设置 magpie 指令 agents：$AGENTS_TO_SET"
  info "  执行 magpie library sync 可立即写入各 agent 文件（或在 app 里点 Library → Sync）"
fi
