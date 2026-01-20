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

	# 1) attach ubi1 (mtd5 -> ubi1)
	ubidetach -m 5 >/dev/null 2>&1 || true
	ubiattach -m 5 -d 1 >/dev/null 2>&1 || {
		echo "hx: ubiattach mtd5 failed" > /dev/kmsg
		return 0
	}

	# 2) Ensure device nodes exist (preinit has no hotplug/mdev yet)
	# In your system they show as: /dev/ubi1 = c 249,0 ; /dev/ubi1_0 = c 249,1
	[ -c /dev/ubi1 ] || mknod -m 600 /dev/ubi1 c 249 0
	[ -c /dev/ubi1_0 ] || mknod -m 600 /dev/ubi1_0 c 249 1

	# 3) mount UBIFS (upper storage)
	mkdir -p /tmp/hx-overlay
	mount -t ubifs /dev/ubi1_0 /tmp/hx-overlay || {
		echo "hx: mount ubifs /dev/ubi1_0 -> /tmp/hx-overlay failed" > /dev/kmsg
		return 0
	}
	mkdir -p /tmp/hx-overlay/upper /tmp/hx-overlay/work

	# 4) mount overlayfs to /
	mount -t overlay overlayfs:/overlay \
		-o lowerdir=/,upperdir=/tmp/hx-overlay/upper,workdir=/tmp/hx-overlay/work / || {
		echo "hx: overlayfs mount to / failed" > /dev/kmsg
		umount /tmp/hx-overlay >/dev/null 2>&1 || true
		return 0
	}

	echo "hx: overlayfs root mounted from ubi1_0 (OK)" > /dev/kmsg
}

boot_hook_add preinit_main hx_ubi1_extroot
