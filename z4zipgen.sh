#!/bin/bash
#
# z4zipgen.sh, by Elia Yehuda, (c) 2010 GPLv2
#
# patches an updater-script template to match selected options and create an 
# update.zip with selected tools
#

#set -x

usage() 
{
	echo
	echo "z4zipgen.sh [filesystem] [root] [busybox] [-z zImage] [-o output]"
	echo "all parameters are optional:"
	echo
	echo "filesystem = convert filesystem to [ext2/ext3/ext4/jfs/rfs/auto]"
	echo "root       = install root"
	echo "busybox    = install busybox"
	echo "-z zImage  = flash zImage to device"
	echo "-o output  = write final update.zip file to output"
	echo
	exit 1
}

set_data_filesystem()
{
	# copy our z4mod converting script
	cp ${srcdir}/updates/z4mod ${wrkdir}/sbin/z4mod
	sed -i 's/version=.*/version='$version'/g' ${wrkdir}/sbin/z4mod
	# copy busybox to initramfs/sbin for z4mod usage
	cp ${srcdir}/updates/busybox/system/xbin/busybox ${wrkdir}/sbin/busybox
	# set correct filesystem type into the updater-script template
	sed -i 's|run_program("/sbin/z4mod".*|run_program("/sbin/z4mod", "data", "mmcblk0p2", "'$1'");|g' "${script}"
}

get_system_files()
{
	pushd $wrkdir >/dev/null
	for file in `find system/ ! -type d`; do
		echo -e "delete(\"$file\");\\\npackage_extract_file(\"$file\", \"/$file\");\\"
		echo -e "set_perm(0, 0, $(stat -c '%a' $file), \"/$file\");\\"
	done
	popd >/dev/null
}

[ $# == 0 ] && usage

srcdir=`dirname $0`
srcdir=`realpath $srcdir`
wrkdir=`pwd`/z4mod-$$-$RANDOM.tmp
script=${wrkdir}/META-INF/com/google/android/updater-script
mkdir -p ${wrkdir}/{sbin,system/{app,xbin}}
cp -r ${srcdir}/updates/META-INF ${wrkdir}/

filename=z4mod

while [ "$*" ]; do
	if [ "$1" == "root" -o "$1" == "busybox" ]; then
		cp -a ${srcdir}/updates/$1/* ${wrkdir}/
		z4install="true"
		filename="${filename}.$1"
	elif [ "$1" == "-z" ]; then
		shift
		zImage=`realpath $1`
		if [ ! -f $zImage ]; then
			echo "zImage not found: $zImage"
			exit 1
		fi
		filename="${filename}.zImage"
	elif [ "$1" == "-o" ]; then
		shift
		output=$1
	else
		filesystem="$1"
		filename="${filename}.$1"
	fi
	shift
done
if [ -z $output ]; then
	output=`pwd`/${filename}.update.zip
fi
# set version in script
version=`cat ${srcdir}/z4version`


# copy the appropriate tools according to selected filesystem
case "${filesystem}" in
	rfs)
		# patch updater-script to relflect choosen filesystem and copy the z4mod convertor
		set_data_filesystem ${filesystem}
		;;
	jfs)
		# patch updater-script to relflect choosen filesystem and copy the z4mod convertor
		set_data_filesystem ${filesystem}
		# copy required tools
		cp -r ${srcdir}/updates/jfsutils/* ${wrkdir}/
		;;
	ext2|ext3|ext4)
		# patch updater-script to relflect choosen filesystem and copy the z4mod convertor
		set_data_filesystem ${filesystem}
		# copy required tools
		cp -r ${srcdir}/updates/e2fsprogs/* ${wrkdir}/
		;;
	auto)
		# patch updater-script to relflect choosen filesystem and copy the z4mod convertor
		set_data_filesystem ${filesystem}
		# copy required tools
		cp -r ${srcdir}/updates/jfsutils/* ${wrkdir}/
		cp -r ${srcdir}/updates/e2fsprogs/* ${wrkdir}/
		cp ${srcdir}/updates/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.ext3
		cp ${srcdir}/updates/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.ext3
		cp ${srcdir}/updates/e2fsprogs/system/xbin/mkfs.ext2 ${wrkdir}/system/xbin/mkfs.ext4
		cp ${srcdir}/updates/e2fsprogs/system/xbin/fsck.ext2 ${wrkdir}/system/xbin/fsck.ext4
		;;
	*)
		# remove the z4mod convert section from updater-script
		sed -i '/# START: z4mod/,/# END: z4mod/d' "${script}"
		;;
esac

#if [ -z ${z4install} ]; then
#	# remove the install section from updater-script
#	sed -i '/# START: Install/,/# END: Install/d' "${script}"
#fi
if [ -z ${zImage} ]; then
	# remove the kernel-flash section from updater-script
	sed -i '/# START: Kernel/,/# END: Kernel/d' "${script}"
else
	cp ${srcdir}/updates/redbend_ua ${wrkdir}/redbend_ua
	cp $zImage $wrkdir/zImage
	zImagefiles="zImage redbend_ua"
fi

# FIXME: package_extract_dir does not work with CWM recovery
sed -i 's|package_extract_dir("system", "/system");|'"`get_system_files`"\n'|g' ${script}

# set version in script
sed -i 's/Version .*/Version '$version'\");/g' ${script}

# create the update.zip file
(cd ${wrkdir}; zip -r $output META-INF/ sbin/ system/ $zImagefiles)
# cleanup
rm -rf ${wrkdir}

echo
echo File is ready: 
ls -lh $output
echo
