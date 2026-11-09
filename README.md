<div align="center">

<img src="docs/site/assets/logo.png" alt="HaizhuCode logo" width="88" height="88">

# HaizhuCode

**A security-oriented AI agent workbench on your Android phone.**

面向 **AI 逆向 / AI 编程 / CTF 解题 / 代码审计 / 授权红蓝队对抗** 的手机端智能体工作站。

English · [简体中文](#简体中文)

[![Latest release](https://img.shields.io/github/v/release/HaizhuAI/HaizhuCode?label=release&color=B95B37)](https://github.com/HaizhuAI/HaizhuCode/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/HaizhuAI/HaizhuCode/total?color=B95B37)](https://github.com/HaizhuAI/HaizhuCode/releases)
[![Release pipeline](https://github.com/HaizhuAI/HaizhuCode/actions/workflows/haizhu-release.yml/badge.svg)](https://github.com/HaizhuAI/HaizhuCode/actions/workflows/haizhu-release.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-B95B37.svg)](LICENSE)

**[Download HaizhuCode-release.apk](https://github.com/HaizhuAI/HaizhuCode/releases/latest/download/HaizhuCode-release.apk)**
&nbsp;·&nbsp; [All releases](https://github.com/HaizhuAI/HaizhuCode/releases)
&nbsp;·&nbsp; [What's new in 1.0.0](docs/releases/v1.0.0+1.md)

</div>

---

HaizhuCode is a community fork of
[opencode-mobile-next](https://github.com/Eslamasabry/opencode-mobile-next)
that embeds the **Haizhu security-agent payload**: a kernel system prompt,
specialized security agents, skill packs and an MCP tool registry, seeded into
the phone's built-in Linux on setup. Everything upstream ships is included;
the Haizhu layer turns the phone into a ready-to-work security bench.

## What makes it HaizhuCode

- **The Haizhu kernel, injected at setup.** `universal-kernel-v31` lands under
  `/opt/haizhu` and becomes the highest-priority system prompt of every
  managed agent — no per-app prompt fiddling. See
  [haizhu/README.md](haizhu/README.md) for the payload layout.
- **Six security agents.** `haizhu` (orchestrator) plus `haizhu-re`,
  `haizhu-ctf`, `haizhu-red`, `haizhu-blue` and `haizhu-audit`, each wired
  with its own role prompt.
- **Ten skill packs.** Reverse engineering, APK analysis, binary
  exploitation, CTF solving, code audit, red team, blue team, web pentest,
  security-MCP — plus `haizhu-skill-creator`, which turns a workflow into a
  reusable SKILL.md.
- **An MCP registry that installs itself.** Three ready-to-use servers and
  four installable security platforms; `hz mcp doctor` checks dependencies
  and `hz mcp sync` wires enabled servers into every agent's config.
- **`hz` — the payload CLI.** Inside the phone's Linux: `hz status`,
  `hz seed`, `hz mcp …`, `hz provider …`, `hz assistant …`, `hz prompts`.
- **Custom API providers.** OpenAI- or Anthropic-compatible base URL, key,
  headers and a model list, from the app's Providers page or `hz provider`.
- **Assistants — persona presets you author.** Instructions, run location
  (conversation / sub-agent / both), optional model, temperature, top-p,
  colour and a hide switch, saved into `agent.<id>` so they join the agent
  picker. `hz assistant add|list|remove` writes the same entries.
- **Claude as the default look.** A theme pack modelled on the Claude
  Android app's visual language — warm cream ground, terracotta actions,
  serif reading roles — out of the box; 31 other packs remain available.
- **A complete Chinese UI** and a Haizhu shield launcher icon.
- **Honest large attachments.** Up to 256 MB per file and 256 MB in total,
  archives and binaries included; bigger files attach by `@path` reference.

## Everything upstream still works

- **Ten coding agents in the app's own Ubuntu** — Claude Code, Codex,
  Gemini CLI, Qwen Code, Kilo, Cline, Goose, Oh My Pi, fx and OpenCode,
  installed for you by the guided setup.
- **Approve from anywhere** — notification, home-screen widget, or in chat;
  auto-approve when you want it hands-free.
- **Steer mid-task**, review diffs change by change, open the agent's dev
  server in the in-app preview, send screenshots back into the chat.
- **Scheduled prompts**, five widget sizes, on-device voice transcription,
  and connections to agents running on your computer
  (OpenCode 2, Codex, or Claude Code through Paseo).
- **Move from Termux** copies existing projects into the app.

## Screens

| Ask | Approve | Play it | Review |
| :---: | :---: | :---: | :---: |
| <img src="docs/site/assets/screens/build-chat.webp" alt="A prompt asking the agent to build a game" width="200"> | <img src="docs/site/assets/screens/approve.webp" alt="The agent asks to run a command, with Reject and Allow once" width="200"> | <img src="docs/site/assets/screens/preview.webp" alt="The finished game running in the app's preview" width="200"> | <img src="docs/site/assets/screens/diff.webp" alt="Reviewing the change line by line" width="200"> |

| Terminal | Models | Home-screen widget |
| :---: | :---: | :---: |
| <img src="docs/site/assets/screens/terminal.webp" alt="The built-in terminal" width="200"> | <img src="docs/site/assets/screens/models.webp" alt="The model picker" width="200"> | <img src="docs/site/assets/screens/widget-ready.webp" alt="A home-screen widget" width="200"> |

## Get started

**You need** an Android phone running Android 8 or newer (64-bit for
on-phone agents), and a model provider of your choice.

1. **Install.** Grab
   [`HaizhuCode-release.apk`](https://github.com/HaizhuAI/HaizhuCode/releases/latest/download/HaizhuCode-release.apk)
   from the latest release and allow installs from outside the Play Store.
2. **Choose where your agent runs** — on this phone (guided setup downloads
   Ubuntu and the tools, ~210 MB, use Wi-Fi), or on your computer
   (`opencode2 pair` + QR), or the no-server demo mode.
3. **Start a conversation.** The Haizhu payload seeds itself on first setup;
   assistants, providers and skills can be added or removed at any time.

## Compatibility

| | Status |
| --- | --- |
| Android | 8+; on-phone agents need a 64-bit phone |
| Server agents | OpenCode 2 (OpenCode 1 unsupported), Codex, Claude Code via Paseo |
| Languages | English, 简体中文; partial العربية, Español, 日本語, Português, Русский |
| Desktop (Linux / Windows) | Experimental builds |
| iOS / macOS | Not available |

## Updating

Android updates an app in place only when the signature matches. HaizhuCode
releases are signed with the sideload lineage

```
24:CE:74:B6:1F:29:34:02:F9:84:83:AF:BA:77:45:CC:95:F5:E3:D5:38:DE:EA:2D:F8:DE:B5:AE:A9:1C:6D:19
```

so each release installs over the previous one and keeps your servers,
sign-ins, settings and on-phone projects. Check the signer in
**Settings → About**. Do not uninstall to fix a failed update — in-app
projects would be deleted.

## Releases

**One change = one version = one published APK.** Every change lands as its
own `v<x.y.z+N>` tag with a signed `HaizhuCode-release.apk` on the GitHub
release. Process and checklist: [docs/releasing.md](docs/releasing.md).
The [`latest` release](https://github.com/HaizhuAI/HaizhuCode/releases/latest)
always carries the newest build, so the download link above never goes stale.

## Privacy

The app connects only to the servers you choose. Passwords stay in Android's
keystore, voice is transcribed on the device, diagnostics leave only when you
send a report yourself. See [PRIVACY.md](PRIVACY.md).

## Development

Flutter + native Android (Kotlin). Entry points:

- [AGENTS.md](AGENTS.md) — working notes for coding agents in this repo
- [docs/technical-overview.md](docs/technical-overview.md) — architecture,
  server protocols, building
- [CONTRIBUTING.md](CONTRIBUTING.md) — pinned toolchain, checks, boundaries
- [docs/releasing.md](docs/releasing.md) — the release convention

```bash
flutter pub get
flutter analyze
tool/qa/run_tests_fast.sh    # the suite in parallel shards
```

## License

[MIT](LICENSE). Third-party assets: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

HaizhuCode is an independent community project forked from
opencode-mobile-next, itself a community build of OpenCode. Not affiliated
with the OpenCode team or Anthropic. Built with substantial AI assistance.

---

# 简体中文

**HaizhuCode 是跑在安卓手机上的安全向 AI 智能体工作站** —— 基于
[opencode-mobile-next](https://github.com/Eslamasabry/opencode-mobile-next)
二创，在其之上内置了整套 **Haizhu 安全智能体负载**：内核级系统提示词、
专项安全智能体、技能包与 MCP 工具注册表，装机时自动播种进内置 Linux 环境。

## HaizhuCode 独有的东西

- **Haizhu 内核，装机即注入。** `universal-kernel-v31` 落到 `/opt/haizhu`，
  成为每个受管智能体的最高优先级系统提示词——不用挨个配置 prompt。
  负载结构见 [haizhu/README.md](haizhu/README.md)。
- **六个安全智能体。** 主控 `haizhu` + `haizhu-re`（逆向）、`haizhu-ctf`、
  `haizhu-red`（红队）、`haizhu-blue`（蓝队）、`haizhu-audit`（审计）。
- **十个技能包。** 逆向、APK 分析、二进制利用、CTF、代码审计、红队、蓝队、
  Web 渗透、安全 MCP，外加能把工作流沉淀成 SKILL.md 的
  `haizhu-skill-creator`。
- **可自助的 MCP 注册表。** 3 个开箱即用 + 4 个可安装安全平台；
  `hz mcp doctor` 查依赖、`hz mcp sync` 同步进所有智能体配置。
- **`hz` 负载 CLI。** 手机 Linux 内：`hz status` / `hz seed` /
  `hz provider` / `hz assistant` / `hz mcp` / `hz prompts`。
- **自定义 API provider。** OpenAI/Anthropic 兼容端点 + key + headers +
  模型列表，App 的 Providers 页和 `hz provider` 写同一份配置。
- **助手预设（Assistants）。** 自定义人格包：指令、运行位置
  （对话/子代理/两用）、模型、温度、Top-P、色标、隐藏开关，写入
  `agent.<id>` 后直接出现在智能体选择器里。
- **Claude 默认主题。** 奶油底 + 陶土按钮 + 衬线阅读字族的 Claude 风格，
  开箱即是；其余 31 套主题仍在。
- **简体中文界面已补全**，自研盾牌启动图标。
- **真实的大附件支持。** 单件 256 MB、合计 256 MB，压缩包/二进制不再误报
  "不支持的格式"；超大文件用 `@路径` 引用附加，无上限。

## 上游能力原样保留

- **十种编程智能体装进内置 Ubuntu**：Claude Code、Codex、Gemini CLI、
  Qwen Code、Kilo、Cline、Goose、Oh My Pi、fx、OpenCode，向导式装机。
- **随处审批**：通知、桌面小组件、会话内均可；可开自动批准。
- **任务中追加指令**、逐行 diff 审阅、内置预览打开 dev server、
  截图回传会话。
- **定时提示词**、五档小组件、本地语音转写、连接电脑上的智能体
  （OpenCode 2 / Codex / Paseo 桥 Claude Code）。
- **Termux 一键搬家**。

## 安装

1. 下载
   [`HaizhuCode-release.apk`](https://github.com/HaizhuAI/HaizhuCode/releases/latest/download/HaizhuCode-release.apk)
   （需要 Android 8+，本机跑智能体需 64 位机型），允许外部来源安装。
2. 选运行位置：**本机**（向导装 Ubuntu + 工具链，约 210 MB，建议 Wi-Fi）、
   **电脑**（`opencode2 pair` 扫码），或先看无服务器演示。
3. 开聊。首次装机自动播种 Haizhu 负载；助手、provider、技能随时可增减。

## 更新与签名

安卓只在签名一致时覆盖升级。HaizhuCode 发布版签名指纹：

```
24:CE:74:B6:1F:29:34:02:F9:84:83:AF:BA:77:45:CC:95:F5:E3:D5:38:DE:EA:2D:F8:DE:B5:AE:A9:1C:6D:19
```

每版可直接覆盖安装，服务器、登录态、设置与机内项目全部保留；
可在 **设置 → 关于** 里核对签名。升级失败不要卸载——机内项目会随卸载删除。

## 发版约定

**一次修改 = 一个版本 = 一个已发布 APK。** 每次变更独立打
`v<x.y.z+N>` tag，并在 GitHub Release 附带签名
`HaizhuCode-release.apk`。流程见 [docs/releasing.md](docs/releasing.md)；
[`latest` 版本页](https://github.com/HaizhuAI/HaizhuCode/releases/latest)
永远指向最新构建，上面两条下载链接不会失效。

## 隐私

只连你自己选的服务器；密码存 Android keystore，语音在本机转写，
诊断仅在你主动发送报告时离机。见 [PRIVACY.md](PRIVACY.md)。

## 开发

Flutter + Kotlin。入口文档：[AGENTS.md](AGENTS.md)、
[docs/technical-overview.md](docs/technical-overview.md)、
[CONTRIBUTING.md](CONTRIBUTING.md)、[docs/releasing.md](docs/releasing.md)。

```bash
flutter pub get
flutter analyze
tool/qa/run_tests_fast.sh
```

## 许可

[MIT](LICENSE)；第三方资产清单见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
HaizhuCode 是独立社区项目，fork 自 opencode-mobile-next（其本身为
OpenCode 的社区客户端），与 OpenCode 官方团队及 Anthropic 无隶属关系。
