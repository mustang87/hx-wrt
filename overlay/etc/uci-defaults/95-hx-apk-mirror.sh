#!/bin/sh
set -e

exec >/tmp/.hxwrt/uci-defaults/95-apk-mirror.log 2>&1

LIST="/etc/apk/repositories.d/distfeeds.list"
USTC_BASE="https://mirrors.ustc.edu.cn/openwrt"

echo "[INFO] hx-apk-mirror start: $(date -Is 2>/dev/null || date)"

# 备份原文件（可选）
if [ -f "$LIST" ] && [ ! -f "${LIST}.bak" ]; then
  cp "$LIST" "${LIST}.bak" || true
  echo "[OK] backup created: ${LIST}.bak"
fi

if [ ! -f "$LIST" ]; then
  echo "[SKIP] $LIST not found"
  exit 0
fi

# 1) 先替换为中科大镜像，并统一 https（只改域名部分）
sed -i 's|downloads.openwrt.org|mirrors.ustc.edu.cn/openwrt|g' "$LIST" || true
sed -i 's|http://|https://|g' "$LIST" || true

# 2) 判断是否应走 snapshots
#    条件：分支为 main / 25 或 URL 中含 snapshot/SNAPSHOT
#    注意：你的 bak 里是 releases/25.12-SNAPSHOT，所以也应命中
if grep -qiE '(/|-)25(\.|/|-)|main|trunk|snapshot' "$LIST"; then
  echo "[INFO] snapshot-like feeds detected, switching releases/* prefix to snapshots/* (keep suffix path)"

  # 只改“前缀”，保留后缀路径不变：
  # https://mirrors.ustc.edu.cn/openwrt/releases/<ver>/xxx  -> https://mirrors.ustc.edu.cn/openwrt/snapshots/xxx
  sed -i -E "s|${USTC_BASE}/releases/[^/]+/|${USTC_BASE}/snapshots/|g" "$LIST"

  # 如果有人写成了 .../snapshots/<something>/... 也不去破坏，最多只确保是 /snapshots/
  # （这一条可选；保守起见不做更深清洗）
else
  echo "[INFO] release feeds detected, keep releases path"
fi

echo "[OK] apk mirror updated"
exit 0
