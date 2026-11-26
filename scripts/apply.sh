#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="/var/lib/micat-node-guard"
BASELINE="$STATE/baseline"
SYSCTL_FILE="/etc/sysctl.d/99-micat-node-guard.conf"
F2B_FILE="/etc/fail2ban/jail.d/micat-sshd.local"
AUTO_FILE="/etc/apt/apt.conf.d/20auto-upgrades"
log(){ printf '\n[Micat Node Guard] %s\n' "$*"; }
die(){ echo "[ERROR] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "请使用 root 执行"
. /etc/os-release
case "${ID:-}" in debian|ubuntu) ;; *) die "仅支持 Debian/Ubuntu";; esac
command -v systemctl >/dev/null 2>&1 || die "需要 systemd"

mkdir -p "$BASELINE" /etc/sysctl.d /etc/fail2ban/jail.d /etc/apt/apt.conf.d

# Save the pre-Micat baseline once. Re-applying/updating never overwrites it.
backup_once() {
  local target="$1" key
  key="$(printf '%s' "$target" | sed 's#/#_#g')"
  if [[ ! -e "$BASELINE/$key.saved" && ! -e "$BASELINE/$key.absent" ]]; then
    if [[ -e "$target" ]]; then
      cp -a "$target" "$BASELINE/$key.saved"
    else
      : > "$BASELINE/$key.absent"
    fi
  fi
}
backup_once "$SYSCTL_FILE"
backup_once "$F2B_FILE"
backup_once "$AUTO_FILE"

log "安装依赖（含 systemd 日志支持）"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git fail2ban python3-systemd unattended-upgrades

log "写入 sysctl 配置"
install -m 0644 "$ROOT/config/sysctl.conf" "$SYSCTL_FILE"
sysctl --system

log "写入 SSH Fail2ban 配置（systemd journal 后端）"
install -m 0644 "$ROOT/config/fail2ban-sshd.local" "$F2B_FILE"
fail2ban-client -t || die "Fail2ban 配置检测失败；未继续重启服务"
systemctl enable fail2ban
systemctl restart fail2ban
systemctl is-active --quiet fail2ban || die "Fail2ban 服务未运行；查看 journalctl -u fail2ban"
fail2ban-client ping | grep -q pong || die "Fail2ban socket 通信检测失败"
fail2ban-client status sshd >/dev/null || die "sshd jail 未正常加载"

log "配置 unattended-upgrades"
cat > "$AUTO_FILE" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades.service 2>/dev/null || true

printf '%s\n' "$(date -Is)" > "$STATE/installed"
printf '%s\n' "2.1.0" > "$STATE/installed_version"

log "安装完成，执行验证"
systemctl --no-pager --full status fail2ban | sed -n '1,12p'
fail2ban-client ping
fail2ban-client status sshd
echo
echo "版本：2.1.0"
echo "基线备份：$BASELINE"
echo "配置：$SYSCTL_FILE"
echo "说明：未添加/清空防火墙规则，未修改 SSH 端口及 Xray TCP/UDP 端口。"
echo "请从另一终端验证 SSH 登录，并检查节点业务连通性。"
