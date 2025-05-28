#!/bin/bash

set -e

echo "[+] Cleaning SSH host keys..."
rm -f /etc/ssh/ssh_host_*

echo "[+] Clearing bash history..."
unset HISTFILE
rm -f /root/.bash_history
history -c

echo "[+] Clearing logs..."
journalctl --rotate
journalctl --vacuum-time=1s
rm -rf /var/log/*

echo "[+] Removing persistent net rules..."
rm -f /etc/udev/rules.d/70-persistent-net.rules

echo "[+] Cleaning cloud-init (if installed)..."
if command -v cloud-init &>/dev/null; then
    cloud-init clean --logs
fi

echo "[+] Cleaning package cache..."
if [ -x "$(command -v apt)" ]; then
    apt clean
    apt autoremove -y
elif [ -x "$(command -v yum)" ]; then
    yum clean all
fi

echo "[+] Resetting machine-id..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

echo "[+] Resetting hostname..."
hostnamectl set-hostname localhost

echo "[+] Zero-filling free space to shrink disk..."
dd if=/dev/zero of=/zerofile bs=1M || true
rm -f /zerofile

echo "[+] Done! Please shutdown the VM and convert it to template."
