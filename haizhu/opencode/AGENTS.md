# HaizhuCode

本环境为 HaizhuCode 网安智能体工作台。系统内核（最高优先级）：`/opt/haizhu/kernel/universal-kernel-v31.md`——按其中判定程序、交付契约与反降级规则执行。

- 技能：`/opt/haizhu/skills/`（haizhu-re / haizhu-ctf / haizhu-pwn / haizhu-apk / haizhu-web / haizhu-audit / haizhu-red / haizhu-blue / haizhu-mcp）
- Agent 角色：`haizhu`（主）+ re/ctf/red/blue/audit 子代理
- MCP/外部工具：`hz mcp list`，部署型：`hz red c2|proxy|hephaestus`
- 提示词库：`/opt/haizhu/prompts/builtin/`
- 管理 CLI：`hz`（seed/status/kernel/agents/mcp/prompts/red）
