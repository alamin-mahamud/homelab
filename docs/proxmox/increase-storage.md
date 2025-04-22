# Increase Storage

As Root User

```sh
lsblk
PARTITION_NUMBER=<partition_number>
growpart /dev/sda $PARTITION_NUMBER
pvresize /dev/sda/$PARTITION_NUMBER
lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
resize2fs /dev/ubuntu-vg/ubuntu-lv
```
