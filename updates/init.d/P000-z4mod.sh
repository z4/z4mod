#!/system/bin/sh
#
# /etc/init.d/P000-z4mod.sh

/system/xbin/busybox sh /system/xbin/z4mod data mmcblk0p2 ext2
busybox mount -o remount,rw /system
busybox rm -f `busybox realpath $0`
busybox mount -o remount,ro /system

