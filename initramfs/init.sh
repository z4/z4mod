#!/sbin/busybox sh
#
# z4mod init wrapper, by Elia Yehuda (c) 2010 GPLv2
#
# Loops over partitions to find jfs/ext2/3/4 and replace mount command in *.rc files.
# It extracts info from the filesystem structure to check for the correct type.
#

# some aliasses to make the code more readable
alias dd="busybox dd"
alias od="busybox od"
alias ls="busybox ls"
alias awk="busybox awk"
alias sed="busybox sed"
alias mknod="busybox mknod"
alias mount="busybox mount"
alias insmod="busybox insmod"

# jfs offset
JFS_MAGIC=0x8000

# ext2/3/4 offsets
RO_COMPAT=0x464
INCOMPAT=0x460
COMPAT=0x45c
EXT_MAGIC=0x438

# ext2/3/4 flags
EXT3_FEATURE_COMPAT_HAS_JOURNAL=4
EXT4_FEATURE_RO_COMPAT_HUGE_FILE=8
EXT4_FEATURE_RO_COMPAT_GDT_CSUM=16
EXT4_FEATURE_RO_COMPAT_DIR_NLINK=32
EXT4_FEATURE_RO_COMPAT_EXTRA_ISIZE=64
EXT4_FEATURE_INCOMPAT_64BIT=128
EXT4_FEATURE_INCOMPAT_MMP=256

# mount options for various filesystem types
EXT2_MOUNT_OPTIONS="nosuid nodev noatime nodiratime errors=continue"
EXT3_MOUNT_OPTIONS="nosuid nodev noatime nodiratime errors=continue data=writeback barrier=0"
EXT4_MOUNT_OPTIONS="nosuid nodev noatime nodiratime errors=continue data=writeback barrier=0 noauto_da_alloc"
JFS_MOUNT_OPTIONS="nosuid nodev noatime nodiratime errors=continue"

set -x
exec >> /z4mod.init.log 2>&1

# we must have proc mounted
mount -t proc none /proc
mount -t sysfs none /sys

# we only create device nodes that we need
mknod /dev/null c 1 3
mknod /dev/block/mmcblk0p1 b 179 1
mknod /dev/block/mmcblk0p2 b 179 2
mknod /dev/block/stl3 b 138 3
mknod /dev/block/stl6 b 138 6
mknod /dev/block/stl8 b 138 8
mknod /dev/block/stl9 b 138 9
mknod /dev/block/stl10 b 138 10
mknod /dev/block/stl11 b 138 11

# loading all the modules, just in case
# FIXME: insmod default modules first - modules must be loaded in a curtain order (manual)
#for module in /lib/modules/*; do
#	insmod $module
#done

# returns filesystem type if found, blank if non
get_partition_type()
{
	part=$1
	# check if this is an ext2/3/4
	#magic="`dd if=$part skip=$((EXT_MAGIC)) bs=1 count=2 2>/dev/null | od -vx`"
	#if [ "${magic:8:4}" == "ef53" ]; then
	magic="`dd if=$part bs=$((EXT_MAGIC)) skip=1 count=1 2>/dev/null | dd bs=2 count=1 2>/dev/null | od -vx | awk '{print $2}'`"
	if [ "$magic" == "ef53" ]; then
		# has journal?
		#compat="`dd if=$part skip=$((COMPAT)) bs=1 count=4 2>/dev/null | od -X`"
		#compat=0x"${compat:8:8}"
		compat=0x"`dd if=$part bs=$((COMPAT)) skip=1 count=1 2>/dev/null | dd bs=4 count=1 2>/dev/null | od -vx | awk '{print $2}'`"
		if [ "$((compat&=EXT3_FEATURE_COMPAT_HAS_JOURNAL))" == "0" ]; then
			# replace rfs with ext2
			echo "ext2"
		else
			# ext3 or ext4
			#ro_compat="`dd if=$part skip=$((RO_COMPAT)) bs=1 count=4 2>/dev/null | od -X`"
			#ro_compat=0x"${ro_compat:8:8}"
			ro_compat=0x"`dd if=$part bs=$((RO_COMPAT)) skip=1 count=1 2>/dev/null | dd bs=1 count=4 2>/dev/null | od -vX | awk '{print $2}'`"
			#incompat="`dd if=$part skip=$((INCOMPAT)) bs=1 count=4 2>/dev/null | od -X`"
			#incompat=0x"${incompat:8:8}"
			incompat=0x"`dd if=$part bs=$((INCOMPAT)) skip=1 count=1 2>/dev/null | dd bs=1 count=4 2>/dev/null | od -vX | awk '{print $2}'`"
			if [ "$((ro_compat&=EXT4_FEATURE_RO_COMPAT_HUGE_FILE))" != "0" -o \
				"$((ro_compat&=EXT4_FEATURE_RO_COMPAT_GDT_CSUM))" != "0" -o \
				"$((ro_compat&=EXT4_FEATURE_RO_COMPAT_DIR_NLINK))" != "0" -o \
				"$((ro_compat&=EXT4_FEATURE_RO_COMPAT_EXTRA_ISIZE))" != "0" -o \
				"$((incompat&=EXT4_FEATURE_INCOMPAT_64BIT))" != "0" -o \
				"$((incompat&=EXT4_FEATURE_INCOMPAT_MMP))" != "0" ]; then
				# replace rfs with ext4
				echo "ext4"
			else
				# replace rfs with ext3
				echo "ext3"
			fi
		fi
	else
		# check if this is a jfs filesystem
		#magic="`dd if=$part skip=$((JFS_MAGIC)) bs=1 count=4 2>/dev/null`"
		#if [ "${magic:0:4}" == "JFS1" ]; then
		magic="`dd if=$part bs=$((JFS_MAGIC)) skip=1 count=1 2>/dev/null | dd bs=4 count=1 2>/dev/null`"
		if [ "$magic" == "JFS1" ]; then
			# replace rfs with jfs
			echo "jfs"
		fi
	fi
}

# loop on known partitions, and set appropriate mount options for each
for part in `ls /dev/block/stl* /dev/block/mmcblk0p*`; do
	case `get_partition_type $part` in
		ext2)	FOUND_NON_RFS="true"
			# replace rfs with ext2
			sed -i 's|mount rfs '"${part}"' \([^ ]*\) .*|mount ext2 '"${part}"' \1 '"${EXT2_MOUNT_OPTIONS}"'|g' /*.rc
			;;
		ext3)	FOUND_NON_RFS="true"
			# replace rfs with ext3
			sed -i 's|mount rfs '"${part}"' \([^ ]*\) .*|mount ext3 '"${part}"' \1 '"${EXT3_MOUNT_OPTIONS}"'|g' /*.rc
			;;
		ext4)	FOUND_NON_RFS="true"
			# replace rfs with ext4
			sed -i 's|mount rfs '"${part}"' \([^ ]*\) .*|mount ext4 '"${part}"' \1 '"${EXT4_MOUNT_OPTIONS}"'|g' /*.rc
			;;
		jfs)	FOUND_NON_RFS="true"
			# replace rfs with jfs
			sed -i 's|mount rfs '"${part}"' \([^ ]*\) .*|mount jfs '"${part}"' \1 '"${JFS_MOUNT_OPTIONS}"'|g' /*.rc
			;;
	esac
done

# check if we need to patch the init binary
if [ "${FOUND_NON_RFS}" == "true" ]; then
	# patch init to ignore non-RFS mmcblk0p2 (and not format it)
	sed -i 's/mmcblk0\x00/\x00mcblk0\x00/g;s/mmcblk0p2\x00/\x00mcblk0p2\x00/g' /sbin/init
fi
# allow a secondary wrapper to be executed
[ -x /z4pre.init.sh ] && /z4pre.init.sh
# execute init
exec /sbin/init

