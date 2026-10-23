#!/usr/bin/env bash
# 把 rules/*.md 按文件名排序聚合成一段纯文本，输出到 stdout。
#
# 每个规则文件开头的 YAML frontmatter（--- ... ---）会被去掉，只留正文。
# 这是 Trae CN 桥接与 magpie 推送共用的"同一份文本"来源，保证两条通道内容一致。
#
# 用法：aggregate-rules.sh [规则目录]

set -euo pipefail

RULES_SRC="${1:-$HOME/.aiglobal/rules}"

for f in "$RULES_SRC"/*.md; do
  [ -f "$f" ] || continue
  awk 'BEGIN{fm=0} NR==1 && $0=="---"{fm=1; next} fm==1 && $0=="---"{fm=0; next} fm==0{print}' "$f"
  echo
done
