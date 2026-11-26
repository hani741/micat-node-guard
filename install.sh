#!/usr/bin/env bash
# Micat Node Guard 2.0 - public GitHub/curl bootstrap installer
set -Eeuo pipefail

REPO_URL="${MICAT_REPO:-}"
INSTALL_DIR="${MICAT_INSTALL_DIR:-/opt/micat-node-guard}"

log(){ printf '\n[Micat Node Guard] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || die "请使用 root 执行：sudo bash"
command -v apt-get >/dev/null 2>&1 || die "当前安装器仅支持 Debian/Ubuntu（apt）"

# When piped from curl, bootstrap by cloning the public repository.
if [[ ! -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/scripts/apply.sh" ]]; then
    [[ -n "$REPO_URL" ]] || die "请设置 MICAT_REPO，例如：MICAT_REPO=https://github.com/OWNER/micat-node-guard.git"
    [[ "$REPO_URL" != *"YOUR_GITHUB_USERNAME"* ]] || die "请先把仓库地址中的 YOUR_GITHUB_USERNAME 替换为你的 GitHub 用户名"
    command -v git >/dev/null 2>&1 || { apt-get update; apt-get install -y git; }
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log "检测到已有仓库，更新代码"
        git -C "$INSTALL_DIR" pull --ff-only
    else
        if [[ -e "$INSTALL_DIR" ]]; then
            mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
        fi
        git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    fi
    exec bash "$INSTALL_DIR/install.sh" --local
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "--local" ]]; then
    exec bash "$SCRIPT_DIR/scripts/apply.sh"
fi
exec bash "$SCRIPT_DIR/scripts/apply.sh"
