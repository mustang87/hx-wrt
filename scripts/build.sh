#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

PROFILE="${1:-hx-wrt-wr3000k-dev}"

"${HXWRT_DIR}/scripts/openwrt_fetch.sh"
"${HXWRT_DIR}/scripts/prepare_tree.sh"
"${HXWRT_DIR}/scripts/openwrt_patch.sh"


cd "${OPENWRT_DIR}"

./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds update openclash || true
./scripts/feeds install -a -p openclash || true

echo "[DBG] config_apply start"
"${HXWRT_DIR}/scripts/config_apply.sh" "${PROFILE}"
echo "[DBG] config_apply done"

# 👇 加这行：按 FEATURES 调整最终 .config
echo "[DBG] config_tweak start"
"${HXWRT_DIR}/scripts/config_tweak.sh"
echo "[DBG] config_tweak done"

# ✅ 固化 .config（非交互、不会卡）
make defconfig
echo "[DBG] defconfig done"

rm -f "${OPENWRT_DIR}/bin/targets/mediatek/filogic/"*tenbay_wr3000k* 2>/dev/null || true

make -j"$(nproc)"

echo "[OK] build done"
echo "Artifacts: ${OPENWRT_DIR}/bin/targets/"
