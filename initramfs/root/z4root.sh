#!/system/bin/sh

# install Superuser.apk
if [ ! -f /system/app/Superuser.apk ]; then
	busybox mount -o remount,rw /system
	busybox cp /res/Superuser.apk /system/app/Superuser.apk
	busybox cp -a /sbin/su /system/xbin/su
	chmod 6755 /system/xbin/su
	busybox mount -o remount,ro /system
fi
