#!/bin/sh
# HX-WRT unified logging library
#
# Goals:
# - Safe under: set -u / set -eu (never reference unset $1/$2)
# - Works in early boot (preinit) when /overlay may not be mounted yet
# - Provide:
#   - hx_log_init <component> [file]
#   - hx_log <level> <msg...>
#   - hx_log_kmsg <msg...>
#   - hx_log_promote / hx_log_rotate
#   - hx_log_path <category> [file]
#   - hx_log_redirect <category> [file]
#
# NOTE:
# - Persistent logs are stored under /overlay/hx/log when overlay is mounted
# - Temp logs are stored under /tmp/.hxwrt

HX_LOG_COMPONENT="${HX_LOG_COMPONENT:-hxwrt}"

HX_LOG_PERSIST_DIR="${HX_LOG_PERSIST_DIR:-/overlay/hx/log}"
HX_LOG_TMP_DIR="${HX_LOG_TMP_DIR:-/tmp/.hxwrt}"
HX_LOG_TMP_FILE="${HX_LOG_TMP_FILE:-${HX_LOG_TMP_DIR}/boot.log}"

HX_LOG_FILE="${HX_LOG_FILE:-}"   # resolved at init
HX_LOG_BOOT_ID="${HX_LOG_BOOT_ID:-}"

# -------------------------
# Internals
# -------------------------

hx__now() {
  # busybox date may not have %N; keep simple
  date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "1970-01-01 00:00:00"
}

hx__ensure_dir() {
  [ -n "${1:-}" ] || return 0
  [ -d "$1" ] || mkdir -p "$1" 2>/dev/null || true
}

hx__is_overlay_ready() {
  # Check mount table: /overlay must be a mountpoint.
  # Use /proc/mounts to avoid depending on "mount" output format.
  grep -qsE '[[:space:]]/overlay[[:space:]]' /proc/mounts && return 0
  return 1
}

hx__boot_id_load() {
  # Prefer persistent boot id if available, else tmp.
  if [ -f "${HX_LOG_PERSIST_DIR}/last_boot_id" ]; then
    HX_LOG_BOOT_ID="$(cat "${HX_LOG_PERSIST_DIR}/last_boot_id" 2>/dev/null || true)"
  elif [ -f "${HX_LOG_TMP_DIR}/last_boot_id" ]; then
    HX_LOG_BOOT_ID="$(cat "${HX_LOG_TMP_DIR}/last_boot_id" 2>/dev/null || true)"
  fi
}

hx__boot_id_new() {
  # Lightweight boot id: epoch + pid
  HX_LOG_BOOT_ID="$(date +%s 2>/dev/null || echo 0)-$$"
  hx__ensure_dir "${HX_LOG_TMP_DIR}"
  echo "${HX_LOG_BOOT_ID}" > "${HX_LOG_TMP_DIR}/last_boot_id" 2>/dev/null || true
}

hx__resolve_log_file() {
  # Decide log file based on overlay readiness.
  # Args: <file>
  local file="${1:-boot.log}"

  hx__ensure_dir "${HX_LOG_TMP_DIR}"
  hx__boot_id_load
  [ -n "${HX_LOG_BOOT_ID}" ] || hx__boot_id_new

  if hx__is_overlay_ready; then
    hx__ensure_dir "${HX_LOG_PERSIST_DIR}"
    HX_LOG_FILE="${HX_LOG_PERSIST_DIR}/${file}"
    echo "${HX_LOG_BOOT_ID}" > "${HX_LOG_PERSIST_DIR}/last_boot_id" 2>/dev/null || true
  else
    HX_LOG_FILE="${HX_LOG_TMP_FILE}"
  fi

  echo "${HX_LOG_COMPONENT}" > "${HX_LOG_TMP_DIR}/stage" 2>/dev/null || true
}

# -------------------------
# Public APIs
# -------------------------

hx_log_init() {
  # hx_log_init <component> [file]
  local comp="${1:-hxwrt}"
  local file="${2:-boot.log}"

  [ -n "$comp" ] && HX_LOG_COMPONENT="$comp"
  hx__resolve_log_file "$file"
}

hx_log() {
  # hx_log <level> <msg...>
  local lvl="${1:-I}"
  shift 2>/dev/null || true

  [ -n "${HX_LOG_FILE}" ] || hx_log_init "${HX_LOG_COMPONENT}" "boot.log"

  local ts msg
  ts="$(hx__now)"
  msg="$*"
  printf '%s [%s] [%s] %s\n' \
    "$ts" "${HX_LOG_BOOT_ID}" "${HX_LOG_COMPONENT}/${lvl}" "$msg" \
    >> "${HX_LOG_FILE}" 2>/dev/null || true
}

hx_log_kmsg() {
  # Optional: write to kernel ring buffer too
  # Usage: hx_log_kmsg "message"
  echo "hx: ${HX_LOG_COMPONENT}: $*" > /dev/kmsg 2>/dev/null || true
}

hx_log_promote() {
  # When overlay becomes ready, move tmp boot log to persistent log directory.
  hx__ensure_dir "${HX_LOG_TMP_DIR}"
  hx__ensure_dir "${HX_LOG_PERSIST_DIR}"

  hx__boot_id_load
  [ -n "${HX_LOG_BOOT_ID}" ] || hx__boot_id_new
  echo "${HX_LOG_BOOT_ID}" > "${HX_LOG_PERSIST_DIR}/last_boot_id" 2>/dev/null || true

  if [ -f "${HX_LOG_TMP_FILE}" ]; then
    {
      echo "----- PROMOTE $(hx__now) boot_id=${HX_LOG_BOOT_ID} -----"
      cat "${HX_LOG_TMP_FILE}" 2>/dev/null || true
      echo "----- END PROMOTE -----"
    } >> "${HX_LOG_PERSIST_DIR}/boot.log" 2>/dev/null || true
    : > "${HX_LOG_TMP_FILE}" 2>/dev/null || true
  fi

  HX_LOG_FILE="${HX_LOG_PERSIST_DIR}/boot.log"
}

hx_log_rotate() {
  # Simple rotate: if boot.log > 256KB, rotate to boot.log.1 (keep 3)
  local f="${HX_LOG_PERSIST_DIR}/boot.log"
  [ -f "$f" ] || return 0

  local sz
  sz="$(wc -c < "$f" 2>/dev/null || echo 0)"
  [ "${sz:-0}" -lt 262144 ] && return 0

  rm -f "${f}.3" 2>/dev/null || true
  [ -f "${f}.2" ] && mv -f "${f}.2" "${f}.3" 2>/dev/null || true
  [ -f "${f}.1" ] && mv -f "${f}.1" "${f}.2" 2>/dev/null || true
  mv -f "$f" "${f}.1" 2>/dev/null || true
  : > "$f" 2>/dev/null || true
}

hx_log_path() {
  # hx_log_path <category> [file]
  # Must be safe when only one arg is passed.
  local category="${1:-misc}"
  local file="${2:-}"

  case "$category" in
    uci-defaults)
      echo "/tmp/.hxwrt/uci-defaults/${file:-uci-defaults.log}"
      ;;
    uci-theme)
      echo "/tmp/.hxwrt/hx-uci-15-theme.log"
      ;;
    openclash)
      # keep compatibility: many places expect this fixed filename
      echo "/tmp/.hxwrt/openclash/${file:-hx-openclash-init-run.log}"
      ;;
    preinit)
      echo "/tmp/.hxwrt/preinit/${file:-preinit.log}"
      ;;
    *)
      echo "${HX_LOG_TMP_DIR}/${file:-misc.log}"
      ;;
  esac
}

hx_log_redirect() {
  # hx_log_redirect <category> [file]
  local category="${1:-misc}"
  local file="${2:-}"
  local path

  path="$(hx_log_path "$category" "$file")"
  hx__ensure_dir "${path%/*}"

  # Redirect stdout+stderr for the caller process
  exec > "$path" 2>&1
}

hx_log_redirect_append() {
  # hx_log_redirect_append <category> [file]
  # Same as hx_log_redirect, but append mode.
  local category="${1:-misc}"
  local file="${2:-}"
  local path

  path="$(hx_log_path "$category" "$file")"
  hx__ensure_dir "${path%/*}"

  exec >> "$path" 2>&1
}
