#!/bin/sh
# HX-WRT Reset Policy (preinit)
#
# Goals:
# 1) Hard reset: if extroot flag exists -> wipe overlay runtime dirs (upper/work/etc/.fs_state)
# 2) Default clean upgrade: if build_id changed -> wipe same set
# 3) Do NOT format or recreate UBI volumes (keep current overlay size/layout)
#
# IMPORTANT FIX (one-reboot):
# - NEVER wipe /overlay/* after root is already overlayfs (/).
# - Always wipe on RAW UBIFS by mounting the extroot volume to /mnt BEFORE mount_root.
#
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

# root already switched to overlayfs (too late to delete /overlay/upper in-place)
hxrp_root_is_overlayfs() {
  mount | grep -qE '^overlayfs:/overlay on / '
}

# ---- Build ID ----
hxrp_build_id_rom() {
  # Always output one line (possibly empty)
  if [ -r /rom/etc/hxwrt_build_id ]; then
    tr -d '\r\n' < /rom/etc/hxwrt_build_id 2>/dev/null || true
  fi
  echo ""
}

# NOTE: overlay build_id is stored on extroot volume.
# We'll read/write it on /mnt/.hxwrt/build_id after mounting raw ubifs.
hxrp_build_id_overlay_from_mnt() {
  if [ -r /mnt/.hxwrt/build_id ]; then
    tr -d '\r\n' < /mnt/.hxwrt/build_id 2>/dev/null || true
  fi
  echo ""
}

hxrp_build_id_overlay_set_on_mnt() {
  local id="$1"
  mkdir -p /mnt/.hxwrt 2>/dev/null || true
  printf '%s\n' "$id" > /mnt/.hxwrt/build_id 2>/dev/null || true
  sync
}

# ---- State dump ----
hxrp_dump_state() {
  hxrp_log I "state: board='$(hxrp_board_name)'"
  hxrp_log I "state: root_is_overlayfs=$(hxrp_root_is_overlayfs && echo 1 || echo 0)"

  # /overlay may or may not be mounted yet in this stage
  mount | grep ' /overlay ' 2>/dev/null | while read -r line; do
    hxrp_log I "mount: $line"
    break
  done
}

# ---- Find extroot device (prefer fstab.overlay.device; fallback /dev/ubi1_0) ----
hxrp_get_extroot_dev() {
  local dev=""
  dev="$(uci -q get fstab.overlay.device 2>/dev/null || true)"
  if [ -n "$dev" ] && [ -e "$dev" ]; then
    echo "$dev"
    return 0
  fi

  # common default
  if [ -e /dev/ubi1_0 ]; then
    echo "/dev/ubi1_0"
    return 0
  fi

  # try sysfs resolve: find ubi1_* whose name is extroot_overlay
  local p
  for p in /sys/class/ubi/ubi1_*; do
    [ -e "$p/name" ] || continue
    [ "$(cat "$p/name" 2>/dev/null)" = "extroot_overlay" ] || continue
    echo "/dev/$(basename "$p")"
    return 0
  done

  echo ""
  return 1
}

# ---- Wait extroot dev ready (because this 79- file can run before 79_ file) ----
hxrp_wait_extroot_dev() {
  local try dev
  for try in 1 2 3 4 5 6 7 8 9 10; do
    dev="$(hxrp_get_extroot_dev 2>/dev/null || true)"
    if [ -n "$dev" ] && [ -e "$dev" ]; then
      echo "$dev"
      return 0
    fi
    # Also allow disk_ready to finish attach/volume creation
    sleep 1
  done
  echo ""
  return 1
}

# ---- Decision: should wipe? (runs while /mnt is mounted) ----
hxrp_should_wipe_on_mnt() {
  # return 0 if should wipe
  if [ -e /mnt/.extroot-erase ]; then
    hxrp_log W "hard reset flag found: /mnt/.extroot-erase"
    return 0
  fi

  local rom_id ovl_id
  rom_id="$(hxrp_build_id_rom)"
  ovl_id="$(hxrp_build_id_overlay_from_mnt)"

  # Safety: ROM build_id empty -> do NOT auto wipe
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

# ---- Wipe (on /mnt raw ubifs) ----
hxrp_wipe_overlay_runtime_on_mnt() {
  hxrp_log W "wiping runtime dirs on raw ubifs: /mnt/{upper,work,etc,.fs_state,.hxwrt}"
  hxrp_log_kmsg "wipe runtime dirs on raw ubifs"

  rm -rf /mnt/upper 2>/dev/null || true
  rm -rf /mnt/work 2>/dev/null || true
  rm -rf /mnt/etc 2>/dev/null || true
  rm -rf /mnt/.fs_state 2>/dev/null || true
  rm -rf /mnt/.hxwrt 2>/dev/null || true

  # clear triggers/state
  rm -f  /mnt/.extroot-erase 2>/dev/null || true

  # create base dirs to avoid first boot half-broken
  mkdir -p /mnt/upper /mnt/work /mnt/etc 2>/dev/null || true

  sync
  hxrp_log W "wipe done"
}

hxrp_main() {
  hxrp_log_init

  hxrp_board_ok || {
    hxrp_log I "skip: board '$(hxrp_board_name)' not supported"
    return 0
  }

  hxrp_dump_state

  # Safety: if root already overlayfs, do NOTHING (too late)
  if hxrp_root_is_overlayfs; then
    hxrp_log W "root already overlayfs(/) -> refuse to wipe here (would cause double-reboot symptom)"
    return 0
  fi

  # Wait extroot volume device ready, then mount it to /mnt and operate there
  local extdev
  extdev="$(hxrp_wait_extroot_dev || true)"
  if [ -z "$extdev" ] || [ ! -e "$extdev" ]; then
    hxrp_log W "extroot dev not ready -> skip reset policy this boot"
    return 0
  fi

  mkdir -p /mnt 2>/dev/null || true
  if ! mount -t ubifs "$extdev" /mnt >/dev/null 2>&1; then
    hxrp_log W "mount raw ubifs to /mnt failed (dev=$extdev) -> skip"
    return 0
  fi

  # Promote tmp log once we know overlay storage exists (still before overlayfs root)
  if command -v hx_log_promote >/dev/null 2>&1; then
    hx_log_promote || true
    hxrp_log I "log promoted to persistent dir"
  fi

  local rom_id ovl_id
  rom_id="$(hxrp_build_id_rom)"
  ovl_id="$(hxrp_build_id_overlay_from_mnt)"
  hxrp_log I "build_id: rom='${rom_id:-<empty>}' overlay='${ovl_id:-<empty>}'"
  hxrp_log I "flag_extroot_erase=$([ -e /mnt/.extroot-erase ] && echo 1 || echo 0)"

  if hxrp_should_wipe_on_mnt; then
    hxrp_wipe_overlay_runtime_on_mnt
  else
    hxrp_log I "no wipe needed"
  fi

  # Record current build id after possible wipe
  if [ -n "$rom_id" ]; then
    hxrp_build_id_overlay_set_on_mnt "$rom_id"
    hxrp_log I "recorded build_id into overlay: $rom_id"
  else
    hxrp_log I "skip recording build_id: ROM build_id empty"
  fi

  umount /mnt >/dev/null 2>&1 || hxrp_log W "umount /mnt failed (busy?)"

  return 0
}

# MUST run before mount_root switches to overlayfs root.
# Using preinit_main ensures we can safely mount extroot volume to /mnt and wipe there.
boot_hook_add preinit_main hxrp_main
