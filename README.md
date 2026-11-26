# Micat Node Guard 2.0

迷途猫落地服务器基础防护配置，适用于 **Debian 11/12** 和 **Ubuntu 22.04/24.04**。

> 这是服务器基础加固工具，不是 DDoS 清洗服务。它不会替代机房高防、上游流量清洗或专业防火墙。

## 功能

- TCP SYN Cookies、连接队列和网络缓冲区基础优化
- IPv4/IPv6 源路由及 ICMP Redirect 基础防护
- loose `rp_filter`，兼顾多网卡/策略路由场景
- Fail2ban SSH 暴力登录封禁
- unattended-upgrades 自动安全更新
- 安装前备份原有配置
- 检查、更新和卸载恢复脚本

## 安全边界

- **不添加 UFW/iptables/nftables 规则**，避免误封 Xray 的 TCP/UDP 端口或 SSH。
- **不修改 SSH 端口、不关闭密码登录、不改 SSH 白名单**。
- **不强制设置 BBR 或其他拥塞控制算法**。不同内核、云厂商及网络环境支持情况不同。
- 不承诺抵御大流量 UDP/TCP DDoS；此类攻击需要上游清洗/高防 IP。
- 建议先在一台测试节点验证，再批量部署。

## 发布到 GitHub

1. 在 GitHub 创建公开仓库：`micat-node-guard`。
2. 上传本项目全部文件，保持目录结构。
3. 确认 `install.sh` 位于仓库根目录。
4. 将下方命令中的 `YOUR_GITHUB_USERNAME` 替换为你的 GitHub 用户名。

## 一行安装（curl）

以 root 身份执行：

```bash
apt-get update && apt-get install -y curl git && \
MICAT_REPO="https://github.com/YOUR_GITHUB_USERNAME/micat-node-guard.git" \
bash -c 'curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/micat-node-guard/main/install.sh | bash'
```

如果仓库分支不是 `main`，请相应修改 URL。

## 常用命令

安装后默认目录：`/opt/micat-node-guard`

```bash
# 检查防护状态
bash /opt/micat-node-guard/scripts/check.sh

# 从 GitHub 更新并重新应用配置
bash /opt/micat-node-guard/scripts/update.sh

# 卸载本项目配置并尝试恢复安装前备份
bash /opt/micat-node-guard/scripts/uninstall.sh
```

## 安装后验证

```bash
systemctl status fail2ban --no-pager
fail2ban-client status sshd
sysctl net.ipv4.tcp_syncookies
sysctl net.core.somaxconn
ss -lntup
```

从**另一个终端**确认 SSH 仍可登录，并验证 Xray 的 TCP/UDP 节点业务后，再关闭当前 SSH 会话。

## 文件说明

```text
micat-node-guard/
├── install.sh
├── config/
│   ├── sysctl.conf
│   └── fail2ban-sshd.local
├── scripts/
│   ├── apply.sh
│   ├── check.sh
│   ├── update.sh
│   └── uninstall.sh
├── VERSION
└── README.md
```

## 重要说明

1. 本工具面向 Debian/Ubuntu 的 apt 系统；其他发行版不支持。
2. 安全更新可能在维护窗口之外安装系统安全补丁。生产环境建议安排维护窗口并监控重启需求。
3. Fail2ban 会根据 SSH 日志封禁多次失败的来源 IP。若你通过固定跳板机登录，请先确保其 IP 不会因误报被封；可按需在 `/etc/fail2ban/jail.d/micat-sshd.local` 增加 `ignoreip`，然后重启 Fail2ban。
4. sysctl 参数对不同内核/虚拟化网络环境的效果可能不同；如果业务出现异常，恢复备份或运行卸载脚本。
