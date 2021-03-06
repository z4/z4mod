#!/system/bin/sh

# install Superuser.apk
if [ ! -f /system/xbin/busybox ]; then
	busybox mount -o remount,rw,llw,check=no /system || busybox mount -o remount,rw /system
	busybox cp -a /sbin/busybox /system/xbin/busybox
	busybox --install -s /system/xbin/
	busybox mount -o remount,ro /system
fi
