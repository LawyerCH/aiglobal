---
name: cleanup-disk
description: 扫描项目构建产物与全局缓存，列出大小供用户确认后清理，回收磁盘。当用户说"清理磁盘 / 空间不够 / 清理缓存 / 清理 node_modules"时使用。
---
# 磁盘清理

## 1. 扫描构建产物（在目标根目录，默认 `~/Projects` 或用户指定）
```bash
find <目录> -type d \( -name node_modules -o -name .venv -o -name target -o -name vendor -o -name build -o -name dist \) -prune -print0 2>/dev/null \
  | xargs -0 du -sh 2>/dev/null | sort -rh | head -30
```
把结果**列成表格**，让用户勾选删哪些——**不要擅自删除**。

## 2. 全局缓存（可选，需逐条确认）
- Node：`pnpm store prune`
- Python：`uv cache prune`
- npm：`npm cache clean --force`

## 3. 报告
删除后报告共释放了多少空间。

**原则**：先列清单 → 经用户确认 → 再删除；只删构建产物与缓存，**不删源码**。
