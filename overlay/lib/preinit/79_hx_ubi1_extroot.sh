#!/bin/sh

. /lib/functions.sh
. /lib/functions/preinit.sh

hx_ubi1_attach() {
	[ -c /dev/ubi1 ] && return 0
	grep -qs '"ubi1"' /proc/mtd || return 0

	ubidetach -m 5 >/dev/null 2>&1 || true

	if ubiattach -m 5 -d 1 >/dev/null 2>&1; then
		return 0
	fi

	ubiattach -m 5 >/dev/null 2>&1 || true
	return 0
}

boot_hook_add preinit_main hx_ubi1_attach
