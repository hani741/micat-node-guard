# Micat Node Guard 2.1.0

迷途猫落地服务器基础防护配置，适用于 Debian 11/12、Ubuntu 22.04/24.04。

## 2.1 更新内容

- Fail2ban SSH jail 固定使用 `backend = systemd`，避免系统没有 `/var/log/auth.log` 时启动失败。
- Debian/Ubuntu 安装 `python3-systemd`，提供 systemd journal 读取支持。
- 启动后验证 `fail2ban-client ping` 和 `fail2ban-client status sshd`，不再只检查服务进程。
- 修复 `curl | bash` 时 `BASH_SOURCE[0]` 为空导致的引导兼容问题。
- 备份改为首次安装保存一次，重复 apply/update 不覆盖首次安装基线。
- 卸载按首次安装基线恢复配置，不再依赖最后一次更新的备份目录。

## 一键安装

以 root 执行：

```bash
curl -fsSL https://raw.githubusercontent.com/hani741/micat-node-guard/main/install.sh | bash
```

默认安装目录：`/opt/micat-node-guard`

## 常用命令

```bash
bash /opt/micat-node-guard/scripts/check.sh
bash /opt/micat-node-guard/scripts/update.sh
bash /opt/micat-node-guard/scripts/uninstall.sh
```

## 安全边界

- 不添加 UFW/iptables/nftables 规则，不开放端口、不清空规则。
- 不修改 SSH 端口、SSH 登录策略或白名单。
- 不强制设置 BBR/拥塞控制算法。
- 不修改 Xray/sing-box 配置及监听端口。
- 不承诺抵御大流量 TCP/UDP DDoS；此类攻击需要机房/上游清洗。

## 重要提示

1. Fail2ban 的 SSH jail 会封禁达到阈值的来源 IP。固定跳板机应按需配置 `ignoreip`，避免误封。
2. 自动安全更新可能在维护窗口之外安装系统补丁，生产环境应安排维护窗口并监控重启需求。
3. 升级不会清空现有 Fail2ban 封禁数据库；不要手动删除 `/var/lib/fail2ban/fail2ban.sqlite3`。
4. 建议先在一台测试节点验证，再批量部署。
