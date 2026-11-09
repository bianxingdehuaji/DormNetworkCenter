# To Be Continued... ⚡

> *"If it works, don't touch it. If it touches your workflow, hack it until it's seamless."*

`DormNetworkCenter` 最初只是为了解决宿舍断网、多设备互传受阻与内网穿透痛点而攒出的小玩具。但在折腾的过程中，百元级路由（CR6608）与手头设备的潜力被一步步压榨到了极限。

网络工程没有终点，只要宿舍电闸没跳，Hack 就不会停止。

---

### 🛠️ Next in Pipeline (Roadmap)

- [ ] **Home Assistant 边缘化接入**：尝试将轻量级 MQTT Broker 部署到网关，利用宿舍 Wi-Fi 状态实现离舍/归宿自动化联动。
- [ ] **自动化电费监控与报警**：逆向校园宿管电费充值系统接口，通过 Telegram Bot 自动推送余量告警。
- [ ] **IPv6 WireGuard 直连优化**：探索校园内网分配的动态 `/64` IPv6 地址池，绕过 Tailscale DERP 打造绝对零中继的极速握手通道。
- [ ] **Docker on PC 算力矩阵**：将 Windows PC 上的 WSL2 算力进一步解耦，利用内网提供本地 LLM (Ollama) 私有推理接口与局域网 Git 备份。

---

### 📡 Status: Idle but Listening

```bash
while [ "$PASSION" = "TRUE" ]; do
    hack_the_dorm_network
    sleep 86400
done
```

欢迎交流。**Keep hacking, stay hungry.** 🚀

如果你有任何疑问，或你想联系到我：发送邮件至  120763101+bianxingdehuaji@users.noreply.github.com 。我会一一答复。