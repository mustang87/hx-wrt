#!/bin/sh
# HX-WRT: sanitize firewall config for fw4 (nftables)
# - Fix duplicate zones (@zone + named zone) causing:
#     Error: redefinition of symbol 'lan_devices' / 'wan_devices'
# - Ensure lan->wan forwarding & NAT works
# - Log to /tmp/.hxwrt/uci-defaults/

set -eu

HX_DIR="/tmp/.hxwrt/uci-defaults"
LOG="${HX_DIR}/94-firewall.log"
mkdir -p "${HX_DIR}"

log() { echo "[$(date '+%F %T')] $*" >> "${LOG}"; }

log "begin: firewall sanitize"

# If uci is missing, do nothing.
command -v uci >/dev/null 2>&1 || { log "uci not found, exit"; exit 0; }

# -----------------------------------------------------------------------------
# 1) REMOVE duplicate anonymous zones/forwardings (the root cause)
#    fw4 cannot tolerate duplicate lan/wan zones producing duplicated defines:
#      define lan_devices ...
#      define wan_devices ...
# -----------------------------------------------------------------------------
# Delete ALL anonymous zones: firewall.@zone[0], [1], ...
zdel=0
while uci -q delete firewall.@zone[0]; do
  zdel=$((zdel+1))
done
log "deleted anonymous zones: ${zdel}"

# Delete ALL anonymous forwardings to avoid duplicates/garbage
fdel=0
while uci -q delete firewall.@forwarding[0]; do
  fdel=$((fdel+1))
done
log "deleted anonymous forwardings: ${fdel}"

# (Optional) clean legacy firewall.user include if exists (fw4 ignores mostly, but keep clean)
# Do NOT delete file here; just ensure config doesn't reference it in a way that breaks fw4.
# (We only sanitize zones/forwardings which break fw4.)

# -----------------------------------------------------------------------------
# 2) Ensure defaults exist (keep conservative OpenWrt defaults)
# -----------------------------------------------------------------------------
# Ensure one defaults section exists
if ! uci -q get firewall.@defaults[0] >/dev/null 2>&1; then
  uci add firewall defaults >/dev/null
  log "created firewall defaults section"
fi
uci set firewall.@defaults[0].input='REJECT'
uci set firewall.@defaults[0].output='ACCEPT'
uci set firewall.@defaults[0].forward='REJECT'
log "set defaults: input=REJECT output=ACCEPT forward=REJECT"

# -----------------------------------------------------------------------------
# 3) Ensure named LAN zone exists and is correct
# -----------------------------------------------------------------------------
if ! uci -q get firewall.lan >/dev/null 2>&1; then
  uci set firewall.lan='zone'
  log "created named zone firewall.lan"
fi
uci set firewall.lan.name='lan'
uci set firewall.lan.network='lan'
uci set firewall.lan.input='ACCEPT'
uci set firewall.lan.output='ACCEPT'
uci set firewall.lan.forward='ACCEPT'
# mtu_fix is not needed on lan; keep unset
log "configured zone: lan"

# -----------------------------------------------------------------------------
# 4) Ensure named WAN zone exists and is correct (NAT on)
# -----------------------------------------------------------------------------
if ! uci -q get firewall.wan >/dev/null 2>&1; then
  uci set firewall.wan='zone'
  log "created named zone firewall.wan"
fi
uci set firewall.wan.name='wan'
uci set firewall.wan.network='wan wan6'
uci set firewall.wan.input='REJECT'
uci set firewall.wan.output='ACCEPT'
uci set firewall.wan.forward='REJECT'
uci set firewall.wan.masq='1'
uci set firewall.wan.mtu_fix='1'
log "configured zone: wan (masq=1)"

# -----------------------------------------------------------------------------
# 5) Ensure lan -> wan forwarding exists
# -----------------------------------------------------------------------------
# Create/ensure a single forwarding section
# We'll create a deterministic named forwarding section "lan_wan" to avoid duplicates.
if ! uci -q get firewall.lan_wan >/dev/null 2>&1; then
  uci set firewall.lan_wan='forwarding'
  log "created forwarding firewall.lan_wan"
fi
uci set firewall.lan_wan.src='lan'
uci set firewall.lan_wan.dest='wan'
log "configured forwarding: lan -> wan"

# -----------------------------------------------------------------------------
# 6) Keep common base rules (DHCP renew / ping / DHCPv6 / ICMPv6) if they exist
#    We do NOT remove any rules here to avoid breaking user features.
# -----------------------------------------------------------------------------

uci commit firewall
log "committed firewall config"

# Best-effort restart fw4 at first boot. If firewall isn't available yet, skip.
if [ -x /etc/init.d/firewall ]; then
  /etc/init.d/firewall restart >> "${LOG}" 2>&1 || log "firewall restart failed (see above)"
else
  log "/etc/init.d/firewall not found, skip restart"
fi

log "end: firewall sanitize"
exit 0
