#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

CACHE_DIR="${HXWRT_DIR}/.cache/sources"
LOCK_FILE="${HXWRT_DIR}/thirdparty.lock"

mkdir -p "${CACHE_DIR}"

log() { echo "$@"; }

is_sha() {
  # 7~40 位 hex 都算（兼容短 hash）
  [[ "${1:-}" =~ ^[0-9a-fA-F]{7,40}$ ]]
}

fetch_one() {
  local name="$1"
  local url="$2"
  local ref="$3"
  local dir="${CACHE_DIR}/${name}"

  if [ -z "${name}" ] || [ -z "${url}" ] || [ -z "${ref}" ]; then
    echo "[ERR] invalid lock entry: name='${name}' url='${url}' ref='${ref}'" >&2
    return 1
  fi

  # 1) clone（尽量轻量：depth=1 + 不自动拉 tag）
  if [ ! -d "${dir}/.git" ]; then
    log "[SRC] clone ${name} <- ${url}"
    git clone --depth 1 --no-tags "${url}" "${dir}"
  fi

  cd "${dir}"

  # 2) 确保 remote 是对的（避免之前 clone 错库导致体积爆炸）
  git remote set-url origin "${url}"

  # 3) 只抓指定 ref（避免 --all/--tags 拉爆）
  if is_sha "${ref}"; then
    # 指定 commit：只抓该 commit（浅抓）
    log "[SRC] fetch commit ${ref} (${name})"
    git fetch --depth 1 origin "${ref}"
    git checkout -f "${ref}"
  else
    # tag / branch：优先当 tag，其次当 branch
    # 先试 tag
    log "[SRC] fetch ref ${ref} (${name})"
    if git fetch --depth 1 --no-tags origin "refs/tags/${ref}:refs/tags/${ref}" 2>/dev/null; then
      git checkout -f "tags/${ref}"
    else
      # 再试 branch
      git fetch --depth 1 --no-tags origin "${ref}:${ref}" 2>/dev/null || git fetch --depth 1 --no-tags origin "${ref}"
      git checkout -f "${ref}" 2>/dev/null || git checkout -f "origin/${ref}"
    fi
  fi

  # 4) 输出当前落点
  log "[OK] source ${name}: ${url} @ $(git rev-parse --short HEAD)"
}

# lock 文件格式：name|url|ref
while IFS='|' read -r name url ref; do
  # trim
  name="${name#"${name%%[![:space:]]*}"}"; name="${name%"${name##*[![:space:]]}"}"
  url="${url#"${url%%[![:space:]]*}"}";   url="${url%"${url##*[![:space:]]}"}"
  ref="${ref#"${ref%%[![:space:]]*}"}";   ref="${ref%"${ref##*[![:space:]]}"}"

  # skip empty/comment
  [ -z "${name}" ] && continue
  case "${name}" in \#*) continue ;; esac

  fetch_one "${name}" "${url}" "${ref}"
done < "${LOCK_FILE}"


ensure_feeds_mirror() {
  local f="${OPENWRT_DIR}/feeds.conf.default"
  [ -f "$f" ] || return 0

  # 仅当包含 git.openwrt.org 时才替换
  if grep -q "git.openwrt.org" "$f"; then
    echo "[FEEDS] switch git.openwrt.org -> github mirror"
    sed -i 's#https://git.openwrt.org/feed/packages.git#https://github.com/openwrt/packages.git#g' "$f"
    sed -i 's#https://git.openwrt.org/feed/routing.git#https://github.com/openwrt/routing.git#g' "$f"
    sed -i 's#https://git.openwrt.org/feed/telephony.git#https://github.com/openwrt/telephony.git#g' "$f"
    sed -i 's#https://git.openwrt.org/project/luci.git#https://github.com/openwrt/luci.git#g' "$f"
  fi
}

feeds_update_with_fallback() {
  cd "${OPENWRT_DIR}"

  echo "[FEEDS] update -a"
  if ./scripts/feeds update -a; then
    return 0
  fi

  echo "[FEEDS] update failed, applying mirror + retry..."
  ensure_feeds_mirror

  ./scripts/feeds clean || true
  rm -rf feeds/packages feeds/routing feeds/luci feeds/telephony || true

  ./scripts/feeds update -a
}
