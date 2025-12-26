Before converting a Proxmox VM into a **template**, you should **clean up** unnecessary data and prepare the VM to ensure it deploys correctly. Here’s a checklist of **cleanup steps** to follow:

---

## **🔧 1. Remove Machine-Specific Data**

These steps prevent conflicts when deploying new VMs from the template.

### **Remove SSH Host Keys (Optional, for security)**

```bash
rm -f /etc/ssh/ssh_host_*
```

New SSH keys will be generated when a VM is created from the template.

---

## **🗑️ 2. Clear System Logs**

```bash
journalctl --rotate
journalctl --vacuum-time=1s
rm -rf /var/log/*.log
rm -rf /var/log/journal/*
```

This removes unnecessary logs and reclaims disk space.

---

## **📂 3. Remove Bash History**

```bash
unset HISTFILE
rm -f ~/.bash_history
```

Prevents command history from persisting in new VMs.

---

## **🛑 4. Remove Persistent Network Rules**

Remove old network configurations to prevent duplicate MAC addresses.

```bash
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -rf /var/lib/systemd/random-seed
```

New VMs will generate their own network configuration.

---

## **📦 5. Clean Package Cache**

For **Debian/Ubuntu-based** VMs:

```bash
apt clean
apt autoremove -y
```

For **RHEL-based (CentOS, Rocky, AlmaLinux)**:

```bash
dnf clean all
```

---

## **🔄 6. Remove Cloud-Init Data (If Installed)**

If you use **Cloud-Init**, reset its data:

```bash
cloud-init clean --logs
```

This ensures a fresh instance when a VM is created.

---

## **🖥️ 7. Zero Out Unused Disk Space (Optional, Reduces Template Size)**

```bash
cat /dev/zero > /zero.fill; sync; rm -f /zero.fill
```

This fills empty space with zeros, improving template compression.

---

## **🚀 8. Shut Down the VM**

```bash
poweroff
```

After shutting down, convert the VM to a template in **Proxmox Web UI** or run:

```bash
qm template <VMID>
```

---

### **✅ Done!**

Your VM is now **cleaned up and optimized** for use as a Proxmox template! 🚀
