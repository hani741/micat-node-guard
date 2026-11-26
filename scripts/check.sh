#!/usr/bin/env bash
set -u
echo "===== Micat Node Guard 2.1 检查 ====="
echo "版本：$(cat /opt/micat-node-guard/VERSION 2>/dev/null || echo unknown)"
echo
for key in net.ipv4.tcp_syncookies net.ipv4.tcp_max_syn_backlog net.core.somaxconn net.ipv4.conf.all.rp_filter fs.file-max; do
  printf '%-42s ' "$key"
  sysctl -n "$key" 2>/dev/null || echo "无法读取"
done
echo
if systemctl is-active --quiet fail2ban; then
  echo "[正常] Fail2ban 正在运行"
  fail2ban-client ping 2>&1 || true
  fail2ban-client status sshd 2>&1 || true
else
  echo "[警告] Fail2ban 未运行"
  journalctl -u fail2ban -n 30 --no-pager 2>/dev/null || true
fi
echo
echo "监听端口（仅展示，不修改）："
ss -lntup 2>/dev/null | head -n 40 || true
echo "===== 检查结束 ====="
