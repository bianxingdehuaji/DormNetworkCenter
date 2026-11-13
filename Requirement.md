# 运行环境与前置依赖 (Requirements)

在部署 **DormNetworkCenter (DNC)** 方案前，请确保准备好以下硬件设施、PC 核心宿主环境及底层软件依赖。

## 1. 硬件平台与规格要求

本方案采用**边缘网关 + 算力宿主**的职责分离架构，以 **小米 CR6608 路由器** 作为网关主控参考硬件，最低规格建议如下：

* **主控芯片 (SoC)**：MediaTek MT7621A（MIPS 1004Kc 双核四线程，主频 880MHz，无硬件浮点 FPU）
* **运行内存 (RAM)**：256MB DDR3（剥离重度存储后，保证 OpenWrt 系统 + ShellCrash 轻量分流长期稳定运行，无 OOM 风险）
* **存储空间 (Flash)**：128MB SPI NAND Flash（容纳系统固件、Meta 内核及前端面板静态资源）
* **网络接口**：千兆 RJ45 网口 × 4（1 WAN 接入校园网墙插 + 3 LAN 供核心宿主有线直连）
* **无线规格**：双频并发 1775Mbps（2.4GHz 574Mbps + 5GHz 1201Mbps），支持 Wi-Fi 6 及 MU-MIMO
* **整机功耗**：DC 12V / 1A，待机与日常运行功耗约 5~7W，适合 7×24 小时常开值守

## 2. Windows 11 核心宿主与调试工作站

Windows PC 在本方案中兼具**前期刷机调试工作站**与**后期 7×24 小时存储/算力中心**双重角色，需准备以下环境与工具：

* **操作系统**：Windows 10 / Windows 11 **专业版 (Pro)** 及以上（需原生支持完整的远程桌面 RDP 服务端与高级 SMB 共享权限管控）
* **物理连接**：超五类 (Cat5e) 或六类 (Cat6) 网线 1 根（连接 PC 与路由器千兆 LAN 口，并在路由器端配置 DHCP 静态 IP 绑定，如 `192.168.1.100`）
* **前期刷机与调试工具链**（详见 [`Docs/01-flash-system.md`](Docs/01-flash-system.md)）：
  * **Windows 终端 / PowerShell**：执行 SSH 远程连接、脚本赋权与底层 MTD 分区写入。
  * **WinSCP (v5.21+)**：基于 SCP 协议传输 Bootloader、固件包与备份原厂 `Factory` 射频分区。
  * **Chrome / Edge 浏览器**：利用 F12 开发者工具 (Network) 捕获深大 eportal 校园网鉴权 GET 请求报文。
  * **CR660x 解锁工具包**：基于 `Resource/cr660x-unlock` 通过局域网 API 漏洞免拆机开启 SSH。
* **核心宿主常驻服务**（详见 [`Docs/04-smb-share.md`](Docs/04-smb-share.md) 与 [`Docs/05-remote-access.md`](Docs/05-remote-access.md)）：
  * **Windows 原生 SMB 3.0 服务**：基于 NTFS 安全权限 + SMB 共享权限提供大容量局域网高速文件存储。
  * **Windows 原生远程桌面 (RDP, 3389)**：提供低延迟图形化桌面算力调用。
  * **Tailscale 客户端**：基于 WireGuard 构建虚拟局域网，实现校园网跨网段 P2P 直连与异地穿透。

## 3. 网关固件底座与核心系统组件

### 3.1 底层系统选型

* **安全引导程序 (Bootloader)**：专版 `pb-boot` 或 `Breed`（提供脱离系统的 Web 救砖与固件刷写控制台）。
* **操作系统**：OpenWrt（基于 Linux 5.10+ 内核，目标架构为 `ramips/mt7621`）。
* **根文件系统**：SquashFS（只读基础镜像，支持一键重置救砖）+ OverlayFS（用户配置与脚本持久化）。

### 3.2 网关核心依赖包与服务

为适配 256MB 内存与 MIPS 软浮点架构，网关层弃用臃肿的 LuCI 图形化代理与存储插件，仅依赖以下极简组件：

* **`ping` & `wget`**：系统原生内置工具，负责校园网连通性探活与 HTTP GET (JSONP) 鉴权请求发送，无需额外安装体积庞大的 `curl`（详见 [`Docs/02-auth-keeper.md`](Docs/02-auth-keeper.md)）。
* **`crond` (Scheduled Tasks)**：OpenWrt 原生计划任务守护进程，负责每 5 分钟执行一次断网自愈巡检脚本。
* **`ShellCrash` + `Meta (mipsle-softfloat)`**：纯脚本驱动的轻量级透明代理框架，配合针对 MIPS 软浮点编译的 Clash.Meta 内核，实现极低内存占用的策略分流与 QUIC 精准阻断（详见 [`Docs/03-smart-proxy.md`](Docs/03-smart-proxy.md)）。
* **`Metacubexd`**：纯静态前端控制面板，由客户端浏览器负责渲染，路由器端零算力开销。

## 4. 实测验证终端与兼容性表现 (Verified Environments)

本项目方案已在以下跨生态设备组合中完成全功能运行验证（涵盖无感认证、策略分流、SMB 存储挂载与异地远控）：

| 设备终端 | 操作系统与架构 | 接入方式 | 验证功能与实测表现 |
| :--- | :--- | :--- | :--- |
| **桌面主机 (核心宿主)** | Windows 11 专业版 (`x86_64`) | 千兆有线直连 (LAN) | 承担前期刷机调试；作为核心宿主提供原生 SMB 3.0 高速共享与 RDP (3389) 远控服务；常驻 Tailscale 节点实现校内外穿透。 |
| **笔记本电脑** | Apple Silicon MacBook (`macOS`, `ARM64`) | Wi-Fi 6 (5GHz) / 校外热点 | 局域网内免装代理客户端直享策略分流；Finder (访达) 原生挂载 SMB 共享卷；通过 Tailscale + Windows App 跨网段丝滑远控宿主 PC。 |
| **移动终端** | iPhone / iPad (`iOS` / `iPadOS`) | Wi-Fi 6 (5GHz) / 蜂窝网络 | 彻底解决移动端息屏断连与重复弹 Portal 痛点；系统自带“文件”App 挂载双书签（内网 IP / Tailscale IP）无缝读写宿主文件；Windows App 随时随地调用桌面算力。 |
