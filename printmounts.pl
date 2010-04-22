#!/usr/bin/env perl

use strict;

use lib '.';
use VolmountsDB;

if ($ARGV[0] ne '-v' and $ARGV[0] ne '-p') {
	print "Usage: printmounts -v|-p\n\n";
	exit 1;
}

my $db = VolmountsDB->new('dbuser', 'dbpass', 'dbhost', 'dbname', 'basepath');
if (!$db) {
	print "Failed to connect to database\n";
}

if ($ARGV[0] eq '-p') {
	$db->print_mountpoints_by_path();
} elsif ($ARGV[0] eq '-v') {
	$db->print_mountpoints_by_vol();
}

