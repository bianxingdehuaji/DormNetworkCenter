#!/bin/sh
# ==============================================================================
# SZU Campus Network Auto-Auth & Keepalive Script (wget edition)
# 深圳大学校园网自动登录与状态探活自愈脚本 (基于内置 wget/uclient-fetch)
# ==============================================================================

# ----------------- 用户配置区域 (按需修改) -----------------
USER_ACCOUNT="Account"    # 校园网登录学号/账号
USER_PASSWORD="Password"    # 校园网登录密码
LOG_FILE="/tmp/szu_auth.log" # 运行日志路径 (强烈建议放在 /tmp 防止写坏 Flash)
MAX_LOG_LINES=500                 # 日志最大保留行数

# ----------------- 接口与探针参数 -----------------
AUTH_SERVER="http://172.30.255.42:801/eportal/portal/login"
# 外网连通性探测接口
PROBE_URL="http://connect.rom.miui.com/generate_204"

# ----------------- 基础函数定义 -----------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 日志轮转，避免 Flash 存储溢出 (即使在 /tmp 也控制一下大小)
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
    
    # 若通过 ubus 未取到，回退使用 ifconfig 直接提取 (需根据实际接口名修改 eth0.2 或 wan)
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

# 1. 探测外网是否连通
# 使用内置的 uclient-fetch 或 wget 进行探测
# uclient-fetch 对 HTTP 状态码提取可能不如 curl 方便，这里直接判断能否拉取成功
# 使用 ping 探测阿里 DNS，发 2 个包，超时 3 秒
ping -c 2 -W 3 223.5.5.5 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    # 网络正常，静默退出
    exit 0
fi
log "检测到外网异常断开，准备触发自动登录认证..."

# 2. 获取当前 WAN 口 IP
CURRENT_IP=$(get_wan_ip)

if [ -z "$CURRENT_IP" ]; then
    log "错误：无法获取当前 WAN 口内网 IP，网线可能未插好或未获取到 DHCP 地址。"
    exit 1
fi

log "获取到当前内网 IP: $CURRENT_IP，正在组装参数发起 GET 鉴权..."

# 3. 组装请求 URL
AUTH_URL="${AUTH_SERVER}?callback=dr1003&login_method=1&user_account=${USER_ACCOUNT}&user_password=${USER_PASSWORD}&wlan_user_ip=${CURRENT_IP}&wlan_user_ipv6=&wlan_vlan_id=0&wlan_encac_id=0&wlan_direct_ip=0&wlan_user_mac=000000000000"

# 4. 发送 GET 认证请求
# 使用 wget，添加 User-Agent 伪装，并输出错误信息
RESP=$(wget --no-check-certificate -qO- --header="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "$AUTH_URL" 2>&1)

# 5. 解析结果
if echo "$RESP" | grep -q '"result":1'; then
    log "认证成功！网络已恢复畅通。"
elif echo "$RESP" | grep -q '"result":0'; then
    ERR_MSG=$(echo "$RESP" | grep -oE '"msg":"[^"]+"')
    log "认证失败，服务端提示: $ERR_MSG"
else
    log "请求已发送，接口原始响应: $RESP"
fi