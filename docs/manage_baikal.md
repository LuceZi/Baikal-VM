# Baikal 安裝與管理

以下指令在 Alpine Linux VM 內以 root 執行。一般建置建議使用 `scripts/full_install.sh`；本指南提供 SSH 設定及手動安裝參考。若要從主機測試連線埠轉送，請參閱[從頭建置 Baikal 映像](create_vm.md)。

## 設定 SSH

```sh
apk add openssh

# 僅建議在隔離的測試環境允許 root 使用密碼登入。
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
passwd

rc-update add sshd default
rc-service sshd start
```

請在 `passwd` 提示時自行設定密碼，不要將密碼寫入文件。若 VM 已設定 QEMU 的 `2222` 連接埠轉送，可從主機連線：

```sh
ssh -p 2222 root@127.0.0.1
```

## 安裝 Nginx 與 PHP

啟用 Alpine 的 community 套件庫並安裝 Baikal 所需元件：

```sh
sed -i '/community/s/^#//g' /etc/apk/repositories
apk update
apk add nginx php php-fpm php-pdo_sqlite php-mbstring php-xml php-xmlreader php-xmlwriter php-dom php-fileinfo php-openssl php-ctype php-simplexml php-iconv \
    php-curl php-session unzip wget curl \
    qemu-guest-agent qemu-guest-agent-openrc \
    avahi avahi-openrc dbus dbus-openrc
```

PHP-FPM 的服務名稱與設定目錄會隨 Alpine 套件版本改變。以下步驟會從系統中找出已安裝的服務與設定檔，不要將範例中的 PHP 版本目錄寫死。

## 下載並安裝 Baikal

此處使用 Baikal 0.13.0：

```sh
mkdir -p /var/www
wget https://github.com/sabre-io/Baikal/releases/download/0.13.0/baikal-0.13.0.zip -O /tmp/baikal.zip
unzip /tmp/baikal.zip -d /var/www/
mv /var/www/baikal-* /var/www/baikal
rm /tmp/baikal.zip
```

## 設定 Nginx

建立 `/etc/nginx/http.d/baikal.conf`：

```nginx
server {
    listen 80;
    server_name localhost;

    root /var/www/baikal/html;
    index index.php;

    charset utf-8;

    # CalDAV / CardDAV discovery
    rewrite ^/.well-known/caldav /dav.php redirect;
    rewrite ^/.well-known/carddav /dav.php redirect;

    # Protect sensitive files and directories
    location ~ /(\.ht|Core|Specific|config|vendor) {
        deny all;
        return 404;
    }

    # PHP-FPM
    location ~ ^(.+\.php)(.*)$ {
        try_files $fastcgi_script_name =404;

        include fastcgi_params;
        fastcgi_split_path_info ^(.+\.php)(.*)$;

        fastcgi_pass 127.0.0.1:9000;    #alpine php-fpm.sock

        fastcgi_param SCRIPT_FILENAME
                     $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;

        fastcgi_param HTTP_AUTHORIZATION $http_authorization;
    }
}

```

## 設定 PHP-FPM 與檔案權限

```sh
PHP_FPM_CONFIG=$(find /etc -path '/etc/php*/php-fpm.d/www.conf' -type f -print -quit)
[ -n "$PHP_FPM_CONFIG" ] || { echo '找不到 PHP-FPM 設定檔' >&2; exit 1; }
sed -i 's/^[[:space:]]*user[[:space:]]*=.*/user = nginx/' "$PHP_FPM_CONFIG"
sed -i 's/^[[:space:]]*group[[:space:]]*=.*/group = nginx/' "$PHP_FPM_CONFIG"

chown -R nginx:nginx /var/www/baikal
find /var/www/baikal -type d -exec chmod 755 {} +
find /var/www/baikal -type f -exec chmod 644 {} +
```

## 設定開機啟動並啟動服務

```sh
rc-update add nginx default
set -- /etc/init.d/php-fpm*
[ "$#" -eq 1 ] && [ -x "$1" ] || { echo '無法唯一判斷 PHP-FPM 服務' >&2; exit 1; }
PHP_FPM_SERVICE=${1##*/}
rc-update add "$PHP_FPM_SERVICE" default

rc-service "$PHP_FPM_SERVICE" restart
rc-service nginx restart

rc-update add qemu-guest-agent default
rc-update add dbus default
rc-update add avahi-daemon default
rc-service dbus start
rc-service avahi-daemon start
```

完成後，使用 VM 的 IP 位址開啟 Baikal；若 QEMU 設定了 `8080` 連接埠轉送，可在主機瀏覽 `http://127.0.0.1:8080/`。修改 Nginx 或 PHP-FPM 設定後，請重新啟動對應服務。
