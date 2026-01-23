#!/bin/sh
# HX-WRT Reset/Wipe Policy (library for disk_ready)
#
# 约定：
# - 本脚本不负责 mount/umount，只在 /mnt (raw ubifs) 上操作
# - 由 79_hx_disk_ready 在 mount /mnt 成功后调用 hxrp_wipe_policy_on_mnt
#
# wipe 规则：
# - SOFT：只清 runtime（upper/work/.fs_state/.hxwrt），保留 /mnt/etc（保留 UCI）
# - HARD：清 runtime + /mnt/etc（等价“重置配置/host key 等”）
#
# 触发来源：
# - /mnt/.extroot-erase-hard
# - /mnt/.extroot-erase-soft
# - build_id 变化（视作 SOFT wipe）

. /lib/functions.sh 2>/dev/null || true
. /usr/lib/hxwrt/log.sh 2>/dev/null || true

hxrp_log() {
	# 统一走 hx_log；没有就退回 kmsg
	if command -v hx_log >/dev/null 2>&1; then
		hx_log "$@"
	else
		echo "hx-reset: $*" > /dev/kmsg 2>/dev/null || true
	fi
}

hxrp_read_build_id_rom() {
	[ -r /rom/etc/hxwrt_build_id ] && tr -d '\r\n' < /rom/etc/hxwrt_build_id
}

hxrp_read_build_id_on_mnt() {
	[ -r /mnt/.hxwrt/build_id ] && tr -d '\r\n' < /mnt/.hxwrt/build_id
}

hxrp_write_build_id_on_mnt() {
	local id="$1"
	[ -n "$id" ] || return 0
	mkdir -p /mnt/.hxwrt 2>/dev/null || true
	printf '%s\n' "$id" > /mnt/.hxwrt/build_id 2>/dev/null || true
	sync
}

# exported API: run wipe policy ONLY when /mnt is raw ubifs extroot
hxrp_wipe_policy_on_mnt() {
	# /mnt 必须已挂载为 raw ubifs
	mountpoint -q /mnt 2>/dev/null || return 0

	local wiped=0 hard=0 soft=0
	[ -e /mnt/.extroot-erase-hard ] && hard=1
	[ -e /mnt/.extroot-erase-soft ] && soft=1

	if [ "$hard" -eq 1 ]; then
		hxrp_log W "disk_ready: found HARD flag -> factory wipe"
		wiped=2
	elif [ "$soft" -eq 1 ]; then
		hxrp_log W "disk_ready: found SOFT flag -> runtime wipe"
		wiped=1
	fi

	# build_id 变化：触发 SOFT wipe
	local rom_id ovl_id
	rom_id="$(hxrp_read_build_id_rom 2>/dev/null || true)"
	ovl_id="$(hxrp_read_build_id_on_mnt 2>/dev/null || true)"

	if [ -n "$rom_id" ]; then
		if [ -z "$ovl_id" ] || [ "$rom_id" != "$ovl_id" ]; then
			hxrp_log W "disk_ready: build_id changed (rom='$rom_id' ovl='$ovl_id') -> SOFT wipe"
			[ "$wiped" -lt 1 ] && wiped=1
		fi
	else
		hxrp_log W "disk_ready: ROM build_id empty -> skip auto wipe"
	fi

	[ "$wiped" -ge 1 ] || return 0

	if [ "$wiped" -eq 2 ]; then
		# HARD：包含 /mnt/etc（会清掉 dropbear host key / UCI config）
		hxrp_log W "disk_ready: HARD wipe /mnt/{upper,work,etc,.fs_state,.hxwrt}"
		rm -rf /mnt/upper /mnt/work /mnt/etc /mnt/.fs_state /mnt/.hxwrt 2>/dev/null || true
	else
		# SOFT：保留 /mnt/etc（UCI config survive）
		hxrp_log W "disk_ready: SOFT wipe /mnt/{upper,work,.fs_state,.hxwrt} (keep /mnt/etc)"
		rm -rf /mnt/upper /mnt/work /mnt/.fs_state /mnt/.hxwrt 2>/dev/null || true
	fi

	rm -f /mnt/.extroot-erase-hard /mnt/.extroot-erase-soft 2>/dev/null || true

	# recreate required dirs
	mkdir -p /mnt/upper /mnt/work 2>/dev/null || true
	[ "$wiped" -eq 2 ] && mkdir -p /mnt/etc 2>/dev/null || true

	# record build id
	hxrp_write_build_id_on_mnt "$rom_id"

	sync
	hxrp_log W "disk_ready: wipe done (level=$wiped)"
	return 0
}

# IMPORTANT:
# 不要在这里 boot_hook_add！顺序由 79_hx_disk_ready 控制
