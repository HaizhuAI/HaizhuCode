---
name: haizhu-blue
description: 蓝队防守分析。日志/流量/内存取证、IOC 提取与狩猎、检测规则（Sigma/YARA/Suricata）编写、事件时间线与报告。
---

# HaizhuCode 蓝队

## 取证流

- **流量**：PCAP → `tshark -z io,phs` 协议分布 → 异常长连/域名/DNS 隧道 → `zeek` 切日志按 conn/dns/http 追。
- **日志**：先定时间窗与资产清单；认证失败聚类、进程树异常、新服务/账户/持久化点；Windows 事件按 ID 模板（4624/4625/4688/7045/1102）。
- **内存**：`vol3 -f mem.dmp windows.pslist` → `malfind`/`hollowprocesses` → 可疑段 dump 做静态。
- **主机**：自启位、计划任务、服务、最近写入、`bash_history`、authorized_keys。

## IOC→检测

1. 从样本/日志抽 IOC（IP/域/hash/路径/UA/互斥体/注册表）。
2. 落地检测：YARA（样本特征串+条件）、Sigma（日志源+字段条件）、Suricata 规则（协议字段+content）。
3. 规则自带测试：YARA 对正负样本各跑一遍；Sigma 给对应日志字段映射。

## 产出

`ir/<case>/`：`timeline.md`（UTC 时间线）、`iocs.json`、`rules/`（yara/sigma/suricata）、`report.md`（入口向量→行为→影响→处置建议）。

## 对接

`argusai` 工作台可用时走它的流量分析与巡检工具；本技能负责规则与结论复核。
