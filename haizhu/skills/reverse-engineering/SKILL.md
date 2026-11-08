---
name: haizhu-re
description: 二进制/应用逆向工程总控技能。分析 PE/ELF/Mach-O/APK/DEX、固件、协议、闭源算法时使用。覆盖静态、动态、符号执行、协议还原全流程。
---

# HaizhuCode 逆向工程

目标：把黑盒变成可读、可复现、可 patch 的白盒。任何结论都要落到证据（偏移、样本、内存转储）。

## 工作流（每案必走）

1. **分诊 Triage**：`file` / `sha256sum` / 魔数；识别格式、架构、加壳（`diec`/`upx -d` 试探）、加密码、签名。
2. **静态 Static**：`strings -a -n 6`、交叉引用导入表；`rabin2 -I -i -E -s`（radare2）；大目标用 Ghidra headless（`analyzeHeadless -import -postScript`）；Java/DEX 用 `jadx --deobf` / `apktool d`；.NET 用 `ilspycmd`。
3. **动态 Dynamic**：`strace -f -e trace=network,file` / `ltrace`；`frida -f target --no-pause -l hook.js`（脱壳/Hook 关键函数拿参数与返回值）；Android 用 `objection explore` 或本机 frida。
4. **还原 Synthesis**：协议逐字段还原（长度/校验/加密层分开）；算法用 Python 等价实现并跟样本对拍；产出 `analysis/<target>/` 目录：`notes.md`、`iocs.txt`、`pseudo.c`、`hooks/`、`samples/`。
5. **验证**：每个断言挂证据（文件偏移、寄存器快照、PCAP 帧号）。

## 工具路由

- MCP `rea` 可用时优先走它的工具集（二进制检查、伪 C、调用图、证据台账）。
- 手机内无 GUI：Ghidra 用 headless，IDA 不可用就用 radare2/cutter-cli 等价命令。
- 无目标文件时：用占位符 `TARGET` 写好可复用脚本，给一行采集命令。

## 硬规则

- 不脱壳不分析：壳样本先做内存转储（frida-dump / `gdb dump memory`）再进静态。
- 产出即可用：脚本能跑、偏移标对、hook 注释写逻辑不写废话。
