01-flash-system.md    # 第一节：底层引导与系统刷入 (Flash & Recovery)

# 01. 底层引导与系统刷入 (Flash & Recovery)

本指南针对小米 CR6608 路由器（联发科 MT7621A + 128MB NAND Flash），演示如何从原厂固件免拆开启 SSH、备份出厂射频分区、刷入不死 Bootloader 并最终交付 OpenWrt 操作系统。

---

⚠️ 注意 / Note

**本节（01-底层引导与系统刷入）的操作流程与固件底包仅严格适用于 小米 CR6608 路由器（包含对应的 MTD 分区结构、换机漏洞注入方式与 Bootloader 适配）。其他不同芯片或品牌的硬件最好不要直接套用，以免导致设备变砖。**

*你可以自行查询你使用设备的部署方式。*

**不过，自 02 节起（校园网自动鉴权保活、策略路由分流、局域网 SMB 共享），所有脚本编写、Cron 定时巡检逻辑及网络服务配置均基于标准 Linux / OpenWrt 系统环境，具备通用性，可无缝移植部署至任意运行 OpenWrt 的路由器或软路由设备。**

---

## 一、前期准备与资源下载

在操作前，请确保在 Windows 电脑上下载并整理好以下工具与固件：

### 1.1 必备软件工具

| 软件名称 | 用途 | 官方 / 开源下载渠道 |
| :--- | :--- | :--- |
| **WinSCP** | 图形化 SCP 传输工具（固件上传、分区备份拉取） | [官网下载](https://winscp.net/eng/download.php) |
| **Windows 终端 (PowerShell)** | 执行 SSH 命令与底层 MTD 分区刷写（Win10/11 自带） | 系统自带（或备用 [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/)） |
| **CR660x 解锁工具包** | 本地模拟换机服务，一键向路由器注入指令开启 SSH | [GitHub 项目仓库](https://github.com/hzyitc/cr660x-unlock) |
| **小米路由器修复工具** *(备用)* | 官方刷机救砖/高版本降级工具 | [官方下载直链](http://bigota.miwifi.com/xiaoqiang/tools/create_miwifi_0.1.758.exe) |

### 1.2 固件与引导文件

1. **官方降级底包** *(备用)*：`miwifi_cr6608_all_..._1.0.103.bin` 或更早版本（若当前版本高于 1.0.103 则需降级）。
2. **不死 Bootloader（二选一，强烈建议刷入以防变砖）**：
   * **Breed（推荐）**：前往 [HackPascal Breed 官方源](https://breed.hackpascal.net/)，下载 `breed-mt7621-xiaomi-r3g.bin`（小米 R3G 与 CR6608 闪存布局相同，通用此 Breed）。
   * **pb-boot 专用底包**：前往恩山论坛 CR660x 专版下载 `pb-boot-cr660x.bin` 或 `pb-boot.img`。
3. **OpenWrt 官方固件镜像（需下载 2 个文件）**：
   * 访问 [OpenWrt 固件官方选择器](https://firmware-selector.openwrt.org/)，搜索框输入 `Xiaomi Mi Router CR6608`：
     * **过渡底包 (KERNEL)**：`openwrt-...-ramips-mt7621-xiaomi_mi-router-cr6608-initramfs-kernel.bin`
     * **正式系统包 (SYSUPGRADE)**：`openwrt-...-ramips-mt7621-xiaomi_mi-router-cr6608-squashfs-sysupgrade.bin`

---

## 二、环境连接与版本检查

1. **物理连接**：
   * 使用超五类或六类网线，一端连接电脑网口，另一端连接 CR6608 的 **LAN 口**（切勿连接蓝色 WAN 口）。
   * 暂时**禁用电脑的无线网卡（Wi-Fi）**，避免多网卡引起局域网 IP 冲突。
2. **检查当前固件版本**：
   * 打开浏览器访问 `http://192.168.31.1`，登录原厂管理后台。
   * 查看系统固件版本号：
     * 若 $\le 1.0.103$：可直接进入下一步。
     * 若 $> 1.0.103$：小米在高版本封堵了换机接口注入漏洞。需在后台系统设置中手动选择 `1.0.103` 官方固件降级并重置路由器，或者使用小米官方修复工具刷回低版本。
3. **记录凭据**：
   * 查看路由器机身背面的贴纸，拍下或记下 **SN 码** 与 **默认管理密码**。

---

## 三、免拆机开启 SSH 权限

1. **获取登录 STOK**：
   * 保持小米管理后台处于已登录状态。
   * 观察浏览器地址栏 URL，复制其中的 `stok` 字符串（例如：`http://192.168.31.1/cgi-bin/luci/;stok=abcdef123456/web/home`，其中 `abcdef123456` 即为 STOK）。
   * *注意：复制后切勿刷新后台或点击登出，否则 STOK 凭据会立即失效。*
2. **触发接口注入**：
   * 解压并启动本地的 `CR660x 解锁工具`（例如基于 Python 或可执行程序的单机免路由解锁工具）。
   * 根据终端提示，输入路由器 IP（默认 `192.168.31.1`）以及刚刚复制的 `stok`。
   * 解锁脚本将在本地模拟换机校验服务，并向换机 API 注入指令，静默拉起路由器的 `dropbear` (SSH) 守护进程。
3. **验证 SSH 连通性**：
   * 在 Windows 电脑上按 `Win + X`，选择并打开 **PowerShell** 或 **终端**。
   * 执行连接命令：
     ```powershell
     ssh root@192.168.31.1
     ```
   * 首次连接输入 `yes` 接受证书指纹。
   * **输入密码**：优先输入机身背部贴纸上的默认管理密码；若提示错误，前往 [小米路由器 SN 在线算号平台](https://www.oxygen7.cn/miwifi/) 输入机身背贴的 SN 码计算出初始 SSH 密码。
   * 终端显示欢迎字样（如 `ARE U OK` 或 `root@XiaoQiang:~#`），即代表已成功取得底层 Root 权限。

---

## 四、备份原厂关键分区（防砖核心步骤）

> ⚠️ **重要警告**：CR6608 使用 NAND Flash 存储，`Factory` 分区内存储有该路由器的出厂 MAC 地址与无线射频（EEPROM）校准参数。若未备份且分区损坏，将导致 Wi-Fi 信号极弱或无法开机且永久无法恢复原厂状态。

1. **在 SSH 终端中查看分区结构**：
   ```sh
   cat /proc/mtd
   ```
2. **全量备份底层关键分区至 `/tmp` 内存目录**：
   ```sh
   dd if=/dev/mtd0 of=/tmp/Bootloader.bin
   dd if=/dev/mtd2 of=/tmp/Bdata.bin
   dd if=/dev/mtd3 of=/tmp/Factory.bin
   ```
3. **导出镜像至电脑本地**：
   * 打开 **WinSCP**，文件协议选择 `SCP`，主机名填 `192.168.31.1`，端口 `22`，用户名 `root` 及密码登录。
   * 进入路由器的 `/tmp/` 目录。
   * 将 `Bootloader.bin`、`Bdata.bin`、`Factory.bin` 三个文件拖拽保存到电脑硬盘的独立文件夹中妥善留底。

---

## 五、刷入不死 Bootloader

以刷入 Breed 为例（若使用 pb-boot 流程相同，替换对应文件名即可）：

1. **上传引导底包**：
   * 使用 WinSCP 将下载好的 `breed-mt7621-xiaomi-r3g.bin` 上传到路由器的 `/tmp/` 目录下。
2. **执行闪存写入**：
   * 回到已连接的 SSH 终端，执行写入命令：
     ```sh
     mtd write /tmp/breed-mt7621-xiaomi-r3g.bin Bootloader
     ```
3. **等待并重启**：
   * 观察终端输出，确认出现 `Writing from /tmp/... to Bootloader ... [w]` 且没有任何 `failed/error` 提示。
   * 执行重启命令：
     ```sh
     reboot
     ```

> ⚠️ **警告**：执行 `mtd write` 期间严禁拔掉电源或断开网线，否则会直接导致 Flash 变砖。

---

## 六、通过 Bootloader 刷入 OpenWrt

1. **进入 Bootloader 恢复控制台**：
   * 拔掉路由器电源插头。
   * 用卡针或细牙签顶住路由器背部的 **Reset 键不放**，重新插上电源。
   * 保持按压 Reset 键约 5~8 秒，观察前面板指示灯出现高频交替闪烁后松开。
2. **配置电脑静态网段**：
   * 打开 Windows **设置 $\to$ 网络和 Internet $\to$ 以太网**。
   * 编辑 IPv4 设置为“手动”分配静态 IP：
     * **IP 地址**：`192.168.1.2`
     * **子网掩码**：`255.255.255.0`
     * **默认网关**：`192.168.1.1`
3. **在控制台刷入过渡固件**：
   * 打开浏览器，访问控制台地址：`http://192.168.1.1`（进入 Breed 或 pb-boot 网页恢复控制台）。
   * 点击 **固件更新** $\to$ **固件**，选择下载好的过渡内核文件：
     `openwrt-...-ramips-mt7621-xiaomi_mi-router-cr6608-initramfs-kernel.bin`
   * 点击上传并确认刷写，等待路由器写入完成并自动重启。
4. **刷入正式版 OpenWrt 固件**：
   * 将电脑网卡恢复为 **自动获取 IP (DHCP)**。
   * 电脑重新获取到局域网 IP 后，打开浏览器访问 OpenWrt 默认后台（通常为 `http://192.168.1.1`，默认无密码）。
   * 进入后台菜单：**System (系统) $\to$ Backup / Flash Firmware (备份/升级)**。
   * 在页面下方的 **Flash new firmware image (刷写新固件)** 区域，点击选择下载好的正式升级包：
     `openwrt-...-ramips-mt7621-xiaomi_mi-router-cr6608-squashfs-sysupgrade.bin`
   * 点击 **Flash image**，在校验页面**取消勾选 Keep settings (保留配置)**，点击 **Proceed** 执行正式刷入。
   * 等待 2~3 分钟，路由器指示灯稳定后，重新打开 `http://192.168.1.1` 即可看到全新的 OpenWrt 系统。

至此，基础 Linux 底座交付完成。接下来可进入后续章节部署具体的应用与自动化脚本。