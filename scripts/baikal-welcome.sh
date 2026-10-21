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