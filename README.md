# lvm-mount-umount
This is to automate mount and un mounting lvm disk

Background:
I have disk replication from prod to dev environment,
disk is using lvm with different vgname, need test on dev if the disk can be mounted and used.
At the end, need to revert back to dev's original disk.

The script can't have argument(s) because the provising engine didn't support it.
Config like hostname, vgname-lvname, fstab option need to be configured inside the script.
