#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

log() { echo "[BRAND] $*"; }

# =========================
# Config (you can override via env)
# =========================
HXWRT_MODEL_SHORT="${HXWRT_MODEL_SHORT:-WR3000K}"

# OpenWrt release branding (written into overlay)
HXWRT_DIST="${HXWRT_DIST:-HX-WRT}"
HXWRT_RELEASE="${HXWRT_RELEASE:-25.12.0}"     # what users see instead of 25.12-SNAPSHOT
HXWRT_TARGET="${HXWRT_TARGET:-mediatek/filogic}"
HXWRT_ARCH="${HXWRT_ARCH:-aarch64_cortex-a53}"

# Revision: by default keep real OpenWrt revision if we can read it; else fallback "unknown"
HXWRT_REVISION="${HXWRT_REVISION:-}"

# LuCI branding
HXWRT_LUCI_VARIANT="${HXWRT_LUCI_VARIANT:-LuCI Stable}" # replaces "LuCI Master"
HXWRT_LUCI_BRANCH="${HXWRT_LUCI_BRANCH:-stable}"        # replaces branch=master in luci.version

# Paths
OPENWRT_DIR="${OPENWRT_DIR:?OPENWRT_DIR not set}"
HXWRT_DIR="${HXWRT_DIR:?HXWRT_DIR not set}"

# =========================
# 1) Patch DTS model string (branch-agnostic: search & replace)
# =========================
patch_dts_model() {
  local dts_root="${OPENWRT_DIR}/target/linux/mediatek/dts"
  [ -d "${dts_root}" ] || { log "skip dts patch: ${dts_root} not found"; return 0; }

  # Find dts files that mention WR3000K and contain the full model string
  local hits
  hits="$(grep -RIl 'model = "Tenbay WR3000K"' "${dts_root}" 2>/dev/null || true)"

  if [ -z "${hits}" ]; then
    log "skip dts patch: no file contains model = \"Tenbay WR3000K\""
    return 0
  fi

  local f
  while IFS= read -r f; do
    log "patch dts model: ${f}"
    # idempotent replace
    sed -i 's/model = "Tenbay WR3000K";/model = "'"${HXWRT_MODEL_SHORT}"'";/g' "${f}"
  done <<< "${hits}"

  log "dts patch done"
}

# =========================
# 2) Generate branded release files into hx-wrt overlay
#    (branch-agnostic, stable; avoids touching OpenWrt internal version generator)
# =========================
detect_openwrt_revision() {
  # Try to infer revision from OpenWrt tree (git), else leave empty
  if [ -z "${HXWRT_REVISION}" ]; then
    if [ -d "${OPENWRT_DIR}/.git" ]; then
      HXWRT_REVISION="r$(git -C "${OPENWRT_DIR}" rev-list --count HEAD 2>/dev/null || true)-$(git -C "${OPENWRT_DIR}" rev-parse --short HEAD 2>/dev/null || true)"
    fi
  fi
  HXWRT_REVISION="${HXWRT_REVISION:-unknown}"
}

write_overlay_release_files() {
  detect_openwrt_revision

  local overlay="${HXWRT_DIR}/overlay"
  mkdir -p "${overlay}/etc" "${overlay}/usr/lib"

  local desc="${HXWRT_DIST} ${HXWRT_RELEASE} ${HXWRT_REVISION}"

  log "write overlay /etc/openwrt_release"
  cat > "${overlay}/etc/openwrt_release" <<EOF
DISTRIB_ID='${HXWRT_DIST}'
DISTRIB_RELEASE='${HXWRT_RELEASE}'
DISTRIB_REVISION='${HXWRT_REVISION}'
DISTRIB_TARGET='${HXWRT_TARGET}'
DISTRIB_ARCH='${HXWRT_ARCH}'
DISTRIB_DESCRIPTION='${desc}'
EOF

  log "write overlay /etc/openwrt_version"
  echo "${HXWRT_REVISION}" > "${overlay}/etc/openwrt_version"

  log "write overlay /usr/lib/os-release"
  cat > "${overlay}/usr/lib/os-release" <<EOF
NAME="${HXWRT_DIST}"
VERSION="${HXWRT_RELEASE}"
ID="hx-wrt"
PRETTY_NAME="${HXWRT_DIST} ${HXWRT_RELEASE}"
VERSION_ID="${HXWRT_RELEASE}"
EOF

  log "overlay release files done (${desc})"
}

# =========================
# 3) Patch LuCI "Master" exposure
#    (only if feeds/luci exists; safe across branches)
# =========================
patch_luci_master() {
  local luci_root="${OPENWRT_DIR}/feeds/luci"
  [ -d "${luci_root}" ] || { log "skip luci patch: ${luci_root} not found (feeds not updated yet?)"; return 0; }

  local luci_mk="${luci_root}/luci.mk"
  if [ -f "${luci_mk}" ]; then
    if grep -q 'variant="LuCI Master"' "${luci_mk}"; then
      log "patch luci.mk variant: LuCI Master -> ${HXWRT_LUCI_VARIANT}"
      sed -i 's/variant="LuCI Master"/variant="'"${HXWRT_LUCI_VARIANT}"'"/g' "${luci_mk}"
    else
      log "luci.mk variant already not 'LuCI Master' (skip)"
    fi
  else
    log "skip luci.mk patch: file not found: ${luci_mk}"
  fi

  # Patch luci-base version generator: branch from LUCI_GITBRANCH -> fixed string
  local luci_base_mk="${luci_root}/modules/luci-base/src/Makefile"
  if [ -f "${luci_base_mk}" ]; then
    if grep -q "branch = '$(LUCI_GITBRANCH)'" "${luci_base_mk}" 2>/dev/null; then
      log "patch luci-base branch: \$(LUCI_GITBRANCH) -> ${HXWRT_LUCI_BRANCH}"
      # only replace the branch part, keep revision intact
      sed -i "s/branch = '\\\$(LUCI_GITBRANCH)'/branch = '${HXWRT_LUCI_BRANCH}'/g" "${luci_base_mk}"
    else
      # Some branches may have different formatting; do a more tolerant replace
      if grep -q "LUCI_GITBRANCH" "${luci_base_mk}"; then
        log "patch luci-base branch (tolerant): LUCI_GITBRANCH -> ${HXWRT_LUCI_BRANCH}"
        sed -i "s/\\\$(LUCI_GITBRANCH)/${HXWRT_LUCI_BRANCH}/g" "${luci_base_mk}"
      else
        log "luci-base Makefile has no LUCI_GITBRANCH (skip)"
      fi
    fi
  else
    log "skip luci-base patch: file not found: ${luci_base_mk}"
  fi

  log "luci patch done"
}

main() {
  log "start: model='${HXWRT_MODEL_SHORT}', dist='${HXWRT_DIST}', release='${HXWRT_RELEASE}', luci='${HXWRT_LUCI_VARIANT}/${HXWRT_LUCI_BRANCH}'"

  patch_dts_model
  write_overlay_release_files
  patch_luci_master

  log "all done"
}

main "$@"
