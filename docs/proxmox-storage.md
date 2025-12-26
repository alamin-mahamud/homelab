# Increase Storage

As Root User

```sh
lsblk
PARTITION_NUMBER=<partition_number> # let's say it's sda3 so the partition number is 3
growpart /dev/sda $PARTITION_NUMBER # growpart /dev/sda 3
pvresize /dev/sda$PARTITION_NUMBER # pvresize /dev/sda3
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
resize2fs /dev/ubuntu-vg/ubuntu-lv
```
