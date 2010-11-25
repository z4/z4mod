#!/system/bin/sh
#
# /etc/init.d/P000-z4mod.sh

PATH=/sbin:/system/xbin:/system/bin:$PATH

busybox cp `busybox which busybox` /z4mod/bin/busybox
busybox cp -p /system/xbin/mkfs.ext2 /z4mod/bin/mkfs.ext2
busybox --install -s /z4mod/bin
mkdir /dev/graphics
busybox mknod /dev/graphics/fb0 c 29 0
busybox mknod /dev/zero c 1 5
cat /system/convertsplash | busybox gunzip -c > /dev/graphics/fb0
busybox sh /system/xbin/z4mod data mmcblk0p2 ext2
busybox mount -o remount,rw /system
#busybox rm -f `busybox realpath $0`
busybox rm -f /system/etc/init.d/P000-z4mod.sh
busybox rm -f /system/xbin/z4mod

busybox rm -f /system/convertsplash
busybox mount -o remount,ro /system
sync; sync
/system/bin/toolbox reboot
