#!/bin/sh

set -eu

fail() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

[ "$(id -u)" -eq 0 ] || fail 'Please run this script as root.'
[ -f /etc/alpine-release ] || fail 'This script supports Alpine Linux only.'
[ ! -e /zero.fill ] || fail '/zero.fill already exists; refusing to overwrite it.'

SCRIPT_PATH=$(readlink -f "$0")
case "$SCRIPT_PATH" in
	/tmp/*) fail 'Move this script outside /tmp before running it.' ;;
esac

printf 'This will clear temporary files, logs, and root shell history,\n'
printf 'fill the remaining disk space, and power off the VM.\n'
printf 'Type yes to continue: '
IFS= read -r confirmation || fail 'No confirmation received.'
[ "$confirmation" = 'yes' ] || fail 'Cancelled.'

cleanup_zero_file() {
	if [ -e /zero.fill ]; then
    sync
		rm -f /zero.fill
		sync
	fi
}
trap cleanup_zero_file 0

if [ -x /etc/init.d/nginx ]; then
	rc-service nginx stop || true
fi

for init_script in /etc/init.d/php-fpm*; do
	if [ -x "$init_script" ]; then
		service=${init_script##*/}
		rc-service "$service" stop || true
	fi
done

rm -rf /var/cache/apk/*

for item in /tmp/* /tmp/.[!.]* /tmp/..?*; do
	if [ -e "$item" ] || [ -L "$item" ]; then
		rm -rf "$item"
	fi
done

find /var/log -type f -exec truncate -s 0 {} +
mkdir -p /var/log/nginx
chown -R nginx:nginx /var/log/nginx

rm -f /root/.ash_history /root/.bash_history

printf 'Writing zeros to free disk space; the expected disk-full message is normal.\n'
dd if=/dev/zero of=/zero.fill bs=1M || true
sync
rm -f /zero.fill
sync

printf 'Cleanup complete. Powering off the VM.\n'
poweroff
