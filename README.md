# DormNetworkCenter (DNC)

> 一套面向高校宿舍与多终端生态的智能边缘网关与算力中心协同方案。基于 OpenWrt 路由器（小米 CR6608）与 Windows 11 主机构建，集成校园网无感认证自愈、策略分流、原生内网文件共享、远程桌面直连与异地穿透访问。

[![OpenWrt](https://img.shields.io/badge/OpenWrt-21.02%20%7C%2022.03%2B-blue.svg)](https://openwrt.org/)
[![Hardware](https://img.shields.io/badge/Hardware-Xiaomi%20CR6608-orange.svg)](https://www.mi.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#)

---

## 💡 为什么需要 DormNetworkCenter？

在高校宿舍或小微局域网用网场景下，传统单机连接往往面临多重痛点：
1. **Web Portal 频繁掉线**：设备闲置易断连，各终端需频繁弹窗或手动输入凭据重登，甚至受到设备连接数限制。
2. **流量与业务冲突**：全局代理极易导致 AI 服务（如 Gemini/ChatGPT）被风控，同时也容易劫持校内资产、引发断流。
3. **跨端互传繁琐且受限**：Windows、macOS 与 iOS 设备间传输文件高度依赖公网通讯软件，占用外网带宽且速率受限。
4. **校外异地访问受阻**：校园网处于多层 NAT 大内网，在图书馆或教学楼难以直接调用宿舍 PC 的算力与本地数据。

**DormNetworkCenter (DNC)** 实施精细化职责分离：
* **网关层（小米 CR6608）**：负责 7×24 小时保活与自动鉴权、基于 ShellCrash 的底层轻量分流、内网私有 IP 直连豁免。
* **核心宿主层（Windows 11 PC）**：承担大容量 SMB 3.0 存储中心、RDP 高性能远程桌面计算中心及 Tailscale 穿透节点，避免挤占路由器受限硬件资源。
* **无线终端层（MacBook / iPhone）**：免装任何代理与穿透客户端，开机即用、全速互联、无缝切换。

---

## ⚡ 架构拓扑概览

```text
[ 校园网上行 / 外部网络 ]
          │ (WAN)
┌─────────▼────────────────────────────────────────────────────┐
│                  OpenWrt 边缘网关 (CR6608)                    │
│  ┌─────────────────────────┐    ┌─────────────────────────┐  │
│  │       Auth-Keeper       │    │       Smart-Proxy       │  │
│  │  (探针自愈 / GUI Cron)   │    │ (ShellCrash / 业务分流) │  │
│  └─────────────────────────┘    └─────────────────────────┘  │
│  - DHCP 静态 IP 绑定 (192.168.1.100)                          │
└─────────┬─────────────────────────────────────┬──────────────┘
          │ (千兆 LAN 直连)                      │ (Wi-Fi 6 5GHz)
          ▼                                     ▼
┌───────────────────────────┐         ┌───────────────────────────┐
│  Windows 11 PC (核心宿主)  │ ◄───────┤  无线终端 (MacBook / iOS)  │
│ - 原生 SMB 3.0 高速存储中心│ (局域网) │ - 原生 SMB 双书签自动挂载  │
│ - 原生 RDP 远程桌面 (3389) │         │ - 微软官方 Windows App 远控│
│ - Tailscale P2P 异地组网  │ ◄───────┤ - 纯享高速代理，无 APP 耗电 │
└───────────────────────────┘ (校外穿透)└───────────────────────────┘
```

---

## 📚 项目文档导览

项目采用高度解耦的模块化文档组织，所有实操指南位于 `Docs/` 目录下：

### 📄 基础规范与环境准备
* 📘 **[项目定位与方案描述 (Description.md)](./Description.md)**：核心功能解析、模块交互拓扑及相对传统单机配置的对比优势。
* ⚙️ **[运行环境与前置依赖 (Requirement.md)](./Requirement.md)**：软硬件规格（MT7621A/256MB/128MB）、PC 部署工具包、系统底座选型与实测验证设备列表。

### 🛠️ 具体实施手册 (Docs/)
* 🧱 **[01. 底层引导与系统刷入 (Docs/01-flash-system.md)](./Docs/01-flash-system.md)**  
  *一键开启 SSH 与分区备份、刷入 pb-boot 不死引导、标准双重刷入（底包 + Upgrade）交付 OpenWrt。*
* 🔑 **[02. 校园网自动鉴权与故障自愈 (Docs/02-auth-keeper.md)](./Docs/02-auth-keeper.md)**  
  *深大 eportal (GET/JSONP) 鉴权报文逆向、基于 wget 的极简健康探活、GUI 后台 Cron 定时守护。*
* 🌐 **[03. 策略路由与透明代理自动化 (Docs/03-smart-proxy.md)](./Docs/03-smart-proxy.md)**  
  *MIPS 软浮点内核适配、ShellCrash 极简部署、Metacubexd 独立面板、协议与业务分流（如 AI 服务绑死纯净 VLESS 节点）。*
* 📂 **[04. 局域网文件共享与协同 (Docs/04-smb-share.md)](./Docs/04-smb-share.md)**  
  *以 Windows 11 PC 为核心宿主构建原生 SMB 存储、双层权限（安全/网络）精细化管控及 Mac/iOS 原生挂载。*
* 🖥️ **[05. 异地远程接入与内网穿透 (Docs/05-remote-access.md)](./Docs/05-remote-access.md)**  
  *基于 Tailscale 搭建端到端点对点隧道、近场智能直连与外网穿透无缝切换、异地远程桌面 (RDP)。*
* 🩺 **[06. 日常排障与避坑指南 (Docs/06-troubleshooting.md)](./Docs/06-troubleshooting.md)**  
  *涵盖 Bootloader 救砖、IP 漂移、QUIC 嵌套丢包排查、NLA 凭据陷阱及实用运维命令速查。*
* ⚡ **[未完待续 (Docs/To Be Continue.md)](./Docs/To%20Be%20Continue.md)**  
  *未来扩展路线图（Home Assistant 边缘接入、电费监控、Docker 算力矩阵）与极客折腾记录。*

---

## 💖 开源项目致谢 (Acknowledgments)

本项目的诞生与落地高度依赖于开源社区前辈们的无私奉献，特此向以下优秀的开源项目与开发者致以最深的敬意：

* **[OpenWrt](https://openwrt.org/)**: 为受限硬件提供强大、灵活且无限可能的底层 Linux 路由系统。
* **[hzyitc/cr660x-unlock](https://github.com/hzyitc/cr660x-unlock)**: 优雅的免拆机漏洞注入工具，让解锁 SSH 变得无比简单。
* **[pb-boot / Breed]**: 极其稳定的底层不死 Bootloader，保障了无数次刷机探索中的设备安全。
* **[juewuy/ShellCrash](https://github.com/juewuy/ShellCrash)**: 极简至美的脚本架构，在 256MB 的 MIPS 芯片上展现了令人惊叹的极低资源占用与强大的 Meta 驱动能力。
* **[Metacubex](https://github.com/metacubex)**: 提供了性能优异的内核协议支持以及 `metacubexd` 纯前端无感渲染的高颜值控制面板。
* **[Tailscale](https://tailscale.com/)**: 基于 WireGuard 封装，为局域网与广域网提供了极其智能且零配置的 P2P 穿透组网体验。
* **[ACL4SSR](https://github.com/ACL4SSR/ACL4SSR)**: 详尽且高频更新的云端规则模板，为智能分流策略提供了坚实的基础。

---

## ⚠️ 须知与合规声明

1. **硬件适配说明**：`Docs/01-flash-system.md` 中涉及的分区定义与注入工具**仅严格适用于小米 CR6608 路由器**；
不过自 `02` 节起的网络脚本、代理策略与协同服务基于标准 Linux / Windows 原生协议，具备高度通用性。
2. **合规提示**：本项目所涉及的网络分流与配置方法仅供技术学习与工程实践。使用时请严格遵守国家相关互联网法律法规以及所在高校的校园网准入规定。

---

## 📬 交流与反馈 (Contact & Feedback)

本项目为个人网络工程实践与宿舍网络改造记录，欢迎交流技术：

* 🐛 **问题反馈**：如遇深大校园网接口变动、脚本异常或配置疑问，建议优先提交 [GitHub Issues](../../issues)，方便讨论方案。
* ✉️ **联系邮箱**：[`120763101+bianxingdehuaji@users.noreply.github.com`](mailto:120763101+bianxingdehuaji@users.noreply.github.com) *(GitHub 隐私中转邮箱)*
* ⭐️ 如果本套方案对你的宿舍用网体验有所改善，欢迎点个 **Star** ！

---

## 🤖  AI 协同声明 (AI Statement)

本项目开发及文档撰写过程使用了 AI 辅助协同。