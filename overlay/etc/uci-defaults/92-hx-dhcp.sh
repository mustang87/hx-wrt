#!/bin/sh
set -e

. /usr/lib/hxwrt/log.sh
hx_log_redirect "uci-defaults" "92-dhcp.log"

# Set DHCP for LAN (地址池 + 启用)
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'
uci set dhcp.lan.ignore='0'
uci commit dhcp

echo "[OK] dhcp done"
exit 0
