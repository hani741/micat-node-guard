#!/usr/bin/env bash
# Micat Node Guard 2.1.0 - curl | bash bootstrap
set -Eeuo pipefail
umask 077

REPO_URL="${MICAT_REPO:-https://github.com/hani741/micat-node-guard.git}"
INSTALL_DIR="${MICAT_INSTALL_DIR:-/opt/micat-node-guard}"
log(){ printf '\n[Micat Node Guard] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "请使用 root 执行"
command -v apt-get >/dev/null 2>&1 || die "仅支持 Debian/Ubuntu（apt）"
[[ -r /etc/os-release ]] || die "无法读取 /etc/os-release"
. /etc/os-release
case "${ID:-}" in debian|ubuntu) ;; *) die "仅支持 Debian/Ubuntu";; esac

# BASH_SOURCE may be empty when this file is piped directly from curl.
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
LOCAL_MODE=0
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  [[ -f "$SCRIPT_DIR/scripts/apply.sh" ]] && LOCAL_MODE=1
fi

if [[ "$LOCAL_MODE" -eq 0 ]]; then
  command -v git >/dev/null 2>&1 || {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y git ca-certificates curl
  }
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "更新已有仓库代码"
    git -C "$INSTALL_DIR" fetch --depth 1 origin
    git -C "$INSTALL_DIR" reset --hard FETCH_HEAD
  else
    if [[ -e "$INSTALL_DIR" ]]; then
      mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi
  exec bash "$INSTALL_DIR/install.sh" --local
fi

exec bash "$SCRIPT_DIR/scripts/apply.sh"
