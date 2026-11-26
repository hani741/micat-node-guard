#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "请使用 root 执行"; exit 1; }
DIR="${MICAT_INSTALL_DIR:-/opt/micat-node-guard}"
[[ -d "$DIR/.git" ]] || { echo "未找到 Git 仓库：$DIR"; exit 1; }
git -C "$DIR" fetch --depth 1 origin
git -C "$DIR" reset --hard FETCH_HEAD
bash "$DIR/scripts/apply.sh"
