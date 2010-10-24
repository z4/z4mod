#!/bin/bash
#
# z4update.zip.sh, by Elia Yehuda, (c) 2010 GPLv2
#
# patches an updater-script template to match selected options and create an 
# update.zip with selected tools
#

#set -x

usage() 
{
	echo "z4update.zip.sh <filesystem> <root> <busybox>"
	echo "all parameters are optional:"
	echo "filesystem = convert filesystem to ext2/ext3/ext4/jfs/rfs/auto"
	echo "root       = install root"
	echo "busybox    = install busybox"
	exit 1
}

set_data_filesystem()
{
	cp ${srcdir}/z4mod ${wrkdir}/sbin/z4mod
	cp ${srcdir}/opt/busybox/system/xbin/busybox ${wrkdir}/sbin/busybox
	sed -i 's|run_program("sbin/z4mod".*|run_program("sbin/z4mod", "data", "mmcblk0p2", "'$1'");|g' "${script}"
}


[ $# == 0 ] && usage
[ $# -gt 3 ] && usage

srcdir=`dirname $0`
wrkdir=`pwd`/tmp/z4mod-$$-$RANDOM
script=${wrkdir}/META-INF/com/google/android/updater-script
mkdir -p ${wrkdir}/{sbin,system/{app,xbin}}
cp -r ${srcdir}/META-INF ${wrkdir}/

filename=z4mod
z4install="false"

while [ "$*" ]; do
	filename="${filename}.$1"
	if [ "$1" == "root" -o "$1" == "busybox" ]; then
		cp -r ${srcdir}/opt/$1/* ${wrkdir}/
		z4install="true"
	else
		filesystem="$1"
	fi
	shift
done

if [ "${filesystem}" == "rfs" ]; then
	sed -i 's|run_program("sbin/z4mod".*|run_program("sbin/z4mod", "data", "mmcblk0p2", "rfs");|g' "${script}"
elif [ "${filesystem}" == "jfs" ]; then
	set_data_filesystem ${filesystem}
	cp ${srcdir}/opt/jfsutils/system/xbin/mkfs.jfs ${wrkdir}/system/xbin/mkfs.${filesystem}
	cp ${srcdir}/opt/jfsutils/system/xbin/fsck.jfs ${wrkdir}/system/xbin/fsck.${filesystem}
elif [ "${filesystem}" == "ext2" -o "${filesystem}" == "ext3" -o "${filesystem}" == "ext4" ]; then
	set_data_filesystem ${filesystem}
	cp ${srcdir}/opt/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.${filesystem}
	cp ${srcdir}/opt/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.${filesystem}
	cp -r ${srcdir}/opt/e2fsprogs/system/etc ${wrkdir}/system/
elif [ "${filesystem}" == "auto" ]; then
	set_data_filesystem ${filesystem}
	cp ${srcdir}/opt/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.ext2
	cp ${srcdir}/opt/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.ext2
	cp ${srcdir}/opt/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.ext3
	cp ${srcdir}/opt/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.ext3
	cp ${srcdir}/opt/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.ext4
	cp ${srcdir}/opt/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.ext4
	cp -r ${srcdir}/opt/e2fsprogs/system/etc ${wrkdir}/system/
else
	# remove the z4mod convert section from updater-script
	sed -i '/# START: z4mod/,/# END: z4mod/d' "${script}"
fi

if [ ${z4install} == "false" ]; then
	# remove the install section from updater-script
	sed -i '/# START: Install/,/# END: Install/d' "${script}"
fi

(cd ${wrkdir}; zip -r ${filename}.update.zip META-INF/ sbin/ system/)
rm -rf ${wrkdir}
