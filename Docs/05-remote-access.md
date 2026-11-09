05-remote-access.md       # 第五节：远程控制 (Remote Access)

# 05. 异地远程接入与内网穿透 (Remote-Access & Penetration)

> 💡 **核心场景**：在高校典型的多层 NAT、无公网 IPv4 且出入口严格受限的网络环境下，利用开源/免费的虚拟组网工具 **Tailscale**（基于 WireGuard 协议），实现无需向运营商申请公网 IP、免路由器公网端口映射的端到端（P2P）安全内网穿透。无论人在图书馆、教学楼或校外移动蜂窝网络，均可异地直连宿舍 Windows 11 PC 的 RDP 远程桌面及 SMB 文件存储服务。

---

💡 **提示**：本节属于进阶扩展模块。若你的日常用网环境较为简单，终端设备仅在宿舍同一 Wi-Fi 下互联，直接使用局域网 IP 直连即可，可以安全跳过本节的穿透配置。仅在需要“离开宿舍后从图书馆或外网访问宿舍 PC ”时才需参考配置。

---
## 一、方案选型与架构拓扑

### 1.1 为什么选择 Tailscale？

在受限网络环境下，常见的异地内网穿透有三种典型路径：
* **FRP / NPS**：需要自建或购买具备公网 IP 的云服务器（VPS），不仅额外产生服务器租金，且所有 RDP 高清推流和 SMB 大文件传输均受限于云服务器带宽（通常仅 5~10 Mbps）。
* **公网 IPv6 DDNS**：虽然部分高校分配了公网 IPv6，但在校外移动网络或公共 Wi-Fi 下常面临 IPv6 缺失或防火墙阻断问题，兼容性较差。
* **Tailscale (推荐)**：
  1. **智能 P2P 打洞**：基于 WireGuard 协议与 STUN/ICE 技术，客户端之间优先建立端到端直接加密隧道，跑满双方物理外网最高上下行带宽，不走第三方中继。
  2. **DERP 中继保底**：若遇到极严格对称 NAT 导致打洞失败，自动切换至官方全球中继（DERP）节点，保障链路 100% 连通。
  3. **受限硬件友好**：直接将客户端安装在主力 Windows 11 PC 上，**完全不挤占 CR6608 路由器宝贵的 256MB 内存与 128MB Flash 存储**。

### 1.2 网络通信路径

```text
[ 异地终端：MacBook / iPhone ] (图书馆 Wi-Fi / 5G 蜂窝网)
                 │
                 │ Tailscale WireGuard 加密隧道 (虚拟 IP: 100.x.y.z)
                 ▼
       ┌──────────────────────────┐
       │     NAT / STUN 打洞探测  │
       └─────────────┬────────────┘
                     │
         ┌───────────┴───────────┐
         │ (优先)                │ (保底)
         ▼                       ▼
    [ P2P 直连通道 ]       [ DERP 中继转发 ]
         │                       │
         └───────────┬───────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│ 宿舍局域网 (DNC 网关)                                    │
│   Windows 11 PC (Tailscale Node: 100.64.x.y)           │
│   ├── 原生 RDP 服务 (TCP 3389)  <-- 异地低延迟远程桌面   │
│   └── 原生 SMB 共享 (TCP 445)   <-- 异地访问宿舍大盘     │
└────────────────────────────────────────────────────────┘
```

---

## 二、Windows 11 PC 服务端接入与配置

### 2.1 安装并注册 Tailscale

1. 访问 [Tailscale 官网](https://tailscale.com/)，注册账号（支持 GitHub / Google / Microsoft 账号快捷登录）。
2. 在宿舍 Windows 11 PC 上下载并运行 Windows 客户端安装包。
3. 安装完成后，右键系统托盘中的 Tailscale 图标，点击 **Log in...**，在弹出的浏览器页面中完成设备授权登录。
4. 登录成功后，右键托盘图标可查看分配给本机的虚拟内网 IPv4 地址（形态如 `100.x.y.z`，属于 CGNAT 地址段）。在 Tailscale 控制台（Admin Console）中，你可以为这台 PC 设置易记的主机名（如 `dorm-pc`）。

### 2.2 保持后台全天候无交互常驻

为了在离开宿舍、未登录 Windows 桌面状态下也能随时连入：
1. 右键任务栏右下角 Tailscale 图标。
2. 勾选 **Run Unattended Background Process**（允许作为系统无交互后台服务运行）。
3. 这样即使 PC 处于锁屏或断开当前用户注销状态，Tailscale 守护进程依旧在底层监听隧道。

---

## 三、异地移动控制端（MacBook / iPhone）接入

### 3.1 Apple Silicon MacBook (macOS)

1. 在 Mac 上打开 **App Store**，搜索并安装 **Tailscale**。
2. 启动应用，点击顶部菜单栏的 Tailscale 图标完成登录（**必须使用与 PC 相同的登录方式/账号**）。
3. 在系统网络偏好设置中允许添加 VPN 配置，开启连接开关。
4. **验证连接**：打开 Mac 终端，执行 ping 指令测试与宿舍 PC 的连通性：
   ```bash
   ping 100.x.y.z  # 替换为 Windows PC 的 Tailscale IP
   ```
   若能正常回显 ping 延迟，说明加密专网已成功建立。

### 3.2 iPhone (iOS)

1. 在 iPhone 的 App Store 中下载安装 **Tailscale**。
2. 登录同一账号并信任“Tailscale VPN”系统网络配置文件。
3. 在异地移动网络（4G/5G）环境下将连接开关拨至“Connected”，即可无缝接入虚拟局域网。

---

## 四、异地远程桌面与 SMB 存储直连实操

当终端与宿舍 PC 均处于 Tailscale 网络中时，使用方法与在宿舍内网基本一致，只需将原先的局域网 IP（`192.168.1.100`）替换为 PC 的 **Tailscale 虚拟 IP（`100.x.y.z`）** 即可。

### 4.1 异地访问 Windows 11 远程桌面 (RDP)

1. 打开 Mac 或 iPhone 上的微软官方 **Windows App**（原 Microsoft Remote Desktop）。
2. 编辑或新建一个 PC 连接：
   * **PC name**：填入 PC 的 Tailscale IP（例如 `100.80.12.34`）或 MagicDNS 域名（例如 `dorm-pc`）。
   * **User Account**：填入 Windows 完整微软邮箱或本地用户名及对应登录密码。
3. 点击连接，在校外任意网络下即可秒级拉起宿舍 PC 的高清桌面。

### 4.2 异地安全挂载宿舍 SMB 共享盘

由于 Tailscale 通道通过 WireGuard 在网络层实现了端到端强加密，因此直接在公网上使用 SMB 协议（TCP 445）无需担心数据被运营商明文截获或被校园网防火墙丢弃：

* **MacBook (访达)**：
  按快捷键 `Cmd + K`，输入：
  ```text
  smb://100.x.y.z/DormShare
  ```
  输入 PC 用户名与密码，即可在校外像本地磁盘一样读取宿舍硬盘内的文件。
* **iPhone (文件 App)**：
  点击右上角“...” -> **连接服务器** -> 输入 `100.x.y.z`，认证通过后即可随时调取或回传照片、实验报告。

---

## 五、NAT 穿透打洞与 P2P 直连链路优化

Tailscale 默认会自动协商最优网络链路，若能直接打洞成功，延迟将仅由双方的物理地理网络距离决定。

### 5.1 检查连接状态是“Direct”还是“Relay”

在 Mac 终端中运行：
```bash
tailscale status
```
或者使用 ping 工具查看链路模式：
```bash
tailscale ping 100.x.y.z
```
* **Direct 直连（最优）**：回显显示 `pong from dorm-pc (x.x.x.x:port) via UDP in 12ms`。说明双方已成功完成 UDP 穿透打洞，数据传输不限速、无第三方转发。
* **Relay 中继（次优）**：回显显示 `via DERP(tokyo/hongkong)`。说明网络环境过于严格（如学校采用了对称型 Symmetric NAT），流量正在通过公共中继节点中转，延迟和速度可能会受到一定限制。

### 5.2 提升 P2P 打洞成功率的优化策略

1. **路由器端开启全锥型 NAT (Full Cone NAT)**：
   登录 OpenWrt 路由器后台，进入 **网络 -> 防火墙**，若固件支持硬件加速（Flow Offloading）或全锥型 NAT 补丁，将其开启，可极大改善局域网内设备与外部 STUN 服务器握手的打洞成功率。
2. **启用 UPnP 端口自动映射（可选）**：
   在 OpenWrt 上安装 `miniupnpd`（`opkg install miniupnpd luci-app-upnp`），Tailscale 会自动通过 UPnP 协议向 CR6608 申请一个固定的外部 UDP 端口映射，使外部连接能够直接命中 Windows PC，将直连率提升至 90% 以上。

---

## 六、常见问题与避坑指南 (FAQ)

* **Q1：为什么人在校外连接 Tailscale 后，所有的国内网页都变慢了？**
  * 检查是否误开启了 **Exit Node（出口节点）** 功能。默认情况下 Tailscale 仅接管特定虚拟网段（`100.64.0.0/10`）的流量，公网流量依然走终端当前的本地物理网络；只要不主动将宿舍 PC 指定为出口节点，就不会把校外流量绕回宿舍。
* **Q2：Windows PC 重启后没有开机，异地无法连上？**
  * 结合上一节介绍的 **网卡唤醒 (Wake-on-LAN)** 方案；若人已在宿舍外且 PC 关机，可选择将 Tailscale 同时部署在 OpenWrt 路由器上（或作为 Subnet Router），远程进入路由器后台下发 `etherwake` 唤醒魔术包触发开机。
* **Q3：公司/学校公共 Wi-Fi 屏蔽了 UDP 协议导致无法打洞？**
  * 部分极其严格的公共防火墙会屏蔽所有外部非标准端口的 UDP 通信，此时 Tailscale 会自动降级走 HTTPS (TCP 443) 协议的 DERP 中继节点，虽会损失少许延迟，但保障了关键网络通道绝不失联。