#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "请使用 root 执行"; exit 1; }
STATE="/var/lib/micat-node-guard"
SYSCTL_FILE="/etc/sysctl.d/99-micat-node-guard.conf"
F2B_FILE="/etc/fail2ban/jail.d/micat-sshd.local"
AUTO_FILE="/etc/apt/apt.conf.d/20auto-upgrades"
BACKUP="$(cat "$STATE/latest_backup" 2>/dev/null || true)"

restore_one() {
  local target="$1" encoded="$2"
  if [[ -n "$BACKUP" && -f "$BACKUP/$encoded.bak" ]]; then
    cp -a "$BACKUP/$encoded.bak" "$target"
  elif [[ -n "$BACKUP" && -f "$BACKUP/$encoded.absent" ]]; then
    rm -f "$target"
  else
    rm -f "$target"
  fi
}
echo "将移除 Micat Node Guard 管理的配置。不会卸载软件包，也不会更改防火墙。"
read -r -p "确认继续？输入 YES： " answer
[[ "$answer" == "YES" ]] || { echo "已取消"; exit 0; }
restore_one "$SYSCTL_FILE" "_etc_sysctl.d_99-micat-node-guard.conf"
restore_one "$F2B_FILE" "_etc_fail2ban_jail.d_micat-sshd.local"
restore_one "$AUTO_FILE" "_etc_apt_apt.conf.d_20auto-upgrades"
sysctl --system >/dev/null 2>&1 || true
systemctl restart fail2ban 2>/dev/null || true
echo "配置恢复完成。Fail2ban、unattended-upgrades 软件包未卸载。"
