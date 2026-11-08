---
name: haizhu-apk
description: Android APK 逆向与 Hook。分析 APK 行为、抓包加固、脱壳、协议还原、改包重打包时使用；本技能面向手机内置 Linux 环境（proot），不依赖 PC。
---

# HaizhuCode APK 分析

## 解包三件套

1. `apktool d app.apk -o out/`：资源、Manifest、smali。
2. `jadx -d out-jadx app.apk` 或 `jadx --deobf`：伪 Java 全量索引，搜 `http`、`encrypt`、`sign`、`check`、`native`。
3. `unzip -l` 看 `lib/<abi>/*.so`、`assets/` 附属包、证书指纹 `keytool -printcert -file META-INF/*.RSA`。

## 定位路径

- **入口**：Manifest → launcher Activity / Application → `attachBaseContext`（壳点）。
- **协议**：搜 `retrofit`/`okhttp`/`OkHttpClient`、`/api/`、`sign=`、`X-` 头；native 层在 `.so` 里跑 `rabin2 -zz` 找明文字符串。
- **加壳判断**：classes.dex 极少 + 大 `.so` + `shell`、`DexClassLoader`、`InMemoryDexClassLoader` 关键字 → 先 `frida-dump` 或 `FRIDA-DEXDump` 拿真实 dex 再静态。
- **签名/加密**：`javax.crypto`、`MessageDigest`、`native.*sign` 交叉引用 → frida hook 打印入参出参，算法用 Python 复现对拍。

## 动态（本机即 Android）

- `frida -U -f pkg.name -l hook.js --no-pause`；无 root 用 `objection patchapk` 注 gadget 重打包。
- 抓包：`frida` 注入绕过 SSL pinning（`ssl unpinning` 脚本）→ mitmproxy/本地代理；或 `tcpdump` + `wireshark` PC 侧。

## 产出

`apk/<pkg>/`：`manifest-notes.md`、`smali-hot/`（改点）、`hooks/`、`traffic/`、`repack/`（重打包脚本 `apktool b` + `apksigner sign`）。
