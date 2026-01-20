#!/bin/sh

. /lib/functions.sh
. /lib/functions/preinit.sh

hx_ubi1_extroot() {
        echo "hx: preinit extroot begin" > /dev/kmsg

        # 如果 /overlay 已经挂载，直接跳过
        if mount | grep -qE ' on /overlay '; then
                echo "hx: /overlay already mounted, skip" > /dev/kmsg
                return 0
        fi

        # 1) attach ubi1 (mtd5)
        grep -qs '"ubi1"' /proc/mtd || {
                echo "hx: no mtd ubi1, skip" > /dev/kmsg
                return 0
        }

        ubidetach -m 5 >/dev/null 2>&1 || true

        if ubiattach -m 5 -d 1 >/dev/null 2>&1; then
                echo "hx: ubiattach mtd5 -> ubi1 OK (-d 1)" > /dev/kmsg
        else
                ubiattach -m 5 >/dev/null 2>&1 || true
                echo "hx: ubiattach mtd5 fallback done" > /dev/kmsg
        fi

        # 2) 等待 volume 节点
        i=0
        while [ $i -lt 80 ]; do
                [ -c /dev/ubi1_0 ] && break
                i=$((i+1))
                sleep 0.1
        done

        [ -c /dev/ubi1_0 ] || {
                echo "hx: /dev/ubi1_0 not ready, abort" > /dev/kmsg
                return 0
        }

        echo "hx: /dev/ubi1_0 ready, mounting to /overlay" > /dev/kmsg

        # 3) 挂载 UBIFS 到 /overlay
        mkdir -p /overlay
        mount -t ubifs /dev/ubi1_0 /overlay || {
                echo "hx: mount /dev/ubi1_0 -> /overlay failed" > /dev/kmsg
                return 0
        }

        # ★ 关键：准备 overlayfs 必要目录（防止 mount_root 覆盖）
        mkdir -p /overlay/upper /overlay/work

        echo "hx: extroot overlay mounted from ubi1_0" > /dev/kmsg
}

boot_hook_add preinit_essential hx_ubi1_extroot
