#!/bin/bash
###############################################################################
#
# z4build by Elia Yehuda, aka z4ziggy, (c) 2010-2011
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

# extract initramfs from zImage and set start/end offsets
extract_zImage() 
{
	local zImagex=$1
	pos=`grep -F -a -b -m 1 --only-matching $'\x1F\x8B\x08' $zImagex | cut -f 1 -d :`

	printhl "[I] Extracting kernel image from $zImagex (start = $pos)"
	dd status=noxfer if=$zImagex bs=$pos skip=1 2>/dev/null| gunzip -q > ${wrkdir}/kernel.img

	printhl "[I] Extracting CPIO archive from kernel image"
	startend=`$MKIMGAGE ${wrkdir}/kernel.img ${wrkdir}/tmp.kernel.img -r ${wrkdir}/initramfs.img | tail -n1`

	if [ ! -f ${wrkdir}/initramfs.img ]; then 
		rm -rf ${wrkdir}
		exit_error "[E] Couldn't extract initramfs"
	fi

	start=$((`echo $startend | cut -d' ' -f 4`))
	end=$((`echo $startend | cut -d' ' -f 5`))
	imgsize=`stat -c %s ${wrkdir}/initramfs.img`

	if [ ! $((end - start)) -eq $imgsize ]; then 
		correct_end=$((start + imgsize))
		printhl "[W] ${MKIMGAGE} returns bad ending offset ${end} (should be ${correct_end}), fixing..."
		end=$correct_end
	fi

	if [ "`file ${wrkdir}/initramfs.img | cut -d' ' -f2`" == "gzip" ]; then
		printhl "[I] Compressed CPIO detected (gzip) ($start/$end)"
		cat ${wrkdir}/initramfs.img | gunzip -q > ${wrkdir}/initramfs.img.tmp
		mv ${wrkdir}/initramfs.img.tmp ${wrkdir}/initramfs.img

	elif [ "`dd if=${wrkdir}/initramfs.img bs=4 count=1 2>/dev/null| od -X | head -n1 | cut -d' ' -f2`" == "0000005d" ]; then
		printhl "[I] Compressed CPIO detected (lzma) ($start/$end)"
		lzma -S img -d ${wrkdir}/initramfs.img
		mv ${wrkdir}/initramfs. ${wrkdir}/initramfs.img

	else
		printhl "[I] Non-compressed CPIO detected ($start/$end)"
	fi
}

validate_initramfs()
{
	local xinitfile=$1
	if [ ! `ls $xinitfile 2>/dev/null` ]; then
		exit_error "[E] Invalid initramfs image (init binary not found)"
	fi
	if [ -L $xinitfile ]; then
		exit_error "[E] Non-stock initramfs found (linked init)"
	fi
	elf_signature=`file -b ${xinitfile}`
	if [ "${elf_signature:0:3}" != "ELF" ]; then
		exit_error "[E] Non-stock initramfs found (non-elf init)"
	fi
	# check if this kernel is patched already with z4build
	if cmp -s ${srcdir}/initramfs/z4mod/bin/init $xinitfile; then
		exit_error "[E] This kernel is already patched with z4build"
	fi
}

repack_zImage()
{
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
	${KERNEL_REPACKER} ${zImage}
	popd >/dev/null
	if [ ! -f ${wrkdir}/new_zImage ]; then
		exit_error "[E] Failed building new zImage"
	fi
	printhl "[I] Saving $zImage"
	mv ${wrkdir}/new_zImage $zImage
}

compress_initramfs()
{
	for method in "cat" "gzip -f9c" "lzma -f9c"; do
		$method ${wrkdir}/initramfs.img > ${wrkdir}/initramfs.img.full
		ramdsize=`ls -l ${wrkdir}/initramfs.img.full | awk '{print $5}'`
		printhl "[I] Current ramdsize using $method : $ramdsize with required size : $count"
		if [ $ramdsize -le $count ]; then
			printhl "[I] Method selected: $method"
			return 1
		fi
	done
	return 0
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
if [ -z $zImage ] || [ ! -f $zImage ]; then
	printerr "[E] Can't find kernel: $zImage ($1)"
	exit_usage
fi
shift

# We can start working
wrkdir=`pwd`/z4mod-$$-$RANDOM.tmp
KERNEL_REPACKER=$srcdir/repacker/kernel_repacker.sh
MKIMGAGE=$srcdir/repacker/mkimgage
version=`cat ${srcdir}/z4version`
mkdir -p ${wrkdir}/initramfs/{system,sbin,dev/block,z4mod/log}
mkdir -p ${wrkdir}/initramfs/{sbin,cache,data,dbdata}
chmod 0771 ${wrkdir}/initramfs/data
chmod 0770 ${wrkdir}/initramfs/cache

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
			exit_error "[E] Can't find secondary zImage: $from_zImage ($1)"
		fi
	else
		options+="$1 "
	fi
        shift
done

if [ ! -z "$from_zImage" ]; then
	extract_zImage `realpath $from_zImage`
	printhl "[I] Extracting initramfs image (`basename $from_zImage`)"
	(cd ${wrkdir}/initramfs/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
	extract_zImage $zImage
	printhl "[I] Extracting initramfs image (`basename $zImage`)"
	mkdir ${wrkdir}/initramfs.tmp
	(cd ${wrkdir}/initramfs.tmp/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
	# TODO: instead of exiting, since we're replacing anyway, get offset of z4mod secondary initramfs,
	# extract it, and remove it from the zImage...
	#validate_initramfs ${wrkdir}/initramfs.tmp/init
	if [ ! -f ${wrkdir}/initramfs.tmp/init ]; then
		exit_error "[E] Invalid initramfs image (init binary not found)"
	fi
	if cmp -s ${srcdir}/initramfs/z4mod/bin/init ${wrkdir}/initramfs.tmp/z4mod/bin/init; then
		exit_error "[E] This kernel is already patched with z4build"
	fi
	printhl "[I] Copying modules from original initramfs"
	cp -a ${wrkdir}/initramfs.tmp/lib/modules/* ${wrkdir}/initramfs/lib/modules/
	cp -a ${wrkdir}/initramfs.tmp/modules/* ${wrkdir}/initramfs/modules/
else
	extract_zImage $zImage
	printhl "[I] Extracting initramfs image"
	(cd ${wrkdir}/initramfs/; cpio --quiet -i --no-absolute-filenames < ${wrkdir}/initramfs.img >/dev/null 2>&1)
fi

count=$((end - start))
if [ $count -lt 0 ]; then
	exit_error "[E] Could not determine start/end positions of the CPIO archive"
fi

# Split the Image #1 ->  head.img
printhl "[I] Dumping head.img from kernel image"
dd status=noxfer if=${wrkdir}/kernel.img bs=$start count=1 of=${wrkdir}/head.img 2>/dev/null

# Split the Image #2 ->  tail.img
printhl "[I] Dumping a tail.img from kernel image"
dd status=noxfer if=${wrkdir}/kernel.img bs=$end skip=1 of=${wrkdir}/tail.img 2>/dev/null

initfile=${wrkdir}/initramfs/init
validate_initramfs $initfile

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
# store version
cp ${srcdir}/z4version ${wrkdir}/initramfs/z4mod/

###############################################################################
#
# check if we can replace the initramfs, otherwise only replace the init
# and add a 2nd initramfs at the end of zImage file
#
###############################################################################

printhl "[I] Testing complete initramfs replacement"

cp -a ${wrkdir}/initramfs ${wrkdir}/initramfs.new

if [ ! -z "$rootfile" ]; then
	if [ "${rootfile:0-3}" == "tar" ]; then
		printhl "[I] Adding user rootfile: $rootfile"
		tar xv ${rootfile} -C ${wrkdir}/initramfs.new
	elif [ "${rootfile:0-3}" == "zip" ]; then
		printhl "[I] Adding user rootfile: $rootfile"
		unzip ${rootfile} -d ${wrkdir}/initramfs.new
	else
		printerr "[W] Could not determine rootfile type, skipping"
	fi
fi
# making sure non-stanard stuff works...
for f in ${wrkdir}/initramfs.new/sbin/*; do chmod +x $f; done
# add options if any
for opt in $options; do
	# copy files of selected option
	printhl "[I] Adding $opt"
	cp -a ${srcdir}/initramfs/$opt/* ${wrkdir}/initramfs.new/
done
# remove 2nd initramfs extraction from init script
sed -i '/# extract z4mod initramfs/,/^$/d' ${wrkdir}/initramfs.new/z4mod/bin/init

printhl "[I] Saving patched initramfs.img"
(cd ${wrkdir}/initramfs.new/; find . | cpio --quiet -R 0:0 -H newc -o > ${wrkdir}/initramfs.img)

compress_initramfs
if [ $? -eq 1 ]; then
	repack_zImage
	rm -rf ${wrkdir}
	printhl "[I] Done."
	exit
fi
printerr "[W] Failed replacing complete initramfs, splitting initramfs"

printhl "[I] Searching a replacement to inject z4mod init"
# calculate how much size z4mod uses (init script and tiny busybox if needed)
replace_size=$((4096+`stat -c%s ${srcdir}/initramfs/z4mod/bin/init`))
replace_size=$((replace_size+`stat -c%s ${srcdir}/initramfs/z4mod/bin/busybox`))

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

compress_initramfs
if [ $? -ne 1 ]; then
	exit_error "[E] New ramdisk is still too big. Repack failed. $ramdsize > $count"
fi

repack_zImage

###############################################################################
#
# now pack the 2nd part of the z4mod initramfs and add it to the end of zImage
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
	if [ "${rootfile:0-3}" == "tar" ]; then
		printhl "[I] Adding user rootfile: $rootfile"
		tar xv ${rootfile} -C ${wrkdir}/initramfs
	elif [ "${rootfile:0-3}" == "zip" ]; then
		printhl "[I] Adding user rootfile: $rootfile"
		unzip ${rootfile} -d ${wrkdir}/initramfs
	else
		printerr "[W] Could not determine rootfile type, skipping"
	fi

fi
# making sure non-stanard stuff works...
for f in ${wrkdir}/initramfs/sbin/*; do chmod +x $f; done
# add options if any
for opt in $options; do
	# copy files of selected option
	printhl "[I] Adding $opt"
	cp -a ${srcdir}/initramfs/$opt/* ${wrkdir}/initramfs/
done

printhl "[I] Injecting z4mod compressed image"
(cd ${wrkdir}/initramfs/; tar zcf ${wrkdir}/z4mod.tar.gz --owner root --group root .)
cat ${wrkdir}/z4mod.tar.gz >> $zImage

rm -rf ${wrkdir}
printhl "[I] Done."

