#!/bin/sh
set -e

exec >/tmp/hx-uci-15-theme.log 2>&1

uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

echo "[OK] luci theme set to argon"
exit 0
