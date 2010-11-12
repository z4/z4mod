#!/system/bin/sh

# make sure the recovery script will start our new recovery binary
busybox sed -i 's|^service recovery.*|service recovery /sbin/recovery|g' /recovery.rc
busybox sed -i 's|#mount rfs /dev/block/stl11 /cache|mount rfs /dev/block/stl11 /cache|g' /recovery.rc

