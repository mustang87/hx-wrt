#!/bin/sh

. /lib/functions.sh
. /lib/functions/preinit.sh

hx_ubi1_extroot() {
	echo "hx: preinit_main extroot begin" > /dev/kmsg

	# 已经是 overlayfs 根，跳过
	mount | grep -q "overlayfs:/overlay on / " && {
		echo "hx: root already overlayfs, skip" > /dev/kmsg
		return 0
	}

	# 必须存在 mtd5: "ubi1"
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

	# 2) 等 /dev/ubi1_0 出现（给足时间）
	echo "hx: waiting /dev/ubi1_0 ..." > /dev/kmsg
	i=0
	while [ $i -lt 200 ]; do   # 20s
		[ -c /dev/ubi1_0 ] && break
		i=$((i+1))
		sleep 0.1
	done

	[ -c /dev/ubi1_0 ] || {
		echo "hx: /dev/ubi1_0 still not ready (timeout)" > /dev/kmsg
		return 0
	}

	echo "hx: /dev/ubi1_0 ready, mount ubifs upper" > /dev/kmsg

	# 3) 把 ubi1_0 挂到 tmp 作为 upper 层
	mkdir -p /tmp/hx-overlay
	mount -t ubifs /dev/ubi1_0 /tmp/hx-overlay || {
		echo "hx: mount ubi1_0 -> /tmp/hx-overlay failed" > /dev/kmsg
		return 0
	}

	mkdir -p /tmp/hx-overlay/upper /tmp/hx-overlay/work

	# 4) 用 overlayfs 覆盖根 /
	mount -t overlay overlayfs:/overlay \
		-o lowerdir=/,upperdir=/tmp/hx-overlay/upper,workdir=/tmp/hx-overlay/work / || {
		echo "hx: overlayfs mount to / failed" > /dev/kmsg
		return 0
	}

	echo "hx: overlayfs root mounted from ubi1_0 (OK)" > /dev/kmsg
}

# 关键：改到 preinit_main（别太早）
boot_hook_add preinit_main hx_ubi1_extroot
