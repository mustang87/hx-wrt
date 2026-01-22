#!/bin/sh
# HX-WRT Reset Policy (preinit) - FIXED
#
# SAFE RULE:
# - Only wipe overlayfs runtime dirs: upper/work/.fs_state/.hxwrt
# - NEVER wipe /mnt/etc (UCI configs must survive reset fallback)
# - Operate ONLY on raw ubifs BEFORE mount_root

. /lib/functions.sh
. /lib/functions/preinit.sh 2>/dev/null || true
. /lib/functions/system.sh 2>/dev/null || true

HX_LOGGER="/usr/lib/hxwrt/log.sh"
[ -f "$HX_LOGGER" ] && . "$HX_LOGGER" || true

hxrp_log() {
  echo "hx-reset: $*" > /dev/kmsg 2>/dev/null || true
}

hxrp_board_name() {
  board_name 2>/dev/null || echo unknown
}

hxrp_board_ok() {
  [ "$(hxrp_board_name)" = "tenbay,wr3000k" ]
}

hxrp_root_is_overlayfs() {
  mount | grep -qE '^overlayfs:/overlay on / '
}

hxrp_build_id_rom() {
  [ -r /rom/etc/hxwrt_build_id ] && tr -d '\r\n' < /rom/etc/hxwrt_build_id
}

hxrp_build_id_overlay_from_mnt() {
  [ -r /mnt/.hxwrt/build_id ] && tr -d '\r\n' < /mnt/.hxwrt/build_id
}

hxrp_build_id_overlay_set_on_mnt() {
  mkdir -p /mnt/.hxwrt
  printf '%s\n' "$1" > /mnt/.hxwrt/build_id
  sync
}

hxrp_get_extroot_dev() {
  [ -e /dev/ubi1_0 ] && echo /dev/ubi1_0 && return 0
  return 1
}

hxrp_should_wipe_on_mnt() {
  [ -e /mnt/.extroot-erase ] && return 0

  local rom_id ovl_id
  rom_id="$(hxrp_build_id_rom)"
  ovl_id="$(hxrp_build_id_overlay_from_mnt)"

  [ -z "$rom_id" ] && return 1
  [ -z "$ovl_id" ] && return 0
  [ "$rom_id" != "$ovl_id" ] && return 0

  return 1
}

hxrp_wipe_overlay_runtime_on_mnt() {
  hxrp_log "wipe overlay runtime dirs on raw ubifs"

  ### FIX: ONLY wipe overlayfs runtime dirs
  rm -rf /mnt/upper 2>/dev/null || true
  rm -rf /mnt/work  2>/dev/null || true
  rm -rf /mnt/.fs_state 2>/dev/null || true
  rm -rf /mnt/.hxwrt 2>/dev/null || true

  rm -f  /mnt/.extroot-erase 2>/dev/null || true

  mkdir -p /mnt/upper /mnt/work
  sync
}

hxrp_main() {
  hxrp_board_ok || return 0

  # Too late → do nothing
  hxrp_root_is_overlayfs && return 0

  local extdev
  extdev="$(hxrp_get_extroot_dev)" || return 0

  mkdir -p /mnt
  mount -t ubifs "$extdev" /mnt || return 0

  local rom_id ovl_id
  rom_id="$(hxrp_build_id_rom)"
  ovl_id="$(hxrp_build_id_overlay_from_mnt)"

  if hxrp_should_wipe_on_mnt; then
    hxrp_wipe_overlay_runtime_on_mnt
  fi

  [ -n "$rom_id" ] && hxrp_build_id_overlay_set_on_mnt "$rom_id"

  umount /mnt 2>/dev/null || true
}

boot_hook_add preinit_main hxrp_main
