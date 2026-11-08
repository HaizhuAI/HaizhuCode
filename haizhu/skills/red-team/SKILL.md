---
name: haizhu-red
description: 授权红队行动。基础设施部署（C2、代理池、钓鱼框架可选）、后渗透、横向、痕迹管理、行动报告。仅限已授权实验室/项目环境。
---

# HaizhuCode 红队行动

## 基础设施（自带集成）

- **C2**：`github-C2` 集成——Cloudflare Worker+D1 主通道、GitHub Issue 备用通道，AES-256-GCM 信封，Rust agent。部署：`hz red c2` 输出引导（克隆 `Kxiandaoyan/github-C2` → `deploy.sh` 起 Worker → 控制台 Flask → 生成 agent 载荷）。
- **代理池**：`ProxyCat`——把静态代理 IP 转成固定隧道入口。`hz red proxy` 给出 docker-compose / 本地起池步骤，`config/config.ini` 填代理列表。
- **分布式扫描**：`Hephaestus-Agent` 节点接入主服务（`install.sh --server <主服务>`，需 PostgreSQL 与节点角色）。

## 阶段流

1. **立足点**：载荷投放（按授权范围选通道）、存活确认、环境画像（`whoami/hostname/ip/域`）。
2. **巩固**：本地信息收集（凭据存储、浏览器、计划任务）、持久化（按平台选最小痕迹方式）、代理回连确认备用通道。
3. **横向**：内网探测走代理链（`proxycat` 出口/socks）、凭据复用、票据攻击仅在授权域内。
4. **目标**：拿旗标/演示影响，证据级操作，不碰范围外数据。
5. **收尾**：清理植入与日志中的己方痕迹，提交行动报告（时间线、IOCs、检测点建议给蓝队）。

## OPSEC

通道域名用基础设施而非个人资产；载荷签名与文件名按目标环境伪装基线；操作时间窗对齐业务时段；所有命令记录进 `ops/<op>/journal.md`。
