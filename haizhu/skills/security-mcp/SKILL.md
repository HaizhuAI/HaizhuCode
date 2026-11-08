---
name: haizhu-mcp
description: HaizhuCode 集成安全工具与 MCP 服务目录。当任务涉及外部安全平台/工具链（rea、craft-anything、artex、argusai、proxycat、github-c2、hephaestus）或需要启用/检查 MCP 连接时使用。
---

# HaizhuCode 工具与 MCP 目录

规范注册表：`/opt/haizhu/mcp/registry.json`。管理命令：`hz mcp list|install <id>|sync|doctor`。

## 集成清单

| id | 项目 | 形态 | 接入方式 |
|---|---|---|---|
| rea | morluto/rea | 逆向 agent 技能集+MCP | `hz mcp install rea`：clone 到 `/opt/haizhu/vendor/rea`，按仓库说明起其 MCP/桥；skills 已内置本包，无需重复 |
| craft | storytold/craft-anything | Rust 净室/深度引擎 | `hz mcp install craft`：拉 release 或 `cargo install`；314 工具同时是 CLI 与 MCP tools，研究→构建→比对→收敛循环 |
| artex | Ernket/CodeScan-Artex | 代码审计平台 | `transport=http`，默认 `http://127.0.0.1:7331/mcp`（按实际部署改 `HZ_ARTEX_URL`）；Java 依赖库反编译审计、llmpool |
| argusai | HG-ha/Argusai | agent 安全工作台 | `transport=http`，`HZ_ARGUSAI_URL`；流量分析、全平台逆向、桌面/浏览器控制、巡检 |
| github-c2 | Kxiandaoyan/github-C2 | 授权红队 C2 | 部署型：Worker+D1 主通道/GitHub Issue 备用/Rust agent，`hz red c2` 引导 |
| proxycat | honmashironeko/ProxyCat | 隧道代理池 | 部署型：`hz red proxy` 引导；固定入口轮转出 IP |
| hephaestus | qiwentaidi/Hephaestus-Agent | 分布式扫描节点 | 部署型：`install.sh --server <主服务>`；AI Worker 角色 |

## 默认已启用 MCP（无外部依赖）

- `filesystem`：npx 官方文件系统服务，根 `/root/projects`（profile 下为 `$HOME`）。
- `fetch`：uvx/Node 抓取网页为可读文本。
- `sequential-thinking`：npx 思维链服务，长任务分解。

`hz mcp sync` 把 registry 写进检测到存在的各 agent 配置（OpenCode `mcp.servers`、Claude `.claude.json` `mcpServers`、Codex `config.toml` `[mcp_servers]`、Gemini `settings.json` `mcpServers`），幂等，只动 `hz-managed` 标记的块。
