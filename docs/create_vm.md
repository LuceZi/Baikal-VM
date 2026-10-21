# 從頭建置 Baikal 映像

本指南會在 Linux 主機使用 QEMU/KVM 建立 Alpine VM、安裝 Baikal，並產生可發布的 QCOW2 映像。請先安裝 QEMU/KVM，並確認目前使用者有 KVM 權限。以下以 `~/baikal-appliance` 為專案目錄，且專案的 `scripts/` 位於該目錄下。

## 建立工作目錄與虛擬磁碟

```sh
mkdir -p ~/baikal-appliance/workspace
cd ~/baikal-appliance/workspace

qemu-img create -f qcow2 baikal-base.qcow2 2G
```

## 下載 Alpine 安裝映像

此範例使用 Alpine Linux 3.24.2 x86_64 virt 安裝映像：

```sh
wget https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-virt-3.24.2-x86_64.iso -O alpine.iso
```

## 啟動安裝程式

```sh
qemu-system-x86_64 \
  -enable-kvm \
  -m 1024 \
  -smp 2 \
  -drive file=baikal-base.qcow2,format=qcow2,if=virtio \
  -cdrom alpine.iso \
  -boot d \
  -net nic,model=virtio \
  -net user
```

在 Alpine 安裝環境中執行：

```sh
setup-alpine
```

依照提示完成安裝。安裝完成後關閉虛擬機，接著用硬碟啟動，不再掛載安裝 ISO。

## 啟動 VM、掛載 scripts 與連接埠轉送

以下命令請在 `~/baikal-appliance/workspace` 執行。QEMU 的共享目錄使用相對路徑 `../scripts`，因此會分享主機上的 `~/baikal-appliance/scripts`；VM 內則會掛載到 `/mnt/shared`。

```sh
qemu-system-x86_64 \
  -enable-kvm \
  -m 1024 \
  -smp 2 \
  -drive file=baikal-base.qcow2,format=qcow2,if=virtio \
  -net nic,model=virtio \
  -net user,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:8080-:80 \
  -virtfs local,path=../scripts,mount_tag=hostshare,security_model=none,id=hostshare
```

在 Alpine VM 內以 root 建立掛載點並掛載共享目錄，接著執行安裝腳本：

```sh
mkdir -p /mnt/shared
mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt/shared
sh /mnt/shared/full_install.sh
```

主機上的 `127.0.0.1:8080` 會轉送到 VM 的 HTTP `80`，可開啟 `http://127.0.0.1:8080/` 測試 Baikal。SSH 的 `127.0.0.1:2222` 會轉送到 VM 的 `22`；安裝腳本不會安裝或啟用 SSH，若要使用，請參閱[安裝與管理 Baikal](manage_baikal.md)。這兩個轉送只監聽主機的 loopback 介面，不會直接對外網路開放。

## 清理並產生映像

完成安裝與測試後，在 Alpine VM 內執行清理腳本。此步驟會清除暫存檔和日誌、填滿可用磁碟空間，然後關閉 VM；不要在日常使用的 VM 執行。

```sh
sh /mnt/shared/clean.sh
```

VM 關閉後，在主機的 `~/baikal-appliance/workspace` 目錄執行映像轉檔。輸出檔會放在專案根目錄：

```sh
qemu-img convert -O qcow2 -c baikal-base.qcow2 ./baikal-appliance-v0.13.0.qcow2
ls -lh ./baikal-appliance-v0.13.0.qcow2
```

需要 gzip 壓縮以供下載時，可再執行：

```sh
gzip -k ./baikal-appliance-v0.13.0.qcow2
ls -lh ./baikal-appliance-v0.13.0.qcow2.gz
```
