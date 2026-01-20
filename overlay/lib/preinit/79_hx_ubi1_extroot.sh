#!/bin/sh

. /lib/functions.sh
. /lib/functions/preinit.sh

hx_ubi1_extroot() {
	echo "hx: preinit extroot begin" > /dev/kmsg

	# 如果根已经是 overlayfs，直接退出
	mount | grep -q "overlayfs:/overlay on / " && {
		echo "hx: root already overlayfs, skip" > /dev/kmsg
		return 0
	}

	# 1. attach ubi1 (mtd5)
	grep -qs '"ubi1"' /proc/mtd || {
		echo "hx: no ubi1 mtd, skip" > /dev/kmsg
		return 0
	}

	ubidetach -m 5 >/dev/null 2>&1 || true
	ubiattach -m 5 -d 1 >/dev/null 2>&1 || {
		echo "hx: ubiattach mtd5 failed" > /dev/kmsg
		return 0
	}

	# 2. wait for volume
	i=0
	while [ $i -lt 80 ]; do
		[ -c /dev/ubi1_0 ] && break
		i=$((i+1))
		sleep 0.1
	done

	[ -c /dev/ubi1_0 ] || {
		echo "hx: /dev/ubi1_0 not ready" > /dev/kmsg
		return 0
	}

	# 3. mount UBIFS as upper layer
	mkdir -p /tmp/hx-overlay
	if ! mount -t ubifs /dev/ubi1_0 /tmp/hx-overlay; then
		echo "hx: mount ubi1_0 -> /tmp/hx-overlay failed" > /dev/kmsg
		return 0
	fi

	mkdir -p /tmp/hx-overlay/upper /tmp/hx-overlay/work

	# 4. mount overlayfs AS ROOT (/)
	mount -t overlay overlayfs:/overlay \
		-o lowerdir=/,upperdir=/tmp/hx-overlay/upper,workdir=/tmp/hx-overlay/work / || {
		echo "hx: overlayfs mount failed" > /dev/kmsg
		return 0
	}

	echo "hx: overlayfs root mounted from ubi1_0" > /dev/kmsg
}

boot_hook_add preinit_essential hx_ubi1_extroot
