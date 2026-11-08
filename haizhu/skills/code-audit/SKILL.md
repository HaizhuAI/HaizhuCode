---
name: haizhu-audit
description: 白盒代码审计。源码/依赖库漏洞挖掘：sink 溯源、污点分析、Java 依赖反编译审计、审计报告。参考 CodeScan-Artex 方法流。
---

# HaizhuCode 代码审计

## 方法流（Artex 式）

1. **面**：技术栈、入口路由、鉴权中间件、外部输入源（HTTP 参数/文件/反序列化/RPC/消息）。
2. **点（sink）**：`exec`/`eval`/`Runtime.exec`、`ProcessBuilder`、SQL 拼接、`File(`/`read(`、反序列化（`readObject`/fastjson/Jackson polytpe/XMLDecoder）、`pickle.loads`、`yaml.load`、模板渲染、SSRF 请求发起、命令拼接、路径穿越、硬编码密钥。
3. **线**：source→sink 污点链；优先外部可控 → 高危 sink 的直达链；链断处标人工确认。
4. **依赖审计**：Java `pom.xml`/`build.gradle` 锁版本 → 反编译依赖库（jadx/fernflower）审传递 sink；Node `package-lock`、Python `requirements` → 对 CVE 库（`osv-scanner`）。
5. **证实**：每个 finding 写最小触发输入或调用栈；写不出证据的标 `unverified`。

## 产出

`audit/<repo>/`：`sinks.md`（按类分组）、`findings/NNN-*.md`（位置+污点链+触发条件+严重级+修复）、`deps.md`、`summary.md`（按可利用性排序）。

## 约定

- 只读审计：不改目标源码；验证另开沙箱。
- 大仓先按模块切片并行审，最后汇总查重。
- MCP `artex` 可用时把仓库交给它的 pipeline 跑，本技能负责复核与深挖。
