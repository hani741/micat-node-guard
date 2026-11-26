#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_DIR="/etc/sysctl.d"
SYSCTL_FILE="$CONF_DIR/99-micat-node-guard.conf"
F2B_DIR="/etc/fail2ban/jail.d"
F2B_FILE="$F2B_DIR/micat-sshd.local"
AUTO_FILE="/etc/apt/apt.conf.d/20auto-upgrades"
STATE="/var/lib/micat-node-guard"
BACKUP="$STATE/backups/$(date +%Y%m%d-%H%M%S)"

log(){ printf '\n[Micat Node Guard] %s\n' "$*"; }
die(){ echo "[ERROR] $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "请使用 root 执行"
source /etc/os-release
case "${ID:-}" in debian|ubuntu) ;; *) die "仅支持 Debian/Ubuntu";; esac

mkdir -p "$BACKUP" "$CONF_DIR" "$F2B_DIR" "$STATE/backups"
for f in "$SYSCTL_FILE" "$F2B_FILE" "$AUTO_FILE"; do
  if [[ -e "$f" ]]; then
    cp -a "$f" "$BACKUP/$(echo "$f" | sed 's#/#_#g').bak"
  else
    touch "$BACKUP/$(echo "$f" | sed 's#/#_#g').absent"
  fi
done
printf '%s\n' "$BACKUP" > "$STATE/latest_backup"

log "安装所需软件"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y fail2ban unattended-upgrades

log "安装内核网络参数"
install -m 0644 "$ROOT/config/sysctl.conf" "$SYSCTL_FILE"
sysctl --system

log "安装 SSH 防暴力破解规则"
install -m 0644 "$ROOT/config/fail2ban-sshd.local" "$F2B_FILE"
systemctl enable --now fail2ban
systemctl restart fail2ban

log "启用安全更新定时任务"
cat > "$AUTO_FILE" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades.service 2>/dev/null || true

log "安装完成，正在做基本检查"
systemctl is-active --quiet fail2ban || die "Fail2ban 未运行，请检查：journalctl -u fail2ban"
fail2ban-client status sshd || true
echo
echo "版本：$(cat "$ROOT/VERSION" 2>/dev/null || echo unknown)"
echo "系统：${PRETTY_NAME:-unknown}"
echo "配置：$SYSCTL_FILE"
echo "备份：$BACKUP"
echo "注意：本脚本不添加防火墙规则、不更改 SSH 端口、不强制设置拥塞控制算法。"
echo "完成。建议先从另一终端验证 SSH 登录及节点 TCP/UDP 业务。"
