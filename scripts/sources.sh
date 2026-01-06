#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

CACHE_DIR="${HXWRT_DIR}/.cache/sources"
LOCK_FILE="${HXWRT_DIR}/thirdparty.lock"

mkdir -p "${CACHE_DIR}"

fetch_one() {
  local name="$1"
  local url="$2"
  local ref="$3"
  local dir="${CACHE_DIR}/${name}"

  if [ ! -d "${dir}/.git" ]; then
    git clone --depth 1 "${url}" "${dir}"
  fi

  cd "${dir}"
  git fetch --all --tags --prune

  # ref 可能是 tag/branch/commit
  git checkout -f "${ref}" || {
    # 如果 ref 是 tag/commit 但浅克隆拿不到，补抓
    git fetch --unshallow || true
    git fetch --all --tags --prune
    git checkout -f "${ref}"
  }

  echo "[OK] source ${name}: ${url} @ ${ref}"
}

# 根据 lock 文件拉取
while IFS='|' read -r name url ref; do
  # skip empty/comment
  [ -z "${name}" ] && continue
  case "${name}" in \#*) continue ;; esac

  fetch_one "${name}" "${url}" "${ref}"
done < "${LOCK_FILE}"
