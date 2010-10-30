#!/usr/bin/perl

$file=@ARGV[0];
if (length($file)==0)
   {print "Invalid input file!\n"; die ;}

open FILE, $file or die $!;
binmode FILE;
my ($data, $n, $offset, $found);
$offset=0;
$found=0;
while (
  $n=read FILE, $data, 4
  and $found < 4
) {$offset+=4; if (unpack("I", $data)==0) {$found+=1;} else {$found=0;}}
print "$offset\t";
while (
  $n=read FILE, $data, 4
  and unpack("I", $data)==0
) {$offset+=4;}
print "$offset \n";
close(FILE);

