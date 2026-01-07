#!/bin/sh
# OpenClash deps (feature)
# 只负责把依赖“选进固件”，不做运行时安装
set -e

# kmod / tproxy
uci -q get system.@system[0] >/dev/null 2>&1 || true

exit 0
