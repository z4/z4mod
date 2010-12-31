#!/system/bin/sh

# make sure the recovery script will start our new recovery binary
busybox sed -i 's|^service recovery.*|service recovery /sbin/recovery|g' /recovery.rc
busybox sed -i 's|#mount rfs /dev/block/stl11 /cache|mount rfs /dev/block/stl11 /cache|g' /recovery.rc

if [ ! -z "`busybox grep 'bootmode=2' /proc/cmdline`" ]; then
	mkdir /sdcard
	mkdir -p /mnt/sdcard
	mkdir /sd-ext
	mkdir -p /mnt/sdcard/external_sd
fi
