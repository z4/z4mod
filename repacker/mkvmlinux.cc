/* 
 * Copyright (c) 2010 Hexabit
 *	Hexabit [http://forum.xda-developers.com/member.php?u=3074759]
 *
 * Convert an uncompressed kernel image into a vmlinux converting the kallsymtab
 * structures into symbols. Optionally extract the kallsym table and ramdisk image.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License.
*/

/*
 * Compile example:
 *   g++ mkimgage.cc -o mkimgage -lbfd -liberty -lz [-I and -L that deeplink into binutils]
 *
 * Static compile:
 *   g++ mkvmlinux.cc -o mkimgage -lbfd -liberty -lz [-I -L ...] -static -ldl
 *
 * Extract an uncompressed image:
 *   gcc scripts/binoffset.c -o scripts/binoffset
 *   ofs=`scripts/binoffset zImage 0x1f 0x8b 0x08 0x00 2>/dev/null`
 *   dd ibs=$ofs skip=1 <zImage | gzip -c -d >Image
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <malloc.h>
#include <string.h>
#include <bfd.h>
#include <getopt.h>

int quiet = 0;
const char *input_fname = NULL;
const char *output_fname = NULL;
const char *symbol_fname = NULL;
const char *ramdisk_fname = NULL;
const char *default_target = "elf32-little";
const char *default_architecture = "arm";
unsigned long input_base = 0xc0008000;

bfd *obfd;
asection *text_section;
asection *rodata_section;
asection *data_section;
asection *bss_section;
asymbol *symtab[99999];
int symcnt = 0;

unsigned long input_address;
unsigned char *input_data;
size_t input_size;

// offsets of locations
unsigned int kallsyms_addresses_off;
unsigned int kallsyms_num_syms_off;
unsigned int kallsyms_names_off;
unsigned int kallsyms_markers_off;
unsigned int kallsyms_token_table_off;
unsigned int kallsyms_token_index_off;
// key values
unsigned int kallsyms_num_syms;
unsigned int kallsyms_markers;
unsigned int kallsyms_tokens;

bfd_vma text_base, rodata_base, data_base, bss_base, end_base;
bfd_vma initramfs_start, initramfs_end;

void bfd_nonfatal (const char *string)
{
	fprintf (stderr, "%s returned %s\n", string, bfd_errmsg (bfd_get_error()));
}

void bfd_fatal (const char *string)
{
	bfd_nonfatal (string);
	exit (1);
}

void usage(const char *argv0, FILE *f, int ret)
{
	fprintf(f, "usage: %s [OPTION]... INPUT OUTPUT\n\n"
		"\t-s --symbol=file           Reconstruct kallsym file\n"
		"\t-r --ramdisk=file          Extract ramdisk image\n"
		"\t-a --address=address       Base address of image [0x%08lx]\n"
		"\t-b --target=bfdname        Specify the target object format [%s]\n"
		"\t-m --architecture=machine  Specify the target architecture [%s]\n"
		"\t-q --quiet                 Be silent\n"
		"\t-h --help                  Display this help and exit\n",
		argv0, input_base, default_target, default_architecture);
	exit(ret);
}

void scan_kallsyms(void)
{
unsigned char *data = input_data;

	// try to isolate kallsyms_num_syms
	for (unsigned int i=0; i<input_size; i+=16) {
		if (data[i+ 4] != 0 || data[i+ 5] != 0 || data[i+ 6] != 0 || data[i+ 7] != 0 ||
		    data[i+ 8] != 0 || data[i+ 9] != 0 || data[i+10] != 0 || data[i+11] != 0 ||
		    data[i+12] != 0 || data[i+13] != 0 || data[i+14] != 0 || data[i+15] != 0 ||
		    data[i+16] == 0)
			continue;

		// candidate
		kallsyms_num_syms_off = i;
		kallsyms_num_syms = *(int*)(data+kallsyms_num_syms_off);
		// candidate should be reasonable
		if (kallsyms_num_syms <= 0 || kallsyms_num_syms > 99999)
			continue;

		// kallsyms_names is 16 bytes behind kallsyms_num_syms
		kallsyms_names_off = kallsyms_num_syms_off + 16;

		kallsyms_markers_off = kallsyms_names_off;
		// simple scan name table to detect overflow
		kallsyms_tokens = 0;
		for (unsigned int j=0; j<kallsyms_num_syms && kallsyms_markers_off < input_size; j++) {
			for (unsigned int k=0; k<data[kallsyms_markers_off]; k++)
				if (data[kallsyms_markers_off+1+k] > kallsyms_tokens)
					kallsyms_tokens = data[kallsyms_markers_off+1+k];
			if (data[kallsyms_markers_off] == 0) {
				kallsyms_markers_off = input_size;
				break;
			}
			kallsyms_markers_off += 1 + data[kallsyms_markers_off];

		}
		if (kallsyms_markers_off >= input_size)
			continue;
		// name table is aligned and padded with zero's
		for (unsigned int k=0; k<16; k++)
			if (kallsyms_markers_off&15) { if (data[kallsyms_markers_off]) continue; kallsyms_markers_off++; }
		// include boundry
		kallsyms_tokens++;

		// marker table
		kallsyms_markers = (kallsyms_num_syms+255)/256;
		if (*(int*)(data+kallsyms_markers_off) != 0) continue;
		{
			unsigned int j;
			for (j=0; j<kallsyms_markers-1; j++) {
				if (*(int*)(data+kallsyms_markers_off+j*4) > *(int*)(data+kallsyms_markers_off+j*4+4))
					break;
			}
			if (j < kallsyms_markers-1)
				continue;
		}
		kallsyms_token_table_off = kallsyms_markers_off + kallsyms_markers * 4;
		// token table is aligned and padded with zero's
		for (unsigned int k=0; k<16; k++)
			if (kallsyms_token_table_off&15) { if (data[kallsyms_token_table_off]) continue; kallsyms_token_table_off++; }

		// token table
		kallsyms_token_index_off = kallsyms_token_table_off;
		for (unsigned int j=0; j<kallsyms_tokens && kallsyms_token_index_off < input_size; j++) {
			kallsyms_token_index_off += strlen((const char*)data+kallsyms_token_index_off) + 1;
		}
		if (kallsyms_token_index_off >= input_size)
			continue;
		// token table is aligned and padded with zero's
		for (unsigned int k=0; k<16; k++)
			if (kallsyms_token_index_off&15) { if (data[kallsyms_token_index_off]) continue; kallsyms_token_index_off++; }

		// addresses table should be a good bet
		kallsyms_addresses_off = kallsyms_num_syms_off - kallsyms_num_syms*4;
		// align
		kallsyms_addresses_off &= ~15;
		{
			unsigned int j;
			for (j=0; j<kallsyms_num_syms; j++) {
				if (*(unsigned int*)(data+kallsyms_addresses_off+j*4) < 0xc0008000 || *(unsigned int*)(data+kallsyms_addresses_off+j*4) > 0xc1000000)
					break;
			}
			if (j < kallsyms_num_syms)
				continue;
		}

		// got a match
		break;
	}

	if (!kallsyms_num_syms) {
		printf("no kallsym data found\n");
	} else {
		printf("kallsym data found at 0x%08lx. kallsyms_num_syms:%d kallsyms_markers:%d kallsyms_tokens:%d\n", 
			(long)(input_base+kallsyms_addresses_off), kallsyms_num_syms, kallsyms_markers, kallsyms_tokens);
	}

	// if kallsyms found, guesstimate the section sizes
	text_base = input_base+0x01000000;
	rodata_base = input_base+0x01000000;
	data_base = input_base+0x01000000;
	bss_base = input_base+0x01000000;
	end_base = input_base;

	{
		unsigned int addr_pos = kallsyms_addresses_off;
		unsigned int name_pos = kallsyms_names_off;
		for (unsigned int i=0; i<kallsyms_num_syms; i++) {
			unsigned int sym_value = *(unsigned int*)(input_data+addr_pos);
			addr_pos += 4;

			unsigned int name_len = *(unsigned char*)(input_data+name_pos++);

			unsigned int tok = *(unsigned char*)(input_data+name_pos);
			char *sp = (char*)input_data + kallsyms_token_table_off + *(unsigned short*)(input_data+kallsyms_token_index_off+tok*2);
			name_pos += name_len;

			char sym_type = sp[0];
			if (sym_type == 'B' || sym_type == 'b') {
				if (sym_value < bss_base)
					bss_base = sym_value;
				if (sym_value+4 > end_base)
					end_base = sym_value+4;
			} else if (sym_type == 'R' || sym_type == 'r') {
				if (sym_value < rodata_base)
					rodata_base = sym_value;
			} else if (sym_type == 'D' || sym_type == 'd') {
				if (sym_value < data_base)
					data_base = sym_value;
			} else if (sym_type == 'T' || sym_type == 't') {
				if (sym_value < text_base)
					text_base = sym_value;
			}
		}
	}

	if (kallsyms_num_syms > 0) {
		bfd_vma addr = input_base + kallsyms_addresses_off;
		if (addr < rodata_base)
			rodata_base = addr;
		else if (addr < data_base)
			data_base = addr;
	}

//	printf("%08x %08x %08x %08x %08x\n", (int)text_base, (int)rodata_base, (int)data_base, (int)bss_base, (int)end_base);
}

void inject_kallsyms(void)
{
	unsigned int addr_pos = kallsyms_addresses_off;
	unsigned int name_pos = kallsyms_names_off;
	for (unsigned int i=0; i<kallsyms_num_syms; i++) {
		unsigned int sym_value = *(unsigned int*)(input_data+addr_pos);
		addr_pos += 4;

		unsigned int name_len = *(unsigned char*)(input_data+name_pos++);
		char sym_name[512], *dp = sym_name;

		for (unsigned int j=0; j<name_len; j++) {
			unsigned int tok = *(unsigned char*)(input_data+name_pos++);
			char *sp = (char*)input_data + kallsyms_token_table_off + *(unsigned short*)(input_data+kallsyms_token_index_off+tok*2);
			while (*sp)
				*dp++ = *sp++;
		}
		*dp++ = 0;

		// got symbol, now enter into table
		asymbol *sym = bfd_make_empty_symbol(obfd);
		sym->name = strdup(sym_name+1); // MEMORY LEAK

		// catch reserved symbols
		if (sym->name[0] == '_') {
			if (strcmp(sym->name, "__initramfs_start") == 0)
				initramfs_start = sym_value;
			if (strcmp(sym->name, "__initramfs_end") == 0)
				initramfs_end = sym_value;
		}

		// value
		if (sym_value >= bss_base) {
			sym->section = bss_section;
			sym->value = sym_value - bss_section->vma;
		} else if (sym_value >= data_base) {
			sym->section = data_section;
			sym->value = sym_value - data_section->vma;
		} else if (sym_value >= rodata_base) {
			sym->section = rodata_section;
			sym->value = sym_value - rodata_section->vma;
		} else if (sym_value >= text_base) {
			sym->section = text_section;
			sym->value = sym_value - text_section->vma;
		} else {
			sym->section = &bfd_abs_section;
			sym->value = sym_value - text_section->vma;
		}

		// and type
		char sym_type = sym_name[0];
		if (sym_type == 'T' || sym_type == 'R' || sym_type == 'D' || sym_type == 'B')
			sym->flags = BSF_GLOBAL;
		else if (sym_type == 't' || sym_type == 'r' || sym_type == 'd' || sym_type == 'b')
			sym->flags = BSF_LOCAL;
		else if (sym_type == 'W' || sym_type == 'w')
			sym->flags = BSF_WEAK;

		symtab[symcnt++] = sym;
	}
}

void dump_kallsyms(const char *fname)
{
unsigned char *data = input_data;
unsigned long pos;

	// dump symbol.S
	FILE *sf = fopen(fname, "w");
	if (!sf) { fprintf(stderr, "fopen(%s) returned: %m\n", fname); exit(1); }

	fprintf(sf, "# kallsyms_num_syms: %d\n", kallsyms_num_syms);
	fprintf(sf, "# kallsyms_markers: %d\n", kallsyms_markers);
	fprintf(sf, "# kallsyms_tokens: %d\n", kallsyms_tokens);
	fprintf(sf, "# kallsyms_addresses_off: 0x%08lx\n", input_base+kallsyms_addresses_off);
	fprintf(sf, "# kallsyms_num_syms_off: 0x%08lx\n", input_base+kallsyms_num_syms_off);
	fprintf(sf, "# kallsyms_names_off: 0x%08lx\n", input_base+kallsyms_names_off);
	fprintf(sf, "# kallsyms_markers_off: 0x%08lx\n", input_base+kallsyms_markers_off);
	fprintf(sf, "# kallsyms_token_table_off: 0x%08lx\n", input_base+kallsyms_token_table_off);
	fprintf(sf, "# kallsyms_token_index_off: 0x%08lx\n", input_base+kallsyms_token_index_off);
	fprintf(sf, "\n");

	fprintf(sf, "\t.section .rodata, \"a\"\n");

	pos = kallsyms_addresses_off;

	fprintf(sf, ".globl kallsyms_addresses\n\t.align 4\nkallsyms_addresses:\n");
	for (unsigned int i=0; i<kallsyms_num_syms; i++,pos+=4) {
		fprintf(sf, "\t.long\t0x%08x\n", *(unsigned int*)(data+pos));
	}
	for (;pos < kallsyms_num_syms_off; pos+=4) {
		fprintf(sf, "\t.long\t0x%08x\n", *(unsigned int*)(data+pos));
	}

	fprintf(sf, ".globl kallsyms_num_syms\n\t.align 4\nkallsyms_num_syms:\n");
	for (unsigned int i=0; i<1; i++,pos+=4) {
		fprintf(sf, "\t.long\t%d\n", *(unsigned int*)(data+pos));
	}
	for (;pos < kallsyms_names_off; pos+=4) {
		fprintf(sf, "\t.long\t0x%08x\n", *(unsigned int*)(data+pos));
	}

	fprintf(sf, ".globl kallsyms_names\n\t.align 4\nkallsyms_names:\n");
	for (unsigned int i=0; i<kallsyms_num_syms; i++) {
		fprintf(sf, "\t.byte ");
		int len = *(unsigned char*)(data+pos++);
		fprintf(sf, "0x%02x", len);
		while (--len>=0)
			fprintf(sf, ", 0x%02x", *(unsigned char*)(data+pos++));
		fprintf(sf, "\n");
	}
	for (;pos < kallsyms_markers_off; pos++) {
		fprintf(sf, "\t.byte\t0x%02x\n", *(unsigned char*)(data+pos));
	}

	fprintf(sf, ".globl kallsyms_markers\n\t.align 4\nkallsyms_markers:\n");
	for (unsigned int i=0; i<kallsyms_markers; i++,pos+=4) {
		fprintf(sf, "\t.long\t%d\n", *(unsigned int*)(data+pos));
	}
	for (;pos < kallsyms_token_table_off; pos+=4) {
		fprintf(sf, "\t.long\t0x%08x\n", *(unsigned int*)(data+pos));
	}

	fprintf(sf, ".globl kallsyms_token_table\n\t.align 4\nkallsyms_token_table:\n");
	for (unsigned int i=0; i<kallsyms_tokens; i++) {
		fprintf(sf, "\t.asciz\t\"%s\"\n", (char*)(data+pos));
		pos += strlen((char*)(data+pos))+1;
	}
	for (;pos < kallsyms_token_index_off; pos++) {
		fprintf(sf, "\t.byte\t0x%08x\n", *(unsigned char*)(data+pos));
	}

	fprintf(sf, ".globl kallsyms_token_index\n\t.align 4\nkallsyms_token_index:\n");
	for (unsigned int i=0; i<kallsyms_tokens; i++) {
		fprintf(sf, "\t.short\t\%d\n",  *(short*)(data+pos));
		pos += 2;
	}

	fclose(sf);
}

int main(int argc, char **argv)
{
	while (1) {
		int option_index = 0;
		static struct option long_options[] = {
			{"symbol", 1, 0, 's'},
			{"ramdisk", 1, 0, 'r'},
			{"address", 1, 0, 'a'},
			{"target", 1, 0, 'b'},
			{"architecture", 1, 0, 'm'},
			{"quiet", 0, 0, 'q'},
			{"help", 0, 0, 'h'},
			{0, 0, 0, 0}
		};

		int c = getopt_long (argc, argv, "qhs:r:b:m:a:", long_options, &option_index);
		if (c == -1)
			break;

		switch (c) {
		case 'q':
			quiet = 1;
			break;
		case 's':
			symbol_fname = optarg;
			break;
		case 'r':
			ramdisk_fname = optarg;
			break;
		case 'a':
			input_address = strtoll(optarg, NULL, 0);
			break;
		case 'b':
			default_target = optarg;
			break;
		case 'm':
			default_architecture = optarg;
			break;
		case 'h':
			usage(argv[0], stdout, 0);
			break;
		case '?':
			usage(argv[0], stderr, 1);
			break;
		default:
			fprintf (stderr, "?? getopt returned character code 0%o ??\n", c);
		}
	}

	while (optind < argc) {
		if (input_fname == NULL)
			input_fname = argv[optind++];
		else if (output_fname == NULL)
			output_fname = argv[optind++];
		else
			usage(argv[0], stderr, 1);
	}
	if (input_fname == NULL || output_fname == NULL)
		usage(argv[0], stderr, 1);


	// open and load input
	if (1) {
		struct stat sbuf;

		FILE *f = fopen(input_fname, "r");
		if (!f) { fprintf(stderr, "fopen(%s) returned %m\n", input_fname); return 1; }
		if (fstat(fileno(f), &sbuf)) { fprintf(stderr, "fstat(%s) returned %m\n", input_fname); return 1; }
		input_size = sbuf.st_size;
		input_data = (typeof(input_data)) malloc (input_size);
		if (input_data == NULL) { fprintf(stderr, "malloc(%zd) returned %m\n", input_size); return 1; }
		if (fread(input_data, input_size, 1, f) != 1) { fprintf(stderr, "fread(%s,%zd) returned: %m\n", input_fname, input_size); return 1; }
		fclose(f);
	}

	// scan for kallsyms
	scan_kallsyms();

	// create bfd
	bfd_init ();

	// find target/architecture info
	const bfd_target *tinfo = bfd_find_target(default_target, NULL);
	if (tinfo == NULL) { fprintf(stderr, "target not supported\n"); return 1; }
	const bfd_arch_info_type *ainfo = bfd_scan_arch(default_architecture);
	if (ainfo == NULL) { fprintf(stderr, "architecture not supported\n"); return 1; }

	// create output bfd
	obfd = bfd_openw (output_fname, default_target);
	if (!obfd) bfd_fatal("bfd_openw()");
	bfd_set_arch_info(obfd, ainfo);
	if (!bfd_set_arch_mach(obfd, ainfo->arch, ainfo->mach)) bfd_fatal("bfd_set_arch_mach()");
	if (!bfd_set_format (obfd, bfd_object)) bfd_fatal("bfd_set_format()");

	// create sections
	text_section = bfd_make_section_with_flags(obfd, ".text", SEC_ALLOC|SEC_LOAD|SEC_HAS_CONTENTS|SEC_CODE|SEC_READONLY);
	if (!text_section) bfd_fatal("bfd_make_section_with_flags()");
	rodata_section = bfd_make_section_with_flags(obfd, ".rodata", SEC_ALLOC|SEC_LOAD|SEC_HAS_CONTENTS|SEC_DATA|SEC_READONLY);
	if (!rodata_section) bfd_fatal("bfd_make_section_with_flags()");
	data_section = bfd_make_section_with_flags(obfd, ".data", SEC_ALLOC|SEC_LOAD|SEC_HAS_CONTENTS|SEC_DATA);
	if (!data_section) bfd_fatal("bfd_make_section_with_flags()");
	bss_section = bfd_make_section_with_flags(obfd, ".bss", SEC_ALLOC);
	if (!bss_section) bfd_fatal("bfd_make_section_with_flags()");

	// set vma's
	bfd_set_section_vma(obfd, text_section, text_base);
	bfd_set_section_vma(obfd, rodata_section, rodata_base);
	bfd_set_section_vma(obfd, data_section, data_base);
	bfd_set_section_vma(obfd, bss_section, bss_base);

	// inject symbols
	if (kallsyms_num_syms > 0) {
		inject_kallsyms();
		symtab[symcnt] = 0;
		if (!bfd_set_symtab(obfd, symtab, symcnt)) bfd_fatal("bfd_set_symtab()");
	}

	if (!initramfs_start) {
		printf("no initramfs data found\n");
	} else {
		printf("initramfs found: start/end 0x%08lx 0x%08lx\n", (long)initramfs_start-text_base, (long)initramfs_end-text_base);
	}

	// set section sizes
	if (!bfd_set_section_size(obfd, text_section, rodata_base-text_base)) bfd_fatal("bfd_set_section_size()");
	if (!bfd_set_section_size(obfd, rodata_section, data_base-rodata_base)) bfd_fatal("bfd_set_section_size()");
	if (!bfd_set_section_size(obfd, data_section, bss_base-data_base)) bfd_fatal("bfd_set_section_size()");
	if (!bfd_set_section_size(obfd, bss_section, end_base-bss_base)) bfd_fatal("bfd_set_section_size()");

	// splice data
	if (!bfd_set_section_contents(obfd, text_section, input_data, 0, rodata_base-text_base)) bfd_fatal("bfd_set_section_contents()");
	if (!bfd_set_section_contents(obfd, rodata_section, input_data+rodata_base-text_base, 0, data_base-rodata_base)) bfd_fatal("bfd_set_section_contents()");
	if (!bfd_set_section_contents(obfd, data_section, input_data+data_base-text_base, 0, bss_base-data_base)) bfd_fatal("bfd_set_section_contents()");

//	addsyms();
//	symtab[symcnt] = 0;
//	if (!bfd_set_symtab(obfd, symtab, symcnt)) bfd_fatal("bfd_set_symtab");
//		osections[i].section = section;
//		asection *section = bfd_make_section_with_flags(obfd, sections[i].name, sections[i].flags);
//		if (!section) bfd_fatal("bfd_make_section_with_flags");
//		bfd_set_section_vma(obfd, section, 0xc0008000);
//		if (!bfd_set_section_size(obfd, section, sections[i+1].addr-sections[i].addr)) bfd_fatal("bfd_set_section_size");
//		sections[i].section = section;
//	for (int i=0; sections[i].name; i++) {
//	}
//	if (!bfd_set_arch_mach(obfd, bfd_arch_arm, bfd_mach_arm_unknown+1)) bfd_fatal("bfd_set_arch_mach");

	if (!bfd_set_arch_mach(obfd, ainfo->arch, ainfo->mach)) bfd_fatal("bfd_set_arch_mach()");
	if (!bfd_close(obfd)) bfd_fatal("bfd_close()");

	// dump symbols.S
	if (symbol_fname)
		dump_kallsyms(symbol_fname);

	// dump ramdisk
	if (ramdisk_fname && initramfs_start) {
		FILE *f = fopen(ramdisk_fname, "w");
		if (!f) { fprintf(stderr, "fopen(%s) returned: %m\n", ramdisk_fname); exit(1); }
		if (fwrite(input_data+initramfs_start-text_base, initramfs_end-initramfs_start, 1, f) != 1) { fprintf(stderr, "fwrite(%s) returned: %m\n", ramdisk_fname); exit(1); }
		fclose(f);
	}

	return 0;
}
