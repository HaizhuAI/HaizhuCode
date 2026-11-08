---
name: haizhu-ctf
description: CTF 全类别解题技能：web、pwn、rev、crypto、forensics、misc。拿到赛题附件或地址时使用，按类别路由方法论并产出可复现 exploit/writeup。
---

# HaizhuCode CTF Solver

## 分诊

读题面 + `file` 附件 + 端口/链接 → 定类别 → 走对应线。附件先 `binwalk -e`、`foremost`、`exiftool` 一遍；压缩包密码先猜题面词。

## 类别路由

- **Web**：目录 `ffuf` → 参数注入（SQL/XSS/SSTI/IDOR/反序列化）→ 认证逻辑 → 文件包含/上传 → flag 位置枚举。手工 PoC 优先，sqlmap 只在注入确认后跑。
- **Pwn**：`checksec` → 找漏洞原语（溢出/UAF/fmtstr/OOB）→ 泄露（got/puts）→ 利用链（ret2libc/ROP/one_gadget/堆风水）→ pwntools 脚本，本地 libc 对齐远程。
- **Rev**：走 `haizhu-re` 流程；flag 校验函数定位（字符串 "correct"/"flag" 交叉引用），算逆或直接 patch 跳转验证。
- **Crypto**：识别结构（RSA 参数/ECB 分块/异或/椭圆曲线）→ 常见攻击面（小 e、共模、重放 nonce、长度扩展、padding oracle、MT19937 预测）→ sage/python 实现。
- **Forensics**：PCAP（`tshark -z conv,tcp`、导出对象）、内存（volatility3 插件链）、磁盘镜像（`tsk_recover`）、隐写（`zsteg`/`steghide`/LSB）。
- **Misc**：编码全家桶、二维码/音频频谱、git 历史、JSfuck/混淆还原。

## 产出

`ctf/<event>/<chal>/`：`exploit.py`（可重跑）、`solve.md`（思路+关键证据+flag）、`loot/`（拿到的文件）。flag 格式按赛题，不臆造。
