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

xget_initramfs_img() {
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

# extract initramfs from zImage and set start/end offsets
get_initramfs_img() 
{
	local zImagex=$1
	pos=`grep -F -a -b -m 1 --only-matching $'\x1F\x8B\x08' $zImagex | cut -f 1 -d :`
	printhl "[I] Extracting kernel image from $zImagex (start = $pos)"
	dd status=noxfer if=$zImagex bs=$pos skip=1 2>/dev/null| gunzip -q > ${wrkdir}/kernel.img

	printhl "[I] Searching for a valid CPIO archive"
	start=`grep -F -a -b -m 1 --only-matching '070701' ${wrkdir}/kernel.img | head -1 | cut -f 1 -d :`
	end=`$FINDCPIO ${wrkdir}/kernel.img | cut -f 2`
	if [ "$start" == "" -o "$end" == "" -o $start -gt $end ]; then
		gzip_start_arr=`grep -F -a -b --only-matching $'\x1F\x8B\x08' ${wrkdir}/kernel.img`
		for possible_gzip_start in $gzip_start_arr; do
			possible_gzip_start=`echo $possible_gzip_start | cut -f 1 -d :`
			#dd status=noxfer if=${wrkdir}/kernel.img bs=$possible_gzip_start skip=1 2>/dev/null| gunzip -q > ${wrkdir}/initramfs.img
		        dd status=noxfer if=${wrkdir}/kernel.img bs=$possible_gzip_start skip=1 of=${wrkdir}/cpio.img 2>/dev/null
			gunzip -qf ${wrkdir}/cpio.img > ${wrkdir}/initramfs.img
			if [ $? -ne 1 ]; then
				is_gzipped="TRUE"
				start=$possible_gzip_start
				end=`$FINDZEROS ${wrkdir}/cpio.img | cut -f 2`
				printhl "[I] Compressed (gzip) CPIO detected at $start ~ $end"
				return
			fi
		done
		exit_error "[E] Could not find a valid CPIO archive"
	fi
	dd status=noxfer if=${wrkdir}/kernel.img bs=$start skip=1 > ${wrkdir}/initramfs.img 2>/dev/null
	printhl "[I] Non compressed CPIO detected at $start ~ $end"
}

###############################################################################
#
# checking parameters and initalize stuff
#
###############################################################################

# Making sure we have everything
if [ $# -eq 0 ]; then
	printerr "[E] Wrong parameters"
	exit_usage
fi

srcdir=`dirname $0`
srcdir=`realpath $srcdir`
zImage=`realpath $1`
shift
if [ -z $zImage ] || [ ! -f $zImage ]; then
	printerr "[E] Can't find kernel: $zImage"
	exit_usage
fi

# We can start working
wrkdir=`pwd`/z4mod-$$-$RANDOM.tmp
KERNEL_REPACKER=$srcdir/repacker/kernel_repacker.sh
FINDZEROS=$srcdir/repacker/findzeros.pl
FINDCPIO=$srcdir/repacker/findcpio.pl
version=`cat ${srcdir}/z4version`
mkdir -p ${wrkdir}/initramfs/{system,sbin,dev/block,z4mod/log}

printhl "\n[I] z4build ${version} begins, Linuxizing `basename $zImage` ...\n"

###############################################################################
#
# extract initramfs.img, patch the binary init, patch the scripts and add 
# additional mounts
#
###############################################################################

rootfile=""
options=""
from_zImage=""
# copy files/directories according to options provided
while [ "$*" ]; do
	if [ "$1" == "-t" ]; then
		# if user supplied his own rootfile, extract it
		shift
		rootfile=`realpath $1`
		if [ ! -f "${rootfile}" ]; then
			exit_error "[E] Can't find user supplied rootfile: $rootfile"
		fi
	elif [ "$1" == "-z" ]; then
		# if user supplied his secondary zImage to grab initramfs from
		shift
		from_zImage=`realpath $1`
		if [ ! -f "${from_zImage}" ]; then
			exit_error "[E] Can't find secondary zImage: $from_zImage"
		fi
	else
		options+="$1 "
	fi
        shift
done

if [ ! -z "$from_zImage" ]; then
	get_initramfs_img `realpath $from_zImage`
	printhl "[I] Extracting initramfs image (`basename $from_zImage`)"
	(cd ${wrkdir}/initramfs/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
	get_initramfs_img $zImage
	printhl "[I] Extracting initramfs image (`basename $zImage`)"
	mkdir ${wrkdir}/initramfs.tmp
	(cd ${wrkdir}/initramfs.tmp/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
	# TODO: instead of exiting, since we're replacing anyway, get offset of z4mod secondary initramfs,
	# extract it, and remove it from the zImage...
bash
	if cmp -s ${srcdir}/initramfs/z4mod/bin/init ${wrkdir}/initramfs.tmp/z4mod/bin/init; then
		exit_error "[E] This kernel is already patched with z4build"
	fi
	printhl "[I] Copying modules from original initramfs"
	cp -a ${wrkdir}/initramfs.tmp/lib/modules/* ${wrkdir}/initramfs/lib/modules/
	cp -a ${wrkdir}/initramfs.tmp/modules/* ${wrkdir}/initramfs/modules/
else
	get_initramfs_img $zImage
	printhl "[I] Extracting initramfs image"
	(cd ${wrkdir}/initramfs/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
fi

count=$((end - start))
if [ $count -lt 0 ]; then
	exit_error "[E] Could not determine start/end positions of the CPIO archive"
fi
initfile=${wrkdir}/initramfs/init
# use real path of the init (in case its a symlink)
#initfile=${wrkdir}/initramfs/`readlink $initfile`
#if [ ! -f ${initfile} -a ! -L ${initfile} ]; then
#	exit_error "[E] Could not find a valid /init executable in initramfs"
#fi
if [ ! `ls $initfile 2>/dev/null` ]; then
	exit_error "[E] Invalid initramfs image (init binary not found)"
fi
if [ -L $initfile ]; then
	exit_error "[E] Non-stock initramfs found1"
fi
elf_signature=`file -b ${initfile}`
if [ "${elf_signature:0:3}" != "ELF" ]; then
	exit_error "[E] Non-stock initramfs found2"
fi
# check if this kernel is patched already with z4build
if cmp -s ${srcdir}/initramfs/z4mod/bin/init $initfile; then
	exit_error "[E] This kernel is already patched with z4build"
fi

printhl "[I] Replacing init binary"
# move original init to sbin
mv ${initfile} ${wrkdir}/initramfs/sbin/init
# if real init was a symlink, rm it
rm -f ${wrkdir}/initramfs/init
# and place our init wrapper instead of /init
cp -a ${srcdir}/initramfs/z4mod ${wrkdir}/initramfs/
ln -s /z4mod/bin/init ${wrkdir}/initramfs/init
# add onetime service to run post init scripts at the end of init.rc
echo -e "\n# Added by z4mod\nservice z4postinit /init\n  oneshot\n\n" >> ${wrkdir}/initramfs/init.rc

###############################################################################
# TODO:
# compress z4mod initramfs including options
# check if we can replace
#   if yes > replace, build kernel, exit
#   if not > continue as now
#
###############################################################################

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
if [ $replace_size -gt $replacement_size ]; then
	exit_error "[E] Could not find a valid replacement file (needed: $replace_size)"
fi

printhl "[I] Found replacement: `basename $replacement_file` (`stat -c%s $replacement_file`)"
mv $replacement_file ${wrkdir}/`basename $replacement_file`

###############################################################################
#
# repack the patched initramfs and replace it with orignal initramfs in zImage
#
###############################################################################

printhl "[I] Saving patched initramfs.img"
(cd ${wrkdir}/initramfs/; find . | cpio --quiet -R 0:0 -H newc -o > ${wrkdir}/initramfs.img)

# Check the Image's size
filesize=`ls -l ${wrkdir}/kernel.img | awk '{print $5}'`

# Split the Image #1 ->  head.img
printhl "[I] Making head.img ( from 0 ~ $start )"
dd status=noxfer if=${wrkdir}/kernel.img bs=$start count=1 of=${wrkdir}/head.img 2>/dev/null

# Split the Image #2 ->  tail.img
printhl "[I] Making a tail.img ( from $end ~ $filesize )"
dd status=noxfer if=${wrkdir}/kernel.img bs=$end skip=1 of=${wrkdir}/tail.img 2>/dev/null

toobig="TRUE"
for method in "cat" "gzip -f9c" "lzma -f9c"; do
	$method ${wrkdir}/initramfs.img > ${wrkdir}/initramfs.img.full
	ramdsize=`ls -l ${wrkdir}/initramfs.img.full | awk '{print $5}'`
	printhl "[I] Current ramdsize using $method : $ramdsize with required size : $count"
	if [ $ramdsize -le $count ]; then
		printhl "[I] Method selected: $method"
		toobig="FALSE"
		break;
	fi
done
if [ "$toobig" == "TRUE" ]; then
	exit_error "[E] New ramdisk is still too big. Repack failed. $ramdsize > $count"
fi

franksize=`du -cb ${wrkdir}/head.img ${wrkdir}/initramfs.img.full | tail -n1 | awk '{print $1}'`

printhl "[I] Merging all kernel sections (head,ramdisk,padding,tail)"
if [ $franksize -lt $end ]; then
	tempnum=$((end - franksize))
	dd status=noxfer if=/dev/zero bs=$tempnum count=1 of=${wrkdir}/padding.img 2>/dev/null
	cat ${wrkdir}/head.img ${wrkdir}/initramfs.img.full ${wrkdir}/padding.img ${wrkdir}/tail.img > $zImage
else
	exit_error "[E] Combined zImage is too large - original end is $end and new end is $franksize"
fi

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

if [ ! -z "$rootfile" ]; then
	printhl "[I] Adding user rootfile: $rootfile"
	[ "${rootfile:0-3}" == "tar" ] && tar xv ${rootfile} -C ${wrkdir}/initramfs
	[ "${rootfile:0-3}" == "zip" ] && unzip ${rootfile} -d ${wrkdir}/initramfs
fi
# making sure non-stanard stuff works...
for f in ${wrkdir}/initramfs/sbin/*; do chmod +x $f; done
# add options if any
for opt in $options; do
	# copy files of selected option
	printhl "[I] Adding $opt"
	cp -a ${srcdir}/initramfs/$opt/* ${wrkdir}/initramfs/
done
# store version
cp ${srcdir}/z4version ${wrkdir}/initramfs/z4mod/

printhl "[I] Injecting z4mod compressed image"
(cd ${wrkdir}/initramfs/; tar zcf ${wrkdir}/z4mod.tar.gz --owner root --group root .)
cat ${wrkdir}/z4mod.tar.gz >> $zImage

rm -rf ${wrkdir}
printhl "[I] Done."

