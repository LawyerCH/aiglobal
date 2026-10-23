---
name: new-project
description: 新建一个标准项目（统一放到 ~/Documents/vibecoding/Projects、锁定运行时版本、写好 AGENTS.md 与 .gitignore）。当用户说"新建项目 / 建个 xxx 项目 / 起个项目"时使用。
---
# 新建标准项目

在 `~/Documents/vibecoding/Projects/<项目名>` 下创建，遵循以下步骤：

1. `mkdir -p ~/Documents/vibecoding/Projects/<名> && cd ~/Documents/vibecoding/Projects/<名>`
2. `git init`
3. 锁定运行时版本（按语言取舍），生成 `mise.toml`：
   - Node：`mise use node@24`
   - Python：`mise use python@3.12`
4. 写 `.gitignore`：至少含 `node_modules/`、`.venv/`、`dist/`、`build/`、`.env`
5. 写最小 `AGENTS.md`：说明项目用途、技术栈、如何安装依赖、如何运行
6. 装依赖按《全局开发环境纪律》：Node 用 `pnpm`、Python 用 `uv`（项目内 `.venv`）
7. 首次提交：`git add -A && git commit -m "chore: 初始化项目"`

**禁止**：`npm i -g`、全局 `pip install`、`sudo` 装包。
