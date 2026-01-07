#!/bin/sh
set -e

exec >/tmp/hx-uci-94-firewall.log 2>&1

# 清理旧的（防止重复刷/重复执行残留）
uci -q delete firewall.@defaults[0] || true
uci -q delete firewall.lan || true
uci -q delete firewall.wan || true

# 删掉所有 forwarding（只保留我们定义的一条 lan->wan）
while uci -q delete firewall.@forwarding[0]; do :; done

# defaults
uci add firewall defaults >/dev/null
uci set firewall.@defaults[0].input='REJECT'
uci set firewall.@defaults[0].output='ACCEPT'
uci set firewall.@defaults[0].forward='REJECT'

# lan zone
uci set firewall.lan=zone
uci set firewall.lan.name='lan'
uci set firewall.lan.network='lan'
uci set firewall.lan.input='ACCEPT'
uci set firewall.lan.output='ACCEPT'
uci set firewall.lan.forward='ACCEPT'

# wan zone
uci set firewall.wan=zone
uci set firewall.wan.name='wan'
uci set firewall.wan.network='wan'
# 开发阶段：允许从 WAN 口管理（你现在就需要这个）
uci set firewall.wan.input='ACCEPT'
uci set firewall.wan.output='ACCEPT'
uci set firewall.wan.forward='REJECT'
uci set firewall.wan.masq='1'
uci set firewall.wan.mtu_fix='1'

# forwarding: lan -> wan
uci add firewall forwarding >/dev/null
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='wan'

uci commit firewall

echo "[OK] firewall defaults/lan/wan/forwarding written"
exit 0
