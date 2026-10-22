#!/bin/sh

set -eu

BAIKAL_VERSION="${BAIKAL_VERSION:-0.13.0}"
BAIKAL_URL="${BAIKAL_URL:-https://github.com/sabre-io/Baikal/releases/download/${BAIKAL_VERSION}/baikal-${BAIKAL_VERSION}.zip}"
BAIKAL_DIR="/var/www/baikal"
BACKUP_BAIKAL_DIR="${BACKUP_BAIKAL_DIR:-/var/backups/baikal/update-$(date +%Y%m%d-%H%M%S)}"
ARCHIVE="/tmp/baikal-${BAIKAL_VERSION}.zip"
WORK_DIR="/tmp/baikal-update-${BAIKAL_VERSION}"
NEW_BAIKAL_DIR=""
PHP_FPM_SERVICE=""
INSTALLED="0"
BACKED_UP="0"

fail() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

cleanup() {
	status=$1
	if [ "$status" -ne 0 ] && [ "$BACKED_UP" -eq 1 ]; then
		if [ -d "$BACKUP_BAIKAL_DIR/current" ]; then
			rm -rf "$BAIKAL_DIR"
			mv "$BACKUP_BAIKAL_DIR/current" "$BAIKAL_DIR"
		fi
		start_service || true
	fi

	rm -rf "$WORK_DIR"
	rm -f "$ARCHIVE"
}

backup_app() {
	mkdir -p "$BACKUP_BAIKAL_DIR"
	mv "$BAIKAL_DIR" "$BACKUP_BAIKAL_DIR/current"
	BACKED_UP=1
}

pull_latest_baikal() {
	rm -rf "$WORK_DIR"
	rm -f "$ARCHIVE"
	mkdir -p "$WORK_DIR/extract"

	if command -v curl >/dev/null 2>&1; then
		curl --fail --location --output "$ARCHIVE" "$BAIKAL_URL"
	elif command -v wget >/dev/null 2>&1; then
		wget -O "$ARCHIVE" "$BAIKAL_URL"
	else
		fail 'Neither curl nor wget is installed.'
	fi

	unzip -q "$ARCHIVE" -d "$WORK_DIR/extract"
	NEW_BAIKAL_DIR="$WORK_DIR/extract/baikal"
	[ -d "$NEW_BAIKAL_DIR" ] || fail 'The Baikal archive does not contain the expected baikal directory.'
}

overwrite_srv() {
	[ -d "$BACKUP_BAIKAL_DIR/current/Specific" ] || fail 'The backup does not contain the Baikal Specific directory.'

	# Application code is replaced, while Baikal configuration and runtime data are restored.
	rm -rf "$BAIKAL_DIR/Specific"
	cp -a "$BACKUP_BAIKAL_DIR/current/Specific" "$BAIKAL_DIR/Specific"

	# Preserve explicitly customized top-level configuration files if they exist.
  # damn that config file named baikal.yaml
  if [ -d "$BACKUP_BAIKAL_DIR/current/config" ]; then
    rm -rf "$BAIKAL_DIR/config"
    cp -a "$BACKUP_BAIKAL_DIR/current/config" "$BAIKAL_DIR/config"
  fi
}

stop_service() {
	rc-service nginx stop >/dev/null 2>&1 || true

	set -- /etc/init.d/php-fpm*
	if [ "$#" -eq 1 ] && [ -x "$1" ]; then
		PHP_FPM_SERVICE=${1##*/}
		rc-service "$PHP_FPM_SERVICE" stop >/dev/null 2>&1 || true
	fi
}

start_service() {
	if [ -z "$PHP_FPM_SERVICE" ]; then
		set -- /etc/init.d/php-fpm*
		if [ "$#" -eq 1 ] && [ -x "$1" ]; then
			PHP_FPM_SERVICE=${1##*/}
		fi
	fi

	[ -n "$PHP_FPM_SERVICE" ] || fail 'Could not determine the PHP-FPM service name.'
	rc-service "$PHP_FPM_SERVICE" start
	rc-service nginx start
}

main() {
	[ "$(id -u)" -eq 0 ] || fail 'Please run this script as root.'
	[ -f /etc/alpine-release ] || fail 'This script supports Alpine Linux only.'
	[ -d "$BAIKAL_DIR" ] || fail "$BAIKAL_DIR does not exist."
	[ -d "$BAIKAL_DIR/Specific" ] || fail "$BAIKAL_DIR/Specific does not exist."
	command -v unzip >/dev/null 2>&1 || fail 'unzip is not installed.'

	trap 'status=$?; cleanup "$status"' EXIT

  pull_latest_baikal

	stop_service
	backup_app
	
	mkdir -p "$BAIKAL_DIR"
	cp -a "$NEW_BAIKAL_DIR/." "$BAIKAL_DIR/"
	INSTALLED=1
	overwrite_srv

	chown -R nginx:nginx "$BAIKAL_DIR"
	find "$BAIKAL_DIR" -type d -exec chmod 755 {} +
	find "$BAIKAL_DIR" -type f -exec chmod 644 {} +

	nginx -t
	start_service
	INSTALLED=0

	printf 'Baikal updated to %s. Backup: %s\n' "$BAIKAL_VERSION" "$BACKUP_BAIKAL_DIR"
}

main "$@"