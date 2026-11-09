# 运行环境与前置依赖 (Requirements)

在部署 DormNetworkCenter 方案前，请确保准备好以下硬件设施、PC 部署工具及底层运行环境。

---

## 1. 硬件平台与规格要求

本方案以 **小米 CR6608 路由器** 为主控参考硬件，最低硬件规格建议如下：

* **主控芯片 (SoC)**：MediaTek MT7621A（MIPS 1004Kc 双核四线程，主频 880MHz）
* **运行内存 (RAM)**：256MB DDR3（保证系统 + 代理 + SMB 运行有充足空闲）
* **存储空间 (Flash)**：128MB SPI NAND Flash（确保有足够空间容纳内核与扩展软件包）
* **网络接口**：千兆 RJ45 网口 $\times$ 4（1 WAN + 3 LAN）
* **无线规格**：双频并发 1775Mbps（2.4GHz 574Mbps + 5GHz 1201Mbps），支持 Wi-Fi 6 及 MU-MIMO
* **整机功耗**：DC 12V / 1A，待机功耗约 5~7W

---

## 2. PC 部署与调试工作站

初始化固件刷入与脚本部署需借助一台 Windows PC，建议准备以下工具：

* **操作系统**：Windows 10 / Windows 11 专业版
* **物理连接**：超五类 (Cat5e) 或六类 (Cat6) 网线 1 根（连接 PC 与路由器 LAN 口）
* **调试与开发工具链**：
  * **Windows 终端 / PowerShell**：执行 SSH 远程连接与底层 MTD 分区写入。
  * **WinSCP (v5.21+)**：基于 SFTP/SCP 协议的传输工具，用于传输 Bootloader、安装包与备份出厂射频文件。
  * **Chrome / Edge 浏览器**：利用 F12 开发者工具抓取 Portal 鉴权数据包并转换为 cURL。
  * **CR660x 解锁脚本环境**：用于通过局域网 API 漏洞免拆获取 SSH 权限。

---

## 3. 固件底座与核心系统组件

### 3.1 底层系统选型
* **安全引导程序 (Bootloader)**：Breed (xiaomi-r3g 分区版) 或专版 pb-boot（提供 Web 救砖控制台）。
* **操作系统**：OpenWrt（基于 Linux 5.10+ 内核，架构为 ramips/mt7621）。
* **根文件系统**：SquashFS（只读压缩镜像，防意外损坏）+ OverlayFS（用户配置持久化）。

### 3.2 网关核心依赖包
系统安装完成后，底层服务运行需安装并启用以下依赖组件：
* `curl` & `ca-certificates`：负责校园网 HTTPS 认证请求发送与证书校验。
* `crond`：负责执行自动化定时探活与网络自愈脚本。
* `PassWall` 及其轻量级后端核心（如 Xray / Sing-box，用于 TProxy 透明分流）。
* `ksmbd-server`：轻量级 Linux 内核 SMB 文件服务协议栈。

---

## 4. 实测验证终端与兼容性表现 (Verified Environments)

本项目方案已在以下跨生态设备组合中完成全功能运行验证（涵盖认证漫游、透明分流与 SMB 局域网挂载）：

| 设备终端 | 操作系统与架构 | 接入方式 | 验证功能与实测表现 |
| :--- | :--- | :--- | :--- |
| **桌面 PC** | Windows 11 专业版 (x86_64) | 千兆有线直连 (LAN) | 承担最初的刷机、抓包与调试工作；内网 SMB 网络驱动器正常映射读写，分流与直连策略无感切换。 |
| **笔记本电脑** | Apple Silicon MacBook (macOS, ARM64) | Wi-Fi 6 (5GHz 频段) | 握手速率跑满，免配置代理客户端直达目标网络；Finder (访达) 原生支持挂载 SMB 服务，跨端传输低延迟。 |
| **移动终端** | iPhone (iOS) | Wi-Fi 6 (5GHz 频段) | 解决移动端闲置断连问题，随时联网无需反复认证 Portal；iOS 自带“文件”App 原生无缝连接 SMB 局域网共享。 |