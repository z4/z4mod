cmd_arch/arm/plat-s3c/gpio.o := /home/zero/s5pc1xx/cross/armv7a/bin/arm-s5pc1xx-linux-gnueabi-gcc -Wp,-MD,arch/arm/plat-s3c/.gpio.o.d  -nostdinc -isystem /home/zero/s5pc1xx/cross/armv7a/bin/../lib/gcc/arm-s5pc1xx-linux-gnueabi/4.3.1/include -Dlinux -Iinclude  -I/root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include -include include/linux/autoconf.h -D__KERNEL__ -mlittle-endian -Iarch/arm/mach-s5pc110/include -Iarch/arm/plat-s5pc11x/include -Iarch/arm/plat-s3c/include -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Os -marm -fno-omit-frame-pointer -mapcs -mno-sched-prolog -mabi=aapcs-linux -mno-thumb-interwork -D__LINUX_ARM_ARCH__=7 -mcpu=cortex-a8 -msoft-float -Uarm -fno-stack-protector -I/modules/include -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fwrapv  -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(gpio)"  -D"KBUILD_MODNAME=KBUILD_STR(gpio)"  -c -o arch/arm/plat-s3c/gpio.o arch/arm/plat-s3c/gpio.c

deps_arch/arm/plat-s3c/gpio.o := \
  arch/arm/plat-s3c/gpio.c \
    $(wildcard include/config/s3c/gpio/track.h) \
  include/linux/kernel.h \
    $(wildcard include/config/lbd.h) \
    $(wildcard include/config/preempt/voluntary.h) \
    $(wildcard include/config/debug/spinlock/sleep.h) \
    $(wildcard include/config/prove/locking.h) \
    $(wildcard include/config/printk.h) \
    $(wildcard include/config/dynamic/printk/debug.h) \
    $(wildcard include/config/numa.h) \
    $(wildcard include/config/ftrace/mcount/record.h) \
  /home/zero/s5pc1xx/cross/armv7a/bin/../lib/gcc/arm-s5pc1xx-linux-gnueabi/4.3.1/include/stdarg.h \
  include/linux/linkage.h \
  include/linux/compiler.h \
    $(wildcard include/config/trace/branch/profiling.h) \
    $(wildcard include/config/profile/all/branches.h) \
    $(wildcard include/config/enable/must/check.h) \
    $(wildcard include/config/enable/warn/deprecated.h) \
  include/linux/compiler-gcc.h \
    $(wildcard include/config/arch/supports/optimized/inlining.h) \
    $(wildcard include/config/optimize/inlining.h) \
  include/linux/compiler-gcc4.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/linkage.h \
  include/linux/stddef.h \
  include/linux/types.h \
    $(wildcard include/config/uid16.h) \
    $(wildcard include/config/phys/addr/t/64bit.h) \
    $(wildcard include/config/64bit.h) \
  include/linux/posix_types.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/posix_types.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/types.h \
  include/asm-generic/int-ll64.h \
  include/linux/bitops.h \
    $(wildcard include/config/generic/find/first/bit.h) \
    $(wildcard include/config/generic/find/last/bit.h) \
    $(wildcard include/config/generic/find/next/bit.h) \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/bitops.h \
    $(wildcard include/config/smp.h) \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/system.h \
    $(wildcard include/config/cpu/xsc3.h) \
    $(wildcard include/config/cpu/sa1100.h) \
    $(wildcard include/config/cpu/sa110.h) \
  include/linux/irqflags.h \
    $(wildcard include/config/trace/irqflags.h) \
    $(wildcard include/config/irqsoff/tracer.h) \
    $(wildcard include/config/preempt/tracer.h) \
    $(wildcard include/config/trace/irqflags/support.h) \
    $(wildcard include/config/x86.h) \
  include/linux/typecheck.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/irqflags.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/ptrace.h \
    $(wildcard include/config/arm/thumb.h) \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/hwcap.h \
  include/asm-generic/cmpxchg-local.h \
  include/asm-generic/cmpxchg.h \
  include/asm-generic/bitops/non-atomic.h \
  include/asm-generic/bitops/fls64.h \
  include/asm-generic/bitops/sched.h \
  include/asm-generic/bitops/hweight.h \
  include/asm-generic/bitops/lock.h \
  include/linux/log2.h \
    $(wildcard include/config/arch/has/ilog2/u32.h) \
    $(wildcard include/config/arch/has/ilog2/u64.h) \
  include/linux/ratelimit.h \
  include/linux/param.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/param.h \
    $(wildcard include/config/hz.h) \
  include/linux/dynamic_printk.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/byteorder.h \
  include/linux/byteorder/little_endian.h \
  include/linux/swab.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/swab.h \
  include/linux/byteorder/generic.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/bug.h \
    $(wildcard include/config/bug.h) \
    $(wildcard include/config/debug/bugverbose.h) \
  include/asm-generic/bug.h \
    $(wildcard include/config/generic/bug.h) \
    $(wildcard include/config/generic/bug/relative/pointers.h) \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/div64.h \
  include/linux/init.h \
    $(wildcard include/config/modules.h) \
    $(wildcard include/config/hotplug.h) \
  include/linux/io.h \
    $(wildcard include/config/mmu.h) \
    $(wildcard include/config/has/ioport.h) \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/io.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/memory.h \
    $(wildcard include/config/page/offset.h) \
    $(wildcard include/config/dram/size.h) \
    $(wildcard include/config/dram/base.h) \
    $(wildcard include/config/zone/dma.h) \
    $(wildcard include/config/discontigmem.h) \
    $(wildcard include/config/sparsemem.h) \
  include/linux/const.h \
  arch/arm/mach-s5pc110/include/mach/memory.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/sizes.h \
  include/linux/numa.h \
    $(wildcard include/config/nodes/shift.h) \
  include/asm-generic/memory_model.h \
    $(wildcard include/config/flatmem.h) \
    $(wildcard include/config/sparsemem/vmemmap.h) \
  arch/arm/plat-s3c/include/mach/io.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/page.h \
    $(wildcard include/config/cpu/copy/v3.h) \
    $(wildcard include/config/cpu/copy/v4wt.h) \
    $(wildcard include/config/cpu/copy/v4wb.h) \
    $(wildcard include/config/cpu/copy/feroceon.h) \
    $(wildcard include/config/cpu/xscale.h) \
    $(wildcard include/config/cpu/copy/v6.h) \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/glue.h \
    $(wildcard include/config/cpu/arm610.h) \
    $(wildcard include/config/cpu/arm710.h) \
    $(wildcard include/config/cpu/abrt/lv4t.h) \
    $(wildcard include/config/cpu/abrt/ev4.h) \
    $(wildcard include/config/cpu/abrt/ev4t.h) \
    $(wildcard include/config/cpu/abrt/ev5tj.h) \
    $(wildcard include/config/cpu/abrt/ev5t.h) \
    $(wildcard include/config/cpu/abrt/ev6.h) \
    $(wildcard include/config/cpu/abrt/ev7.h) \
    $(wildcard include/config/cpu/pabrt/ifar.h) \
    $(wildcard include/config/cpu/pabrt/noifar.h) \
  include/asm-generic/page.h \
  include/linux/gpio.h \
    $(wildcard include/config/generic/gpio.h) \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/gpio.h \
  arch/arm/mach-s5pc110/include/mach/gpio.h \
    $(wildcard include/config/s3c/gpio/space.h) \
    $(wildcard include/config/mach/s5pc110/p1p2.h) \
    $(wildcard include/config/mach/s5pc110/jupiter.h) \
  include/asm-generic/gpio.h \
    $(wildcard include/config/gpiolib.h) \
    $(wildcard include/config/gpio/sysfs.h) \
    $(wildcard include/config/have/gpio/lib.h) \
  include/linux/errno.h \
  /root/M110S/GalaxyS/linux-2.6.29-nilfs-oc12/arch/arm/include/asm/errno.h \
  include/asm-generic/errno.h \
  include/asm-generic/errno-base.h \
  arch/arm/mach-s5pc110/include/mach/gpio-jupiter.h \
  arch/arm/plat-s3c/include/plat/gpio-core.h \

arch/arm/plat-s3c/gpio.o: $(deps_arch/arm/plat-s3c/gpio.o)

$(deps_arch/arm/plat-s3c/gpio.o):
