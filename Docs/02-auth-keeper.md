02-auth-keeper.md     # 第二节：校园网抓包与断网自愈 (Auth-Keeper)

# 02. 校园网自动鉴权与故障自愈 (Auth-Keeper)

> 💡 **通用性说明**：本节所涉及的 Shell 脚本编写、网络健康状态探测及 Cron 守护机制基于通用 Linux / OpenWrt 系统环境实现，适用于绝大多数部署了 OpenWrt 系统的路由器。

本节以**深圳大学（SZU）校园网 Web Portal（eportal 鉴权系统）**为例，详细解析协议逆向、动态内网 IP 获取、自动鉴权 Shell 脚本编写以及基于 Cron 的全天候网络故障自愈机制。

---

⚠️ 认证系统适配提示 / Note

***本节提供的脚本与自动化鉴权方案针对深圳大学（SZU）所采用的锐捷 Web Portal（eportal/JSONP）认证系统实测编写。***

***适用范围：本方案适用于同样采用 GET / JSONP 形式传参、明文/简易参数校验、需动态绑定客户端内网 IP（wlan_user_ip） 的同类型校园网或企业 Portal 认证系统。***

***其他系统差异：若所在高校采用非 Web 认证（如锐捷专用客户端 802.1x 拨号、Dr.COM 专有客户端协议），或 Portal 登录密码引入了动态盐值（Salt）哈希加密（如 RSA/AES 前端加密），则不能直接套用此接口参数，需结合浏览器 F12 抓包逆向调整鉴权逻辑。***

---

## 一、协议逆向与鉴权机制分析

通过对校园网认证过程抓包分析，该系统的鉴权机制具有以下典型特征：

* **认证服务端接口**：`http://172.30.255.42:801/eportal/portal/login`
* **交互请求方式**：`GET`（前端采用 JSONP 形式发起异步鉴权跨域请求）
* **密码传输策略**：明文参数传输，无需前端 MD5/SHA256 复杂哈希逆向计算。
* **关键动态参数**：`wlan_user_ip`（必须与当前路由器 WAN 口实际获得的校园内网 IP 完全一致，否则服务端会拒绝认证或返回 IP 不匹配错误）。

### 常见完整请求参数范例

```text
http://172.30.255.42:801/eportal/portal/login?callback=dr1003&login_method=1&user_account=你的学号&user_password=你的密码&wlan_user_ip=路由器WAN口IP&wlan_user_ipv6=&wlan_vlan_id=0&wlan_encac_id=0&wlan_direct_ip=0&wlan_user_mac=000000000000
```

---

## 二、部署动态鉴权脚本

在 OpenWrt 路由器上部署自动化脚本，核心逻辑包括两部分：
1. **健康探针**：向可靠的公共 204 服务（如小米或高通的无内容探测接口）发起微秒级 HTTP 请求，判断外网是否畅通。
2. **故障自愈**：当网络掉线或未登录时，动态提取当前路由器 WAN 口的 IPv4 地址，拼接参数向 eportal 接口发起登录。

### 2.1 创建并编辑脚本

1. 通过 SSH 登录 OpenWrt 路由器终端：
   ```sh
   ssh root@192.168.1.1
   ```
2. 创建脚本存放目录并新建脚本文件：
   ```sh
   mkdir -p /root/scripts
   vi /root/scripts/szu_auth.sh
   ```

3. 写入以下完整脚本代码（请将变量中的 `YOUR_STUDENT_ID` 和 `YOUR_PASSWORD` 替换为你的真实校园网凭据）：

```sh
#!/bin/sh
# ==============================================================================
# SZU Campus Network Auto-Auth & Keepalive Script
# 深圳大学校园网自动登录与状态探活自愈脚本
# ==============================================================================

# ----------------- 用户配置区域 (按需修改) -----------------
USER_ACCOUNT="YOUR_STUDENT_ID"    # 校园网登录学号/账号
USER_PASSWORD="YOUR_PASSWORD"    # 校园网登录密码
LOG_FILE="/root/scripts/szu_auth.log" # 运行日志路径
MAX_LOG_LINES=500                 # 日志最大保留行数，防止占满 Flash

# ----------------- 接口与探针参数 -----------------
AUTH_SERVER="http://172.30.255.42:801/eportal/portal/login"
# 外网连通性探测接口（连通时正常返回 HTTP 204）
PROBE_URL="http://connect.rom.miui.com/generate_204"

# ----------------- 基础函数定义 -----------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 日志轮转，避免 Flash 存储溢出
clean_log() {
    if [ -f "$LOG_FILE" ]; then
        LINES=$(wc -l < "$LOG_FILE")
        if [ "$LINES" -gt "$MAX_LOG_LINES" ]; then
            tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
            log "日志已轮转，保留最近 200 条记录。"
        fi
    fi
}

# 动态获取路由器当前校园网分配的 WAN 口 IP
get_wan_ip() {
    # 优先通过 OpenWrt 官方 ubus 工具查询 wan 接口对应的 IPv4
    WAN_IP=$(ubus call network.interface.wan status 2>/dev/null | grep '"address"' | head -n 1 | awk -F '"' '{print $4}')
    
    # 若通过 ubus 未取到，回退使用 ifconfig 直接提取
    if [ -z "$WAN_IP" ]; then
        WAN_IP=$(ifconfig eth0.2 2>/dev/null | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
    fi

    # 如果还为空，尝试从所有以太网卡提取 10/172 私网地址
    if [ -z "$WAN_IP" ]; then
        WAN_IP=$(ip -4 addr show | grep -oE '(172\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' | head -n 1)
    fi

    echo "$WAN_IP"
}

# ----------------- 核心执行逻辑 -----------------
clean_log

# 1. 探测外网是否连通 (超时设为 3 秒)
HTTP_CODE=$(curl -I -s --connect-timeout 3 -m 5 -w "%{http_code}" -o /dev/null "$PROBE_URL")

if [ "$HTTP_CODE" -eq 204 ] || [ "$HTTP_CODE" -eq 200 ]; then
    # 网络正常，静默退出
    exit 0
fi

log "检测到外网异常断开 (探针返回码: $HTTP_CODE)，准备触发自动登录认证..."

# 2. 获取当前 WAN 口 IP
CURRENT_IP=$(get_wan_ip)

if [ -z "$CURRENT_IP" ]; then
    log "错误：无法获取当前 WAN 口内网 IP，网线可能未插好或未获取到 DHCP 地址。"
    exit 1
fi

log "获取到当前内网 IP: $CURRENT_IP，正在组装参数发起 GET 鉴权..."

# 3. 发送 GET 认证请求 (JSONP 接口)
RESP=$(curl -s --connect-timeout 5 -m 8 -X GET "${AUTH_SERVER}?callback=dr1003&login_method=1&user_account=${USER_ACCOUNT}&user_password=${USER_PASSWORD}&wlan_user_ip=${CURRENT_IP}&wlan_user_ipv6=&wlan_vlan_id=0&wlan_encac_id=0&wlan_direct_ip=0&wlan_user_mac=000000000000")

# 4. 解析结果（通过响应文本中的 result 判断）
if echo "$RESP" | grep -q '"result":1'; then
    log "认证成功！网络已恢复畅通。"
elif echo "$RESP" | grep -q '"result":0'; then
    ERR_MSG=$(echo "$RESP" | grep -oE '"msg":"[^"]+"')
    log "认证失败，服务端提示: $ERR_MSG"
else
    log "请求已发送，接口原始响应: $RESP"
fi
```

### 2.2 赋予执行权限并测试

保存并退出 `vi` 之后，在终端中赋予脚本可执行权限，并手动执行一次以验证效果：

```sh
chmod +x /root/scripts/szu_auth.sh
/bin/sh /root/scripts/szu_auth.sh
```

查看执行输出日志确认是否认证成功：
```sh
cat /root/scripts/szu_auth.log
```

---

## 三、配置系统级计划任务 (Cron) 守护

为了实现路由器全天候自动监控，一旦掉线在 1~2 分钟内无感重连，需将脚本接入系统的 `crond` 服务。

### 3.1 写入定时任务

1. 打开定时任务编辑器：
   ```sh
   crontab -e
   ```
2. 在最后一行添加轮询任务（设定为**每 2 分钟执行一次**检查）：
   ```cron
   */2 * * * * /bin/sh /root/scripts/szu_auth.sh >/dev/null 2>&1
   ```
3. 保存并退出编辑器。

### 3.2 启用并重启 Cron 服务

确保 OpenWrt 的计划任务服务已设为开机自启并立即处于激活状态：
```sh
/etc/init.d/cron enable
/etc/init.d/cron restart
```

---

## 四、网络状态与日志排查

在日常使用中，如遇到网络波动或异常，可通过以下命令实时追踪健康状态：

1. **查看实时自愈与认证日志**：
   ```sh
   tail -f /root/scripts/szu_auth.log
   ```
2. **确认 Cron 探针触发记录**：
   ```sh
   logread | grep crond
   ```
3. **强制测试掉线自愈**：
   * 可以在电脑上手动打开学校注销页面下线设备，观察约 1~2 分钟内脚本是否自动检测并拉起网络。