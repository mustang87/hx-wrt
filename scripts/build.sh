#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"

CMD="${1:-build}"
PROFILE="${2:-hx-wrt-wr3000k-dev}"

# lib
source "${HXWRT_DIR}/scripts/lib/tmux_wrap.sh"

case "${CMD}" in
  build)
    # ./build.sh build [profile]
    tmux_wrap_run "${PROFILE}"
    ;;
  status)
    # ./build.sh status
    bash "${HXWRT_DIR}/scripts/lib/build_ctl.sh" status
    ;;
  tail)
    # ./build.sh tail
    bash "${HXWRT_DIR}/scripts/lib/build_ctl.sh" tail
    ;;
  stop)
    # ./build.sh stop
    bash "${HXWRT_DIR}/scripts/lib/build_ctl.sh" stop
    ;;
  *)
    echo "Usage:"
    echo "  ./build.sh build [profile]"
    echo "  ./build.sh status"
    echo "  ./build.sh tail"
    echo "  ./build.sh stop"
    exit 2
    ;;
esac
