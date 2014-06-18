#!/bin/bash
# usage : ./repacker.sh kernel

##############################################################################
# you should point where your cross-compiler is         
COMPILER=${CROSS_COMPILE:-~/x-tools/arm-z4-linux-gnueabi/bin/arm-z4-linux-gnueabi}
ARM_VERSION=${ARM_VERSION:-7}
##############################################################################
#set -x


ARCH_CFLAGS_7="-D__LINUX_ARM_ARCH__=7 -mcpu=cortex-a8"
ARCH_CFLAGS_6="-D__LINUX_ARM_ARCH__=6 -march=armv6k -mtune=arm1136j-s"

eval "ARCH_CFLAGS=$(echo \$ARCH_CFLAGS_$ARM_VERSION)"

srcdir=`dirname $0`
RESOURCES=`realpath $srcdir`/resources

C_H1="\033[1;37m" # highlight text 1
C_CLEAR="\033[1;0m"

printhl() {
	printf "${C_H1}[I] ${1}${C_CLEAR} \n"
}

#============================================
# rebuild zImage
#============================================
printhl "Starting kernel rebuild"

cp -r $RESOURCES ./
cd resources/2.6.29

#1. Image -> piggy.gz
printhl "Compressing new zImage"
gzip -f -9 < $1 > arch/arm/boot/compressed/piggy.gz

#2. piggy.gz -> piggy.o
printhl "Creating kernel object"
${COMPILER}gcc -Wp,-MD,arch/arm/boot/compressed/.piggy.o.d  -nostdinc -isystem toolchain_resources/include -Dlinux -Iinclude  -Iarch/arm/include -include include/linux/autoconf.h -D__KERNEL__ -mlittle-endian -Iarch/arm/mach-s5pc110/include -Iarch/arm/plat-s5pc11x/include -Iarch/arm/plat-s3c/include -D__ASSEMBLY__ -mabi=aapcs-linux -mno-thumb-interwork $ARCH_CFLAGS  -msoft-float -gdwarf-2  -Wa,-march=all   -c -o arch/arm/boot/compressed/piggy.o arch/arm/boot/compressed/piggy.S

#3. head.o
printhl "Compiling head"
${COMPILER}gcc -Wp,-MD,arch/arm/boot/compressed/.head.o.d  -nostdinc -isystem toolchain_resources/include -Dlinux -Iinclude  -Iarch/arm/include -include include/linux/autoconf.h -D__KERNEL__ -mlittle-endian -Iarch/arm/mach-s5pc110/include -Iarch/arm/plat-s5pc11x/include -Iarch/arm/plat-s3c/include -D__ASSEMBLY__ -mabi=aapcs-linux -mno-thumb-interwork $ARCH_CFLAGS  -msoft-float -gdwarf-2  -Wa,-march=all   -c -o arch/arm/boot/compressed/head.o arch/arm/boot/compressed/head.S

#4. misc.o
printhl "Compiling misc"
${COMPILER}gcc -Wp,-MD,arch/arm/boot/compressed/.misc.o.d  -nostdinc -isystem toolchain_resources/include -Dlinux -Iinclude  -Iarch/arm/include -include include/linux/autoconf.h -D__KERNEL__ -mlittle-endian -Iarch/arm/mach-s5pc110/include -Iarch/arm/plat-s5pc11x/include -Iarch/arm/plat-s3c/include -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Os -marm -fno-omit-frame-pointer -mapcs -mno-sched-prolog -mabi=aapcs-linux -mno-thumb-interwork $ARCH_CFLAGS -msoft-float -Uarm -fno-stack-protector -I/modules/include -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fwrapv -fpic -fno-builtin -Dstatic=  -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(misc)"  -D"KBUILD_MODNAME=KBUILD_STR(misc)"  -c -o arch/arm/boot/compressed/misc.o arch/arm/boot/compressed/misc.c

#5. head.o + misc.o + piggy.o --> vmlinux
printhl "Linking vmlinux"
${COMPILER}ld -EL    --defsym zreladdr=0x30008000 --defsym params_phys=0x30000100 -p --no-undefined -X toolchain_resources/libgcc.a -T arch/arm/boot/compressed/vmlinux.lds arch/arm/boot/compressed/head.o arch/arm/boot/compressed/piggy.o arch/arm/boot/compressed/misc.o -o arch/arm/boot/compressed/vmlinux 

#6. vmlinux -> zImage
printhl "Creating zImage"
${COMPILER}objcopy -O binary -R .note -R .note.gnu.build-id -R .comment -S  arch/arm/boot/compressed/vmlinux arch/arm/boot/zImage

# finishing
printhl "Cleaning up..."
mv arch/arm/boot/zImage ../../new_zImage
rm -f arch/arm/boot/compressed/vmlinux arch/arm/boot/compressed/piggy.o arch/arm/boot/compressed/misc.o arch/arm/boot/compressed/head.o arch/arm/boot/compressed/piggy.gz arch/arm/boot/Image
#rm -rf ../../out
