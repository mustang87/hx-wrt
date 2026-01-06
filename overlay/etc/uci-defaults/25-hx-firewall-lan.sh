#!/bin/sh
set -e

exec >/tmp/hx-uci-25-firewall.log 2>&1

# 如果 lan zone 不存在，创建它
if ! uci -q get firewall.lan >/dev/null; then
  uci add firewall zone
  uci rename firewall.@zone[-1]='lan'
fi

# LAN zone 基本策略
uci set firewall.lan.name='lan'
uci set firewall.lan.input='ACCEPT'
uci set firewall.lan.output='ACCEPT'
uci set firewall.lan.forward='ACCEPT'

# 绑定 LAN 网络（关键）
uci set firewall.lan.network='lan'

# 确保防火墙启用
uci set firewall.@defaults[0].input='REJECT'
uci set firewall.@defaults[0].output='ACCEPT'
uci set firewall.@defaults[0].forward='REJECT'

uci commit firewall

echo "[OK] firewall lan zone fixed"
exit 0
