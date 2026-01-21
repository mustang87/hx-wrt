#!/bin/sh
set -e

. /usr/lib/hxwrt/log.sh
hx_log_redirect "uci-theme"

uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci

echo "[OK] luci theme set to argon"
exit 0
