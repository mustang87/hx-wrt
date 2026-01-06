#!/bin/sh
set -e

wlan_name="OPWRT"
wlan_password="9876543210"

exec >/tmp/hx-uci-30-wifi.log 2>&1

# 保护：密码不足 8 位就不配 wifi
if [ -z "$wlan_name" ] || [ -z "$wlan_password" ] || [ ${#wlan_password} -lt 8 ]; then
  echo "[SKIP] wifi: invalid ssid/password"
  exit 0
fi

# Enable all wifi-device
idx=0
while uci -q get wireless.@wifi-device[$idx] >/dev/null; do
  uci -q set wireless.@wifi-device[$idx].disabled='0'
  idx=$((idx+1))
done

# Configure wifi-iface: 第一个当 2.4G SSID，第二个当 5G SSID（如果存在）
# 不假设 iface 数量一定为 2，按存在的数量配置
if uci -q get wireless.@wifi-iface[0] >/dev/null; then
  uci -q set wireless.@wifi-iface[0].disabled='0'
  uci -q set wireless.@wifi-iface[0].encryption='psk2'
  uci -q set wireless.@wifi-iface[0].ssid="$wlan_name"
  uci -q set wireless.@wifi-iface[0].key="$wlan_password"
fi

if uci -q get wireless.@wifi-iface[1] >/dev/null; then
  uci -q set wireless.@wifi-iface[1].disabled='0'
  uci -q set wireless.@wifi-iface[1].encryption='psk2'
  uci -q set wireless.@wifi-iface[1].ssid="${wlan_name}_5G"
  uci -q set wireless.@wifi-iface[1].key="$wlan_password"
fi

uci commit wireless || true

echo "[OK] wifi config staged (will apply on finish)"
exit 0
