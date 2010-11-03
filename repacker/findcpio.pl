#!/usr/bin/perl
#
# search for cpio archive in a file, and output start/end offsets.
#
# usage:
#   findcpio.pl filename [start_offset]
#
# to search cpio in "filename", where [start_offset] is optional
#

use constant CPIO_HEADER => "070701";

sub find_cpio_begin {
	local ($data, $n, $offset);
	$n=1;
	$offset=$_[0];
	seek(FILE, $offset, 0);
	while (	$n=read FILE, $data, 1024*256) {
		$offset=index $data, CPIO_HEADER, 0;
		return $offset if $offset!=-1;
	}
	return -1;
}

sub scan_cpio {
	local ($start, $offset, $filesize, $namesize, $filename, $data, $mod);
	$offset=$_[0];
	while (1) {
		$start=$offset;
		$offset+=54;
		seek(FILE, $offset, 0);
		$n=read FILE, $filesize, 8;
		$filesize=hex($filesize);
		$offset+=40;
		seek(FILE, $offset, 0);
		$n=read FILE, $namesize, 8;
		$namesize=hex($namesize);
		$offset+=16;
		seek(FILE, $offset, 0);
		$n=read FILE, $filename, $namesize;
		$offset+=$namesize;
		# we need to align the $offset
		$mod = $offset % 4;
		$offset+=4-$mod if ($mod != 0);
		$offset+=$filesize;
		# we need to align the $offset
		$mod = $offset % 4;
		$offset+=4-$mod if ($mod != 0);

		#printf "0x%08x - 0x%08x %s\n",$start, $offset, $filename;
		seek(FILE, $offset, 0);
		$n=read FILE, $data, 6;
		return ($offset) if $data!=CPIO_HEADER;
	}
}

$file=@ARGV[0];
if (length($file)==0)
   {print "Invalid input file!\n"; die ;}

open FILE, $file or die $!;
my ($start,$end);
# default $start is 0 if no arg is provided
$start=@ARGV[1];
$start=find_cpio_begin($start);
exit 1 if $start==-1;
$end=scan_cpio($start);
close(FILE);
#printf "0x%08x\t0x%08x\n",$start,$end;
printf "%d\t%d\t%d\n",$start,$end,$end-$start;


