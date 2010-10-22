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
	echo "filesystem = convert filesystem to ext2/ext3/ext4/rfs/auto"
	echo "root       = install root"
	echo "busybox    = install busybox"
	exit 1
}

set_data_filesystem()
{
	cp ${masterdir}/z4mod ${wrkdir}/sbin/z4mod
	cp ${masterdir}/opt/busybox/system/xbin/busybox ${wrkdir}/sbin/busybox
	sed -i 's|run_program("sbin/z4mod".*|run_program("sbin/z4mod", "data", "mmcblk0p2", "'$1'");|g' "${script}"
}


[ $# == 0 ] && usage
[ $# -gt 3 ] && usage

wrkdir=`pwd`/tmp.1
rm -r $wrkdir
mkdir -p ${wrkdir}/{sbin,system/{app,xbin}}
masterdir=`dirname $0`
cp -r ${masterdir}/META-INF ${wrkdir}/
script=${wrkdir}/META-INF/com/google/android/updater-script

filename=z4mod
zinstall="false"

while [ "$*" ]; do
	filename="${filename}.$1"
	if [ "$1" == "root" -o "$1" == "busybox" ]; then
		cp -r ${masterdir}/opt/$1/* ${wrkdir}/
		zinstall="true"
	else
		filesystem="$1"
	fi
	shift
done

if [ "${filesystem}" == "rfs" ]; then
	sed -i 's|run_program("sbin/z4mod".*|run_program("sbin/z4mod", "data", "mmcblk0p2", "rfs");|g' "${script}"
elif [ "${filesystem}" == "ext2" -o "${filesystem}" == "ext3" -o "${filesystem}" == "ext4" ]; then
	set_data_filesystem ${filesystem}
	cp ${masterdir}/opt/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.${filesystem}
	cp ${masterdir}/opt/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.${filesystem}
elif [ "${filesystem}" == "auto" ]; then
	set_data_filesystem ${filesystem}
	cp ${masterdir}/opt/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.ext2
	cp ${masterdir}/opt/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.ext2
	cp ${masterdir}/opt/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.ext3
	cp ${masterdir}/opt/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.ext3
	cp ${masterdir}/opt/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.ext4
	cp ${masterdir}/opt/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.ext4
else
	# remove the z4mod convert section from updater-script
	sed -i '/# START: z4mod/,/# END: z4mod/d' "${script}"
fi

if [ ${zinstall} == "false" ]; then
	# remove the install section from updater-script
	sed -i '/# START: Install/,/# END: Install/d' "${script}"
fi

(cd ${wrkdir}; zip -r ${filename}.update.zip META-INF/ sbin/ system/)
