---
name: vet-repo
description: 克隆/运行陌生仓库前的安全体检——列出包管理器、将执行的安装脚本、体积估算、可疑命令，给出"可跑 / 建议隔离"结论。当用户要把克隆来的项目跑起来时，先使用本 skill。
---
# 陌生仓库体检（先体检，后运行）

在安装依赖或运行任何脚本**之前**，对目标目录产出体检报告：

1. **识别包管理器与语言**：查找 `package.json` / `pyproject.toml` / `requirements.txt` / `go.mod` / `Gemfile` 等
2. **列出将执行的安装脚本**：`package.json` 的 `scripts.preinstall` / `postinstall` / `prepare`，`pyproject.toml` 的构建钩子——这是主要风险点
3. **预估依赖与体积**：依赖数量、是否带 lockfile
4. **标出可疑命令**：`curl | bash`、`wget` 写系统目录、`sudo`、写 `~/Library` 或 `/etc`、网络下载可执行文件
5. **检查容器配置**：`Dockerfile` / `docker-compose.yml`（若有）
6. **给结论**：**可安全运行** / **建议隔离**（容器或子目录），并说明理由

**未经用户确认，不得执行** `pnpm i` / `uv sync` / `npm i` / 启动 dev server。
