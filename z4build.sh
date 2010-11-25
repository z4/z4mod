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
	options=`(cd ${srcdir}/initramfs; find * -maxdepth 0 -type d ! -name z4mod)`
	options=`echo ${options} | sed -s 's/ /\//g'`
	printhl "\nUsage:"
	echo    "  z4build <zImage> [-z zImage] [options] [-t <file.tar>]"
	printhl "\nWhere:"
	echo    "zImage      = the zImage file (kernel) you wish to patch"
	echo    "-z zImage   = [optional] use initramfs from a different zImage"
	echo    "options     = [$options] install into initramfs"
	echo    "-t file.tar = [optional] extract file.tar over initramfs"
	echo
	exit 1
}

get_initramfs_img() {
	local zImagex=$1
	# find start of gziped kernel object in the zImage file:
	pos=`grep -F -a -b -m 1 --only-matching $'\x1F\x8B\x08' $zImagex | cut -f 1 -d :`
	printhl "[I] Extracting kernel image from $zImagex (start = $pos)"
	dd status=noxfer if=$zImagex bs=$pos skip=1 2>/dev/null| gunzip -q > ${wrkdir}/kernel.img

	# find start of the "cpio" initramfs image inside the kernel object:
	# ASCII cpio header starts with '070701'
	printhl "[I] Searching for cpio start position"
	start=`grep -F -a -b -m 1 --only-matching '070701' ${wrkdir}/kernel.img | head -1 | cut -f 1 -d :`
	if [ "$start" == "" ]; then
		printhl "[I] Searching for gzipped start position"
		# Determine if the cpio inside the zImage is gzipped
		gzip_start_arr=`grep -F -a -b --only-matching $'\x1F\x8B\x08' ${wrkdir}/kernel.img`
		for possible_gzip_start in $gzip_start_arr; do
			possible_gzip_start=`echo $possible_gzip_start | cut -f 1 -d :`
			dd status=noxfer if=${wrkdir}/kernel.img bs=$possible_gzip_start skip=1 2>/dev/null| gunzip -q > ${wrkdir}/cpio.img
			if [ $? -ne 1 ]; then
				printhl "[I] Extracting gzipped initramfs image from kernel (start = $possible_gzip_start)"
				mv ${wrkdir}/cpio.img ${wrkdir}/initramfs.img
				return
			fi
		done
		exit_error "[E] Could not find a valid initramfs image"
	fi

	printhl "[I] Extracting initramfs image from kernel (start = $start)"
	dd status=noxfer if=${wrkdir}/kernel.img bs=$start skip=1 > ${wrkdir}/initramfs.img 2>/dev/null
}

###############################################################################
#
# checking parameters and initalize stuff
#
###############################################################################

srcdir=`dirname $0`
srcdir=`realpath $srcdir`

# Making sure we have everything
if [ $# -eq 0 ]; then
	printerr "[E] Wrong parameters"
	exit_usage
fi

zImage=`realpath $1`
shift
if [ -z $zImage ] || [ ! -f $zImage ]; then
	printerr "[E] Can't find kernel: $zImage"
	exit_usage
fi

# We can start working
wrkdir=`pwd`/z4mod-$$-$RANDOM.tmp
KERNEL_REPACKER=$srcdir/repacker/kernel_repacker.sh
version=`cat ${srcdir}/z4version`
mkdir -p ${wrkdir}/initramfs/{system,sbin,dev/block,z4mod/log}

printhl "\n[I] z4build ${version} begins, Linuxizing `basename $zImage` ...\n"

###############################################################################
#
# extract initramfs.img, patch the binary init, patch the scripts and add 
# additional mounts
#
###############################################################################

get_initramfs_img $zImage
if [ "$1" == "-z" ]; then
	printhl "[I] Extracting initramfs image (`basename $zImage`)"
	mkdir ${wrkdir}/initramfs.tmp
	(cd ${wrkdir}/initramfs.tmp/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
	get_initramfs_img `realpath $2`
	printhl "[I] Extracting initramfs image (`basename $2`)"
	shift; shift
	(cd ${wrkdir}/initramfs/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
	printhl "[I] Copying modules from original initramfs"
	cp -a ${wrkdir}/initramfs.tmp/lib/modules/* ${wrkdir}/initramfs/lib/modules/
	cp -a ${wrkdir}/initramfs.tmp/modules/* ${wrkdir}/initramfs/modules/
	rm -r ${wrkdir}/initramfs.tmp
else
	printhl "[I] Extracting initramfs image"
	(cd ${wrkdir}/initramfs/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
fi

[ ! `ls ${wrkdir}/initramfs/init 2>/dev/null` ] && exit_error "[E] Invalid initramfs image (init binary not found)"
# use real path of the init (in case its a symlink)
initfile=${wrkdir}/initramfs/init
[ -L $initfile ] && initfile=${wrkdir}/initramfs/`readlink $initfile`
# check if this kernel is patched already with z4build
#ls -l ${srcdir}/initramfs/z4mod/bin/init $initfile
if cmp -s ${srcdir}/initramfs/z4mod/bin/init $initfile; then
	exit_error "[E] This kernel is already patched with z4build"
fi

#elf_signature=`file -b ${initfile}`
#if [ "${elf_signature:0:3}" == "ELF" ]; then
if [ ! -f ${initfile} -a ! -L ${initfile} ]; then
	exit_error "[E] Could not find a valid /init executable in initramfs"
fi

printhl "[I] Searching a replacement to inject z4mod init"
# calculate how much size z4mod uses (init script and tiny busybox if needed)
replace_size=$((4096+`stat -c%s ${srcdir}/initramfs/z4mod/bin/init`))
replace_size=$((replace_size+`stat -c%s ${srcdir}/initramfs/z4mod/bin/busybox`))

# find a file big enough to replace our init script/busybox	
#replacement_file=""
#for file in `find ${wrkdir}/initramfs/ -type f ! -name *.ko`; do
#	size=`stat -c%s $file`
#	if [ $size -gt $replace_size ]; then
#		replacement_file=$file
#		break
#	fi
#done
#[ "$replacement_file" == "" ] && exit_error "[E] Could not find a valid replacement file (needed: $replace_size)"

# find biggest file
replacement_file=`find ${wrkdir}/initramfs/ ! -name *.ko -type f -exec du -b {} \; | sort -rn | head -n1 | awk '{print $2}'`
replacement_size=`stat -c%s $replacement_file`
[ $replace_size -gt $replacement_size ] && exit_error "[E] Could not find a valid replacement file (needed: $replace_size)"

printhl "[I] Found replacement: `basename $replacement_file` (`stat -c%s $replacement_file`)"
mv $replacement_file ${wrkdir}/`basename $replacement_file`

printhl "[I] Replacing init binary"
# move original init to sbin
mv ${initfile} ${wrkdir}/initramfs/sbin/init
# incase real init was a symlink...
rm -f ${wrkdir}/initramfs/init
# and place our init wrapper instead of /init
cp -a ${srcdir}/initramfs/z4mod ${wrkdir}/initramfs/
ln -s /z4mod/bin/init ${wrkdir}/initramfs/init
# add onetime service to run post init scripts at the end of init.rc
echo -e "\n# Added by z4mod\nservice z4postinit /init\n  oneshot\n\n" >> ${wrkdir}/initramfs/init.rc

###############################################################################
#
# repack the patched initramfs and replace it with orignal initramfs in zImage
#
###############################################################################

printhl "[I] Saving patched initramfs.img"
(cd ${wrkdir}/initramfs/; find . | cpio --quiet -R 0:0 -H newc -o > ${wrkdir}/initramfs.img)
#if [ "$cpio_is_compressed" == "TRUE" ]; then
#	printhl "[I] Compressing initramfs.img"
#	gzip -f9c  ${wrkdir}/initramfs.img > ${wrkdir}/initramfs.img.gz
#	mv  ${wrkdir}/initramfs.img.gz  ${wrkdir}/initramfs.img
#fi
printhl "[I] Repacking zImage"
pushd ${wrkdir} >/dev/null
rm -f new_zImage
${KERNEL_REPACKER} ${zImage} ${wrkdir}/initramfs.img
popd >/dev/null
if [ ! -f ${wrkdir}/new_zImage ]; then
	exit_error "[E] Failed building new zImage"
fi
oldsize=`ls -l $zImage | awk '{print $5}'`
newsize=`ls -l ${wrkdir}/new_zImage | awk '{print $5}'`

printhl "[I] Saving $zImage"
mv ${wrkdir}/new_zImage $zImage

###############################################################################
#
# now pack the z4mod archive and add it to the end of zImage
#
###############################################################################

rm -rf ${wrkdir}/initramfs/
mkdir -p ${wrkdir}/initramfs/{sbin,cache,data,dbdata}
mkdir -p ${wrkdir}/initramfs/z4mod/{bin,log}
chmod 0771 ${wrkdir}/initramfs/data
chmod 0770 ${wrkdir}/initramfs/cache

# install the file we moved from original initramfs before
install -D ${wrkdir}/`basename $replacement_file` $replacement_file

# copy files/directories according to options provided
while [ "$*" ]; do
	if [ "$1" == "-t" ]; then
		# if user supplied his own rootfile, extract it
		shift
		rootfile=`realpath $1`
		if [ ! -f "${rootfile}" ]; then
			exit_error "[E] Can't find user supplied rootfile: $rootfile"
		fi
		printhl "[I] Adding user rootfile: $rootfile"
		[ "${rootfile:0-3}" == "tar" ] && tar xv ${rootfile} -C ${wrkdir}/initramfs
		[ "${rootfile:0-3}" == "zip" ] && unzip ${rootfile} -d ${wrkdir}/initramfs
	else
		# copy files of selected option
		printhl "[I] Adding $1"
		cp -a ${srcdir}/initramfs/$1/* ${wrkdir}/initramfs/
	fi
        shift
done

# making sure non-stanard stuff works...
for f in ${wrkdir}/initramfs/sbin/*; do chmod +x $f; done
# store version
cp ${srcdir}/z4version ${wrkdir}/initramfs/z4mod/

printhl "[I] Injecting z4mod compressed image"
(cd ${wrkdir}/initramfs/; tar zcf ${wrkdir}/z4mod.tar.gz --owner root --group root .)
cat ${wrkdir}/z4mod.tar.gz >> $zImage

rm -rf ${wrkdir}
printhl "[I] Done."

