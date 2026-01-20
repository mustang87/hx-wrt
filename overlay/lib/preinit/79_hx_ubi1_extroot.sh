#!/bin/sh

. /lib/functions.sh
. /lib/functions/preinit.sh

hx_ubi1_attach() {
	# prove the hook runs
	echo "hx: preinit_essential: hx_ubi1_attach enter" > /dev/kmsg

	# already attached
	[ -c /dev/ubi1 ] && {
		echo "hx: ubi1 already present (/dev/ubi1), skip attach" > /dev/kmsg
		return 0
	}

	# no mtd partition, nothing to do
	grep -qs '"ubi1"' /proc/mtd || {
		echo "hx: mtd5 ubi1 not found in /proc/mtd, skip" > /dev/kmsg
		return 0
	}

	# try detach first (ignore errors)
	ubidetach -m 5 >/dev/null 2>&1 || true

	# attach explicitly to ubi device 1 first, fallback generic attach
	if ubiattach -m 5 -d 1 >/dev/null 2>&1; then
		echo "hx: ubiattach mtd5 -> ubi1 OK (-d 1)" > /dev/kmsg
	else
		ubiattach -m 5 >/dev/null 2>&1 || true
		echo "hx: ubiattach mtd5 generic attempted" > /dev/kmsg
	fi

	# wait for ubi volume node (race-proof)
	echo "hx: ubi1 preinit attach done, waiting /dev/ubi1_0" > /dev/kmsg
	i=0
	while [ $i -lt 50 ]; do
		[ -c /dev/ubi1_0 ] && {
			echo "hx: /dev/ubi1_0 ready" > /dev/kmsg
			break
		}
		i=$((i+1))
		sleep 0.1
	done

	return 0
}

boot_hook_add preinit_essential hx_ubi1_attach
