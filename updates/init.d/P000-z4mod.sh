#!/system/bin/sh
#
# /etc/init.d/P000-z4mod.sh

PATH=/sbin:/system/xbin:/system/bin:$PATH

mkdir /sdcard
busybox mount -t vfat /dev/block/mmcblk0p1 /sdcard
set -x
exec >> /sdcard/z4P000.log 2>&1

busybox cp `busybox which busybox` /z4mod/bin/busybox
busybox --install -s /z4mod/bin
busybox cp /system/xbin/mkfs.ext2 /z4mod/bin/mkfs.ext2
busybox cp /system/xbin/tune2fs /z4mod/bin/tune2fs
mkdir /dev/graphics
busybox mknod /dev/graphics/fb0 c 29 0
busybox mknod /dev/zero c 1 5
#cat /system/convertsplash | busybox gunzip -c > /dev/graphics/fb0
busybox sh /system/xbin/z4mod data mmcblk0p2 ext2

# self-destruction
busybox mount -o remount,rw,check=no,llw /system
busybox rm -f `busybox realpath $0`
busybox rm -f /system/convertsplash
busybox mount -o remount,ro /system

sync; sync
busybox umount /sdcard
/system/bin/toolbox reboot
