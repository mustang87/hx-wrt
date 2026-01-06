#!/usr/bin/env bash
set -euo pipefail

FEATURES="${FEATURES:-}"

has_feature() {
  local f="$1"
  case ",${FEATURES}," in
    *",${f},"*) return 0 ;;
    *) return 1 ;;
  esac
}

feature_list() {
  # 打印 features，便于日志
  echo "${FEATURES}"
}
