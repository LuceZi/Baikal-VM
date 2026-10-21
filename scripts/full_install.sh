#!/bin/sh

set -eu

BAIKAL_VERSION="${BAIKAL_VERSION:-0.13.0}"
BAIKAL_URL="https://github.com/sabre-io/Baikal/releases/download/${BAIKAL_VERSION}/baikal-${BAIKAL_VERSION}.zip"
BAIKAL_DIR="/var/www/baikal"
ARCHIVE="/tmp/baikal-${BAIKAL_VERSION}.zip"
BAIKAL_HOSTNAME="${BAIKAL_HOSTNAME:-baikal}"

fail() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

[ "$(id -u)" -eq 0 ] || fail 'Please run this script as root.'
[ -f /etc/alpine-release ] || fail 'This script supports Alpine Linux only.'
[ ! -e "$BAIKAL_DIR" ] || fail "$BAIKAL_DIR already exists; stopping to avoid overwriting existing data."

if [ ! -f /etc/apk/repositories ]; then
	fail 'Could not find /etc/apk/repositories.'
fi

sed -i '/community/s/^#//' /etc/apk/repositories
apk update

apk add nginx php php-fpm php-pdo_sqlite php-mbstring php-xml php-xmlreader php-xmlwriter php-dom php-fileinfo php-openssl php-ctype php-simplexml php-iconv\
    php-curl php-session unzip wget curl \
    qemu-guest-agent qemu-guest-agent-openrc \
	avahi avahi-openrc dbus dbus-openrc

set -- /etc/init.d/php-fpm*
[ "$#" -eq 1 ] && [ -x "$1" ] || fail 'Could not determine the PHP-FPM service name.'
PHP_FPM_SERVICE=${1##*/}
PHP_FPM_CONFIG=$(find /etc -path '/etc/php*/php-fpm.d/www.conf' -type f -print -quit)
[ -n "$PHP_FPM_CONFIG" ] || fail 'Could not find the PHP-FPM www.conf configuration file.'

mkdir -p /var/www
wget -O "$ARCHIVE" "$BAIKAL_URL"
unzip -q "$ARCHIVE" -d /var/www/
rm -f "$ARCHIVE"
set -- /var/www/baikal*
[ "$#" -eq 1 ] && [ -d "$1" ] || fail 'The Baikal archive does not contain the expected installation directory.'

if [ "$1" != "$BAIKAL_DIR" ]; then
    mv "$1" "$BAIKAL_DIR"
fi

rm -f /etc/nginx/http.d/default.conf
cat > /etc/nginx/http.d/baikal.conf <<'NGINX_CONF'
server {
  listen       80;
  server_name  localhost;

  root  /var/www/baikal/html;
  index index.php;

  rewrite ^/.well-known/caldav /dav.php redirect;
  rewrite ^/.well-known/carddav /dav.php redirect;

  charset utf-8;

  location ~ /(\.ht|Core|Specific|config) {
    deny all;
    return 404;
  }

  location ~ ^(.+\.php)(.*)$ {
    try_files $fastcgi_script_name =404;

    include fastcgi_params;
    fastcgi_split_path_info ^(.+\.php)(.*)$;

    fastcgi_pass 127.0.0.1:9000;

    fastcgi_param SCRIPT_FILENAME
                    $document_root$fastcgi_script_name;
    fastcgi_param PATH_INFO $fastcgi_path_info;

    fastcgi_param HTTP_AUTHORIZATION $http_authorization;
  }
}
NGINX_CONF

sed -i 's/^[[:space:]]*user[[:space:]]*=.*/user = nginx/' "$PHP_FPM_CONFIG"
sed -i 's/^[[:space:]]*group[[:space:]]*=.*/group = nginx/' "$PHP_FPM_CONFIG"

chown -R nginx:nginx "$BAIKAL_DIR"
find "$BAIKAL_DIR" -type d -exec chmod 755 {} +
find "$BAIKAL_DIR" -type f -exec chmod 644 {} +

nginx -t
rc-update add "$PHP_FPM_SERVICE" default
rc-update add nginx default
rc-service "$PHP_FPM_SERVICE" restart
rc-service nginx restart

printf '%s\n' "$BAIKAL_HOSTNAME" > /etc/hostname
hostname "$BAIKAL_HOSTNAME"

rc-update add qemu-guest-agent default
#rc-service qemu-guest-agent start	#unnecessary

rc-update add dbus default
rc-service dbus start
rc-update add avahi-daemon default
rc-service avahi-daemon start

cat > /usr/local/bin/baikal-welcome <<'WELCOME_SCRIPT'
#!/bin/sh
clear
echo "=================================================="
echo "  Ba  kal CalDAV/CardDAV Appliance for Proxmox VE"
echo "=================================================="
echo ""

IP=$(ip -o -4 addr show dev eth0 scope global |
    awk 'NR == 1 { split($4, a, "/"); print a[1] }')
HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname)

if [ -n "$IP" ]; then
    echo "  -> Web Setup UI : http://$IP/"
    echo "  -> mDNS Access  : http://$HOSTNAME.local/ (if Avahi enabled)"
else
    echo "  -> Network is waiting for DHCP..."
fi

echo ""
echo "=================================================="
WELCOME_SCRIPT
chmod 755 /usr/local/bin/baikal-welcome

mkdir -p /etc/profile.d
cat > /etc/profile.d/baikal-welcome.sh <<'PROFILE_SCRIPT'
case $- in
	*i*) /usr/local/bin/baikal-welcome ;;
esac
PROFILE_SCRIPT

printf '\nBaikal installation is complete. Visit http://%s.local/ or the VM IP to finish the initial setup.\n' "$BAIKAL_HOSTNAME"
printf 'For QEMU Guest Agent support, enable the agent in the VM settings in Proxmox VE.\n'