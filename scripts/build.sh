#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

PROFILE="${1:-hx-wrt-wr3000k-dev}"

"${HXWRT_DIR}/scripts/openwrt_fetch.sh"
"${HXWRT_DIR}/scripts/prepare_tree.sh"

cd "${OPENWRT_DIR}"

./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds update openclash || true
./scripts/feeds install -a -p openclash || true

"${HXWRT_DIR}/scripts/config_apply.sh" "${PROFILE}"

# 👇 加这行：按 FEATURES 调整最终 .config
"${HXWRT_DIR}/scripts/config_tweak.sh"

make -j"$(nproc)" target/install

echo "[OK] build done"
echo "Artifacts: ${OPENWRT_DIR}/bin/targets/"
