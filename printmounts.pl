#!/usr/bin/env perl

use strict;

use lib '.';
use volmountsdb;

if (($ARGV[0] ne '-v' and $ARGV[0] ne '-p') || -z $ARGV[1] || -z $ARGV[2]) {
	print "Usage: printmounts -v|-p <volume> <basepath>\n\n";
	exit 1;
}

volmountsdb_init();

mounts_from_root_id(get_volume_id_by_name($ARGV[1]), $ARGV[2]);

if ($ARGV[0] eq '-p') {
	print_mountpoints_by_path();
} elsif ($ARGV[0] eq '-v') {
	print_mountpoints_by_vol();
}

