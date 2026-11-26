#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "请使用 root 执行"; exit 1; }
STATE="/var/lib/micat-node-guard"
BASELINE="$STATE/baseline"
SYSCTL_FILE="/etc/sysctl.d/99-micat-node-guard.conf"
F2B_FILE="/etc/fail2ban/jail.d/micat-sshd.local"
AUTO_FILE="/etc/apt/apt.conf.d/20auto-upgrades"

restore_one() {
  local target="$1" key
  key="$(printf '%s' "$target" | sed 's#/#_#g')"
  if [[ -f "$BASELINE/$key.saved" ]]; then
    mkdir -p "$(dirname "$target")"
    cp -a "$BASELINE/$key.saved" "$target"
  elif [[ -f "$BASELINE/$key.absent" ]]; then
    rm -f "$target"
  else
    echo "[跳过] 未找到首次安装基线：$target"
  fi
}

echo "将恢复首次安装前的 Micat Node Guard 管理配置。"
echo "不会卸载 Fail2ban/python3-systemd/unattended-upgrades，也不会修改防火墙规则。"
read -r -p "确认继续？输入 YES： " answer
[[ "$answer" == "YES" ]] || { echo "已取消"; exit 0; }

restore_one "$SYSCTL_FILE"
restore_one "$F2B_FILE"
restore_one "$AUTO_FILE"
sysctl --system >/dev/null 2>&1 || true
if fail2ban-client -t >/dev/null 2>&1; then
  systemctl restart fail2ban 2>/dev/null || true
else
  echo "[警告] 恢复后的 Fail2ban 配置检测失败，请检查配置后手动启动。"
fi
echo "配置恢复完成。首次安装基线保留在：$BASELINE"
