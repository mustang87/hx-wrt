#!/bin/sh

. /lib/functions.sh
. /lib/functions/preinit.sh

hx_ubi1_extroot() {
	echo "hx: preinit_main extroot begin" > /dev/kmsg

	# already overlayfs root?
	mount | grep -q "overlayfs:/overlay on / " && {
		echo "hx: root already overlayfs, skip" > /dev/kmsg
		return 0
	}

	grep -qs '"ubi1"' /proc/mtd || {
		echo "hx: no mtd ubi1, skip" > /dev/kmsg
		return 0
	}

	ubidetach -m 5 >/dev/null 2>&1 || true
	ubiattach -m 5 -d 1 >/dev/null 2>&1 || {
		echo "hx: ubiattach mtd5 failed" > /dev/kmsg
		return 0
	}

	echo "hx: waiting /dev/ubi1_0 (sleep=1s, max=30s) ..." > /dev/kmsg
	i=0
	while [ $i -lt 30 ]; do
		[ -c /dev/ubi1_0 ] && break
		i=$((i+1))
		sleep 1
	done

	[ -c /dev/ubi1_0 ] || {
		echo "hx: /dev/ubi1_0 still not ready (timeout 30s)" > /dev/kmsg
		return 0
	}

	echo "hx: /dev/ubi1_0 ready, mount ubifs upper" > /dev/kmsg

	mkdir -p /tmp/hx-overlay
	mount -t ubifs /dev/ubi1_0 /tmp/hx-overlay || {
		echo "hx: mount ubi1_0 -> /tmp/hx-overlay failed" > /dev/kmsg
		return 0
	}

	mkdir -p /tmp/hx-overlay/upper /tmp/hx-overlay/work

	mount -t overlay overlayfs:/overlay \
		-o lowerdir=/,upperdir=/tmp/hx-overlay/upper,workdir=/tmp/hx-overlay/work / || {
		echo "hx: overlayfs mount to / failed" > /dev/kmsg
		return 0
	}

	echo "hx: overlayfs root mounted from ubi1_0 (OK)" > /dev/kmsg
}

boot_hook_add preinit_main hx_ubi1_extroot
