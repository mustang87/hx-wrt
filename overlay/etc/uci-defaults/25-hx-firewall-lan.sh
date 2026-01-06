#!/bin/sh
set -e

exec >/tmp/hx-uci-25-firewall.log 2>&1

# Ensure defaults exist
if ! uci -q get firewall.@defaults[0] >/dev/null; then
  uci add firewall defaults
fi

uci set firewall.@defaults[0].input='REJECT'
uci set firewall.@defaults[0].output='ACCEPT'
uci set firewall.@defaults[0].forward='REJECT'

# Ensure lan zone exists
if ! uci -q get firewall.lan >/dev/null; then
  uci add firewall zone
  uci rename firewall.@zone[-1]='lan'
fi

uci set firewall.lan.name='lan'
uci set firewall.lan.network='lan'
uci set firewall.lan.input='ACCEPT'
uci set firewall.lan.output='ACCEPT'
uci set firewall.lan.forward='ACCEPT'

uci commit firewall

# ✅ 关键：确保防火墙开机自启 + 立即生效
/etc/init.d/firewall enable || true
/etc/init.d/firewall restart || /etc/init.d/firewall start || true

echo "[OK] firewall defaults + lan ready"
exit 0
