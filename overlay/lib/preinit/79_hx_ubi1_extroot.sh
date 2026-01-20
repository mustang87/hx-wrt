#!/bin/sh

. /lib/functions.sh
. /lib/functions/preinit.sh

hx_ubi1_attach() {
	[ -c /dev/ubi1 ] && return 0
	grep -qs '"ubi1"' /proc/mtd || return 0

	ubidetach -m 5 >/dev/null 2>&1 || true

	if ubiattach -m 5 -d 1 >/dev/null 2>&1; then
			:
	else
			ubiattach -m 5 >/dev/null 2>&1 || true
	fi

	# wait for ubi volume node (race-proof)
	i=0
	while [ $i -lt 20 ]; do
			[ -c /dev/ubi1_0 ] && break
			i=$((i+1))
			sleep 0.1
	done

	return 0
}


boot_hook_add preinit_main hx_ubi1_attach
