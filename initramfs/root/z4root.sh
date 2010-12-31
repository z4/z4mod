#!/system/bin/sh

chown root.root /sbin/su
chmod 6755 /sbin/su
# install Superuser.apk
if [ ! -f /system/app/Superuser.apk ]; then
	busybox mount -o remount,rw,llw,check=no /system || busybox mount -o remount,rw /system
	cat /res/Superuser.apk > /system/app/Superuser.apk
	cat /sbin/su > /system/xbin/su
	chmod 6755 /system/xbin/su
	busybox mount -o remount,ro /system
fi
