#!/bin/sh
# HX-WRT Reset Policy (preinit)
#
# Goals:
# 1) Hard reset: if /overlay/.extroot-erase exists -> wipe overlay upper/work/etc/.fs_state
# 2) Default clean upgrade: if build_id changed -> wipe same set
# 3) Do NOT format or recreate UBI volumes (keep current overlay size/layout)
#
# This script is POLICY only. Disk/overlay mount should be handled by 79_hx_disk_ready.
# Target: WR3000K NAND+UBI with extroot_overlay on mtd "ubi1" -> /dev/ubi1_0 -> /overlay (ubifs)

. /lib/functions.sh
. /lib/functions/preinit.sh 2>/dev/null || true
. /lib/functions/system.sh 2>/dev/null || true

# ---- unified logger ----
HX_LOGGER="/usr/lib/hxwrt/log.sh"
if [ -f "$HX_LOGGER" ]; then
  # shellcheck disable=SC1090
  . "$HX_LOGGER" || true
fi

HXRP_LOG_INITED="${HXRP_LOG_INITED:-0}"

hxrp_log_init() {
  [ "$HXRP_LOG_INITED" = "1" ] && return 0
  HXRP_LOG_INITED=1

  if command -v hx_log_init >/dev/null 2>&1; then
    hx_log_init "preinit-reset" "preinit-reset.log"
    hx_log I "reset policy init"
    hx_log_kmsg "reset policy init"
  else
    echo "hx-preinit-reset: logger not available" > /dev/kmsg 2>/dev/null || true
  fi
}

hxrp_log() {
  # hxrp_log <level> <msg...>
  local lvl="$1"; shift
  if command -v hx_log >/dev/null 2>&1; then
    hx_log "$lvl" "$*"
    # keep kmsg concise to avoid spam
    hx_log_kmsg "$lvl $*"
  else
    echo "hx-preinit-reset[$lvl]: $*" > /dev/kmsg 2>/dev/null || true
  fi
}

hxrp_board_name() {
  board_name 2>/dev/null || echo unknown
}

hxrp_board_ok() {
  [ "$(hxrp_board_name)" = "tenbay,wr3000k" ]
}

hxrp_overlay_mounted() {
  mount | grep -qE ' on /overlay '
}

hxrp_dump_state() {
  # Do not fail if any command is missing
  hxrp_log I "state: board='$(hxrp_board_name)'"
  hxrp_log I "state: overlay_mounted=$(hxrp_overlay_mounted && echo 1 || echo 0)"
  hxrp_log I "state: flag_extroot_erase=$([ -e /overlay/.extroot-erase ] && echo 1 || echo 0)"
  hxrp_log I "state: ovl_upper=$([ -d /overlay/upper ] && echo 1 || echo 0) ovl_work=$([ -d /overlay/work ] && echo 1 || echo 0) ovl_etc=$([ -d /overlay/etc ] && echo 1 || echo 0) ovl_fs_state=$([ -e /overlay/.fs_state ] && echo 1 || echo 0)"
  # one line mount excerpt for /overlay
  mount | grep ' /overlay ' 2>/dev/null | while read -r line; do
    hxrp_log I "mount: $line"
    break
  done
}

hxrp_build_id_rom() {
  # Always output one line (possibly empty)
  if [ -r /rom/etc/hxwrt_build_id ]; then
    tr -d '\r\n' < /rom/etc/hxwrt_build_id 2>/dev/null || true
  fi
  echo ""
}

hxrp_build_id_overlay() {
  if [ -r /overlay/.hxwrt/build_id ]; then
    tr -d '\r\n' < /overlay/.hxwrt/build_id 2>/dev/null || true
  fi
  echo ""
}

hxrp_build_id_overlay_set() {
  local id="$1"
  mkdir -p /overlay/.hxwrt 2>/dev/null || true
  printf '%s\n' "$id" > /overlay/.hxwrt/build_id 2>/dev/null || true
  sync
}

hxrp_should_wipe() {
  # return 0 if should wipe
  if [ -e /overlay/.extroot-erase ]; then
    hxrp_log W "hard reset flag found: /overlay/.extroot-erase"
    return 0
  fi

  local rom_id ovl_id
  rom_id="$(hxrp_build_id_rom)"
  ovl_id="$(hxrp_build_id_overlay)"

  # Safety: ROM build_id empty -> do NOT auto wipe (avoid accidental wipe on dev images)
  if [ -z "$rom_id" ]; then
    hxrp_log I "ROM build_id empty -> skip auto wipe"
    return 1
  fi

  # First boot: no overlay record -> wipe
  if [ -z "$ovl_id" ]; then
    hxrp_log I "no overlay build_id -> treat as first boot -> wipe"
    return 0
  fi

  # Changed build -> wipe
  if [ "$rom_id" != "$ovl_id" ]; then
    hxrp_log I "build_id changed: rom='$rom_id' overlay='$ovl_id' -> wipe"
    return 0
  fi

  return 1
}

hxrp_wipe_overlay_runtime() {
  # X-WRT style cleanup: wipe overlay runtime dirs; keep other user data under /overlay/*
  hxrp_log W "wiping overlay runtime dirs: /overlay/{upper,work,etc,.fs_state}"
  hxrp_log_kmsg "wipe overlay runtime dirs"

  rm -rf /overlay/upper 2>/dev/null || true
  rm -rf /overlay/work 2>/dev/null || true
  rm -rf /overlay/etc 2>/dev/null || true
  rm -rf /overlay/.fs_state 2>/dev/null || true

  # clear triggers/state
  rm -f  /overlay/.extroot-erase 2>/dev/null || true
  rm -rf /overlay/.hxwrt 2>/dev/null || true

  sync
  hxrp_log W "overlay wipe done"
}

hxrp_main() {
  hxrp_log_init

  hxrp_board_ok || {
    hxrp_log I "skip: board '$(hxrp_board_name)' not supported"
    return 0
  }

  if ! hxrp_overlay_mounted; then
    # NOTE: disk_ready should mount it; if not, do nothing to avoid bricking boot.
    hxrp_log I "overlay not mounted yet; skip reset policy"
    hxrp_dump_state
    return 0
  fi

  # Promote tmp log to persistent as soon as overlay is ready
  if command -v hx_log_promote >/dev/null 2>&1; then
    hx_log_promote || true
    hxrp_log I "log promoted to persistent dir"
  fi

  hxrp_dump_state

  local rom_id ovl_id
  rom_id="$(hxrp_build_id_rom)"
  ovl_id="$(hxrp_build_id_overlay)"
  hxrp_log I "build_id: rom='${rom_id:-<empty>}' overlay='${ovl_id:-<empty>}'"

  if hxrp_should_wipe; then
    hxrp_wipe_overlay_runtime
  else
    hxrp_log I "no wipe needed"
  fi

  # Record current build id after possible wipe
  if [ -n "$rom_id" ]; then
    hxrp_build_id_overlay_set "$rom_id"
    hxrp_log I "recorded build_id into overlay: $rom_id"
  else
    hxrp_log I "skip recording build_id: ROM build_id empty"
  fi

  return 0
}

# Run late in preinit_main so /overlay is already mounted by 79_hx_disk_ready
boot_hook_add preinit_main hxrp_main
