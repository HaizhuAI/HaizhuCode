# HaizhuCode

> 基于 [opencode-mobile-next](https://github.com/Eslamasabry/opencode-mobile-next) 魔改二创：
> 面向 **AI 逆向 / AI 编程 / CTF 解题 / 授权红蓝队对抗 / 代码审计** 的手机端智能体工作站。

HaizhuCode = OpenCode Mobile 客户端 + 内置安全作业内核 + 安全技能包 + MCP 工具接入。
部署后开箱即用：内核作为最高优先级系统提示词注入到所有受管 agent。

## 组成

| 层 | 内容 |
|---|---|
| `kernel/` | `universal-kernel-v31.md`（最高优先级系统内核）+ `global-rules-lite.md`（小模型版）+ `security-research.md` |
| `agents/` | `haizhu`（主）+ `haizhu-re`/`haizhu-ctf`/`haizhu-red`/`haizhu-blue`/`haizhu-audit`（子代理） |
| `skills/` | 逆向、APK、CTF、pwn、Web 渗透、代码审计、红队、蓝队、MCP 目录 共 9 个技能 |
| `mcp/registry.json` | MCP 服务注册表（内置 3 个开箱即用 + 4 个可安装安全平台） |
| `opencode/` | OpenCode 全局配置模板（instructions→内核、agent、mcp） |
| `prompts/builtin/` | 44 份按模型分类的内置提示词库 |
| `bin/hz` | 管理 CLI：seed/status/agents/skills/mcp/prompts/red |

## 装载方式（装机组件 `haizhu`）

`haizhu` 是 app 侧装机组件（`SetupComponent.app`，仿 voice）：装机脚本以单条
`/bin/sh -c` 参数进 proot，上限 ~128KB 装不下 payload，所以由 app 把内嵌
bundle（`lib/builtin/setup/haizhu_bundle.dart`，`tool/gen_haizhu_bundle.py`
生成）经 rootfs 直写到 `/opt/haizhu/`，再跑一行 `install -m 0755 …/hz
/usr/local/bin/hz && hz seed`。seed 产物登记在每个目标根的 `.hz-manifest`
（F/L 两类条目），`hz remove` 按单精确回收。

- **OpenCode 2 服务器**（root）：`/root/.oc-opencode2/config/opencode/` →
  `opencode.json`（instructions + mcp.servers 合并）、`AGENTS.md`、`agent/`、`skill/`
- **`oc` 用户及全部 profile**（`/home/oc`、`/home/oc/.oc-profiles/*`）：
  `claude/CLAUDE.md`+`skills`+`agents`+`.claude.json`，`codex/config.toml`+`AGENTS.md`，
  `.gemini/GEMINI.md`，`.qwen/QWEN.md`，`.config/opencode/*`，`AGENTS.md`/`CLAUDE.md`
- 之后新建的 profile 由 Android 侧 `PhoneAgentHaizhu` 在 `prepareAgentProfileHome` 自动 seed。

## 集成的项目（调研采纳）

| 项目 | 采纳形态 |
|---|---|
| [morluto/rea](https://github.com/morluto/rea) | 逆向技能方法论 + MCP/vendor 接入 |
| [storytold/craft-anything](https://github.com/storytold/craft-anything) | 净室/深度复刻引擎，MCP 接入 |
| [yynxxxxx/Codex-X](https://github.com/yynxxxxx/Codex-X) / [togg53192-cmd/jailbreaks](https://github.com/togg53192-cmd/jailbreaks) | 提示词库（已落于 `prompts/builtin/`） |
| [qiwentaidi/Hephaestus-Agent](https://github.com/qiwentaidi/Hephaestus-Agent) | 分布式扫描节点部署引导 `hz red hephaestus` |
| [HG-ha/Argusai](https://github.com/HG-ha/Argusai) | HTTP MCP 接入 + 蓝队工具路由 |
| [SeaOf0/dsh-redteam-model](https://github.com/SeaOf0/dsh-redteam-model) | 红队多模式方法论 → `haizhu-red` |
| [Kxiandaoyan/github-C2](https://github.com/Kxiandaoyan/github-C2) | 授权 C2 部署引导 `hz red c2` |
| [honmashironeko/ProxyCat](https://github.com/honmashironeko/ProxyCat) | 代理池部署引导 `hz red proxy` |
| [Ernket/CodeScan-Artex](https://github.com/Ernket/CodeScan-Artex) | 代码审计方法流 + mcphttp 接入 |

## 使用

装机完成后在任意 session 直接给任务即可；想手动管理：

```sh
hz status        # 负载与各 agent 接线状态
hz seed          # 重新 seed 所有 home
hz mcp doctor    # MCP 依赖检查
hz mcp install rea   # vendor 化安全平台
hz mcp sync      # 把 registry 中 enabled 的 MCP 同步进所有 agent 配置
```

仅在你拥有或已获书面授权的环境使用渗透/红队能力。
