#!/bin/bash
###############################################################################
#
# z4build by Elia Yehuda, aka z4ziggy, (c) 2010
# part of the z4mod project - a ROM mod without RFS.
#
# extracts initramfs from a given zImage, patch it to allow non-RFS mounts,
# and repack it.
#
# Released under the GPLv2
#
# many thanks goto various coders & Android hackers out there who made this
# possible: supercurio, Unhelpful, dkcldark, RyanZA, XDA & modaco forums.
#
# WARNING:
# FOR YOUR OWN SAFETY, IF YOU CAN'T FOLLOW THE SCRIPT, AVOID USING IT.
# USE AT YOUR OWN RISK! NO WARRANTIES WHAT SO EVER!
#
# zImage extraction script copied from here:
# http://forum.xda-developers.com/wiki/index.php?title=Extract_initramfs_from_zImage
#
# kernel_repacker taken from here:
# http://forum.xda-developers.com/showthread.php?t=789712
#
###############################################################################
#set -x

###############################################################################
#
# general functions
#
###############################################################################

C_H1="\033[1;37m"        # highlight text 1
C_ERR="\033[1;31m"
C_CLEAR="\033[1;0m"

# helper functions:

printhl() {
	printf "${C_H1}${1}${C_CLEAR} \n"
}

printerr() {
	printf "${C_ERR}${1}${C_CLEAR} \n"
}

exit_error() {
	printerr "$1"
	rm -rf ${wrkdir}
	exit 1
}

exit_usage() {
	printhl "\nUsage:"
	echo    "  z4build <zImage> [recovery] [root] [busybox] [-t <file.tar>]"
	printhl "\nWhere:"
	echo    "zImage      = the zImage file (kernel) you wish to patch"
	#echo    "z4mod       = [optional] install z4mod wrapper for ext2/3/4"
	echo    "recovery    = [optional] install recovery into initramfs"
	echo    "root        = [optional] install root into initramfs"
	echo    "busybox     = [optional] install busybox into initramfs"
	echo    "-t file.tar = [optional] extract file.tar over initramfs"
	echo
	exit 1
}

###############################################################################
#
# checking parameters and initalize stuff
#
###############################################################################

# Making sure we have everything
zImage=`realpath $1`
shift
if [ -z $zImage ] || [ ! -f $zImage ]; then
	printerr "[E] Can't find kernel: $zImage"
	exit_usage
fi

# not needed anymore?
#if [ $# -eq 0 -o $# -gt 3 ]; then
#	printerr "[E] Wrong parameters"
#	exit_usage
#fi

while [ "$*" ]; do
	if [ "$1" == "-t" ]; then
		shift
		rootfile=`realpath $1`
		if [ ! -f "${rootfile}" ]; then
			exit_error "[E] Can't find user supplied rootfile"
		fi
	else
		eval do_${1}="true"
	fi
        shift
done

# FIXME: For now we make sure we use recovery
do_recovery="true"

printhl "\n[I] z4build ${version} begins, adding non-RFS support to `basename $zImage`"

# We can start working
wrkdir=`pwd`/z4mod-$$-$RANDOM.tmp
srcdir=`dirname $0`
srcdir=`realpath $srcdir`
KERNEL_REPACKER=$srcdir/repacker/kernel_repacker.sh
version=`cat ${srcdir}/z4version`
mkdir -p ${wrkdir}/initramfs/{sbin,cache,sdcard}
mkdir -p ${wrkdir}/initramfs/dev/block

###############################################################################
#
# extract the initramfs.img from zImage
#
###############################################################################

# find start of gziped kernel object in the zImage file:
pos=`grep -F -a -b -m 1 --only-matching $'\x1F\x8B\x08' $zImage | cut -f 1 -d :`
printhl "[I] Extracting kernel image from $zImage (start = $pos)"
dd if=$zImage bs=$pos skip=1 | gunzip > ${wrkdir}/kernel.img

#=======================================================
# Determine if the cpio inside the zImage is gzipped
#=======================================================
cpio_found="FALSE"
gzip_start_arr=`grep -F -a -b --only-matching $'\x1F\x8B\x08' ${wrkdir}/kernel.img`
for possible_gzip_start in $gzip_start_arr; do
	possible_gzip_start=`echo $possible_gzip_start | cut -f 1 -d :`
	dd if=${wrkdir}/kernel.img bs=$possible_gzip_start skip=1 | gunzip > ${wrkdir}/cpio.img
	if [ $? -ne 1 ]; then
		printhl "[I] gzipped archive detected"
		cpio_found="TRUE"
		printhl "[I] Using gzipped archive as cpio"
		mv ${wrkdir}/cpio.img ${wrkdir}/initramfs.img
		break
	fi
done

#===========================================================================
# If the cpio was not gzipped, we need to find the start
# find start of the "cpio" initramfs image inside the kernel object:
# ASCII cpio header starts with '070701'
#===========================================================================
if [ "$cpio_found" == "FALSE" ]; then
	printhl "[I] Finding non gzipped cpio start position"
	start=`grep -F -a -b -m 1 --only-matching '070701' ${wrkdir}/kernel.img | head -1 | cut -f 1 -d :`

	if [ "$start" == "" ]; then
		exit_error "[E] Could not detect a CPIO Archive!"
	fi
	
	printhl "[I] Extracting initramfs image from kernel (start = $start)"
	dd if=${wrkdir}/kernel.img bs=$start skip=1 > ${wrkdir}/initramfs.img
fi

###############################################################################
#
# extract initramfs.img, patch the binary init, patch the scripts and add 
# additional mounts
#
###############################################################################

printhl "[I] Extracting initramfs compressed image"
(cd ${wrkdir}/initramfs/; cpio -i --no-absolute-filenames < ${wrkdir}/initramfs.img)

# check if this kernel is patched already with z4build
if [ -f ${wrkdir}/initramfs/z4version ] || [ `cmp -s ${srcdir}/initramfs/init.sh ${wrkdir}/initramfs/init` ]; then
	exit_error "[E] This kernel is already patched with z4build"
fi

# check for existance of busybox in the initramfs
if [ -f ${wrkdir}/initramfs/sbin/busybox ] && [ ! -L ${wrkdir}/initramfs/sbin/busybox ]; then
	# enable do_busybox to override existing busybox
	bb_size=`ls -l ${wrkdir}/initramfs/sbin/busybox  | awk '{print $5}'`
	bbz_size=`ls -l ${srcdir}/initramfs/busybox/sbin/busybox  | awk '{print $5}'`
	if [ $bb_size -gt $bbz_size ]; then
		do_busybox="true"
		printhl "[W] Flagging busybox overwrite to save space"
	fi
fi

# use real path of the init (in case its a symlink)
initfile=`realpath ${wrkdir}/initramfs/init`
#elf_signature=`file -b ${initfile}`
#if [ "${elf_signature:0:3}" == "ELF" ]; then
if [ -f ${initfile} ]; then
	printhl "[I] Replacing init binary"
	# move original init to sbin
	mv ${initfile} ${wrkdir}/initramfs/sbin/init
	# and place our init wrapper instead of /init
	cp ${srcdir}/initramfs/init.sh ${wrkdir}/initramfs/init
	# copy the pre/post-init script
	cp ${srcdir}/initramfs/z4post.init.sh ${wrkdir}/initramfs/
	cp ${srcdir}/initramfs/z4pre.init.sh ${wrkdir}/initramfs/
	# add onetime service to run post.init.sh at the end of init.rc
	echo -e "\n# Added by z4mod\nservice z4postinit /z4post.init.sh\n  oneshot\n\n" >> ${wrkdir}/initramfs/init.rc
else
	exit_error "[E] Couldn't find /init executable in the initramfs image"
fi

# install recovery
if [ ! -z "$do_recovery" ]; then
        printhl "[I] Replacing recovery"
        # copy files needed for recovery-2e
        cp -r ${srcdir}/initramfs/recovery/* ${wrkdir}/initramfs/
        # make sure the recovery script will start our new recovery binary
        sed -i 's|^service recovery.*|service recovery /sbin/recovery|g' ${wrkdir}/initramfs/recovery.rc
	sed -i 's|#mount rfs /dev/block/stl11 /cache |mount rfs /dev/block/stl11 /cache|g' ${wrkdir}/initramfs/recovery.rc
fi

# installing either busybox.init or full-busybox for our init wrapper
if [ ! -z "$do_busybox" ]; then
	printhl "[I] Installing full busybox"
	# copy the full-busybox binary, and replace busybox.init in our init wrappers
	cp -r ${srcdir}/initramfs/busybox/* ${wrkdir}/initramfs/
else
	# linking busybox to recovery
	ln -s recovery ${wrkdir}/initramfs/sbin/busybox
fi

# root
if [ ! -z "$do_root" ]; then
	# copy files for 'root'
	cp -r ${srcdir}/initramfs/root/* ${wrkdir}/initramfs/
	# z4post.init.sh will copy the apk to /system/app if needed
fi

# store version
cp ${srcdir}/z4version ${wrkdir}/initramfs/

# if user supplied his own rootfile, extract it now
if [ ! -z "${rootfile}" ]; then
	[ "${rootfile:0-3}" == "tar" ] && tar xv ${rootfile} -C ${wrkdir}/initramfs/
	# FIXME: this is useless for executables (binaries/scripts) since zip 
	#        doesn't preserve execution bit
	[ "${rootfile:0-3}" == "zip" ] && unzip ${rootfile} -d ${wrkdir}/initramfs/
fi

###############################################################################
#
# repack the patched initramfs and replace it with orignal initramfs in zImage
#
###############################################################################

printhl "[I] Saving patched initramfs.img"
(cd ${wrkdir}/initramfs/; find . | cpio -R 0:0 -H newc -o > ${wrkdir}/initramfs.img)
printhl "[I] Repacking zImage"
pushd ${wrkdir}
rm -f new_zImage
${KERNEL_REPACKER} ${zImage} ${wrkdir}/initramfs.img
popd
if [ ! -f ${wrkdir}/new_zImage ]; then
	exit_error "[E] Failed building new zImage"
fi
printhl "[I] Saving $zImage"
mv ${wrkdir}/new_zImage $zImage

rm -rf ${wrkdir}
printhl "[I] Done."

