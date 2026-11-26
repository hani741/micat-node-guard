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

case "${ID:-}" in
    debian|ubuntu) ;;
    *) die "仅支持 Debian/Ubuntu" ;;
esac

command -v systemctl >/dev/null 2>&1 || die "需要 systemd"

mkdir -p "$BASELINE" /etc/sysctl.d /etc/fail2ban/jail.d /etc/apt/apt.conf.d


# =========================================================
# 1. 保存原始配置
# 只备份第一次安装前的配置，后续更新不覆盖原始备份
# =========================================================

backup_once() {
    local target="$1"
    local key

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


# =========================================================
# 2. 安装依赖
# =========================================================

log "安装依赖（含 systemd 日志支持）"

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    git \
    fail2ban \
    python3-systemd \
    unattended-upgrades


# =========================================================
# 3. 写入系统网络优化配置
# =========================================================

log "写入 sysctl 配置"

install -m 0644 "$ROOT/config/sysctl.conf" "$SYSCTL_FILE"

sysctl --system


# =========================================================
# 4. 写入 SSH Fail2ban 配置
# =========================================================

log "写入 SSH Fail2ban 配置（systemd journal 后端）"

install -m 0644 "$ROOT/config/fail2ban-sshd.local" "$F2B_FILE"

# 检查 Fail2ban 配置语法
fail2ban-client -t || die "Fail2ban 配置检测失败；未继续重启服务"

# 启用 Fail2ban
systemctl enable fail2ban

# 重启 Fail2ban，并检查重启命令是否成功
if ! systemctl restart fail2ban; then
    echo "[ERROR] Fail2ban 重启命令失败"

    systemctl status fail2ban --no-pager -l || true

    journalctl -u fail2ban -n 50 --no-pager || true

    die "Fail2ban 重启失败"
fi


# =========================================================
# 5. 等待 Fail2ban 完全启动
# 最多等待 30 秒，每秒检查一次
# =========================================================

log "等待 Fail2ban 服务及 SSH Jail 就绪"

READY=0

for attempt in {1..30}; do

    if systemctl is-active --quiet fail2ban \
        && fail2ban-client ping >/dev/null 2>&1 \
        && fail2ban-client status sshd >/dev/null 2>&1; then

        READY=1
        break
    fi

    sleep 1
done


# =========================================================
# 6. 启动失败时输出详细诊断信息
# =========================================================

if [[ "$READY" -ne 1 ]]; then

    echo
    echo "========================================"
    echo "[ERROR] Fail2ban 启动或 SSH Jail 检测失败"
    echo "========================================"

    echo
    echo "===== Fail2ban 服务状态 ====="

    systemctl status fail2ban --no-pager -l || true

    echo
    echo "===== Fail2ban 最近 50 条日志 ====="

    journalctl -u fail2ban -n 50 --no-pager || true

    echo
    echo "===== Fail2ban 配置检测 ====="

    fail2ban-client -t || true

    echo
    echo "===== Fail2ban Socket ====="

    ls -lah /run/fail2ban/ 2>&1 || true

    die "Fail2ban 未能在 30 秒内正常启动，请根据上述日志排查"
fi


# =========================================================
# 7. Fail2ban 启动成功
# =========================================================

log "Fail2ban 服务和 SSH Jail 已正常启动"

echo
echo "===== Fail2ban 通信检测 ====="

fail2ban-client ping

echo
echo "===== SSH 防护状态 ====="

fail2ban-client status sshd


# =========================================================
# 8. 配置自动安全更新
# =========================================================

log "配置 unattended-upgrades"

cat > "$AUTO_FILE" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl enable --now unattended-upgrades.service 2>/dev/null || true


# =========================================================
# 9. 记录安装版本
# =========================================================

printf '%s\n' "$(date -Is)" > "$STATE/installed"

printf '%s\n' "2.1.0" > "$STATE/installed_version"


# =========================================================
# 10. 安装完成，执行最终验证
# =========================================================

log "安装完成，执行最终验证"

echo
echo "===== Fail2ban 服务状态 ====="

systemctl --no-pager --full status fail2ban | sed -n '1,12p'

echo
echo "===== Fail2ban 通信检测 ====="

fail2ban-client ping

echo
echo "===== SSH 防护状态 ====="

fail2ban-client status sshd

echo
echo "========================================"
echo "Micat Node Guard 2.1.0 安装完成"
echo "========================================"

echo
echo "版本：2.1.0"
echo "基线备份：$BASELINE"
echo "配置：$SYSCTL_FILE"

echo
echo "安全说明："
echo "- 未添加或清空防火墙规则"
echo "- 未修改 SSH 端口"
echo "- 未修改 Xray TCP/UDP 端口"
echo "- 已启用 SSH Fail2ban 防护"
echo "- 已启用自动安全更新"

echo
echo "请从另一终端验证 SSH 登录，并检查节点业务连通性。"
