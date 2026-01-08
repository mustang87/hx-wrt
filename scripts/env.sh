#!/usr/bin/env bash
set -euo pipefail

# 你的目录结构：work/
#   openwrt/   <- 底座（脚本拉取）
#   hx-wrt/    <- 你的发行版（本仓库）
export HXWRT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export WORK_DIR="$(cd "${HXWRT_DIR}/.." && pwd)"
export OPENWRT_DIR="${WORK_DIR}/openwrt"

# 默认 OpenWrt 远端 & 分支（你可随时改）
export OPENWRT_REMOTE="${OPENWRT_REMOTE:-https://github.com/openwrt/openwrt.git}"
# export OPENWRT_BRANCH="${OPENWRT_BRANCH:-main}"
export OPENWRT_BRANCH="${OPENWRT_BRANCH:-openwrt-25.12}"

# 输出目录（打包用）
export RELEASE_DIR="${HXWRT_DIR}/releases"
mkdir -p "${RELEASE_DIR}"
