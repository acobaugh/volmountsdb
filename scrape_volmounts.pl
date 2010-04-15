#!/usr/bin/env perl

use warnings;
use strict;

use lib '.';
use volmountsdb;

volmountsdb_init();

my @volskip = ('root.afs', 'root.afs.readonly');
# output format of volmounts:
# volume type|volume name|volume id|parent volume id|vnode id|uniquifier|dataVersion|mount point|relative path
# 1 = volume type
# 2 = volume name
# 3 = volume id
# 4 = parent volume id
# 5 = vnode id
# 6 = uniquifier
# 7 = DV
# 8 = mount point
# 9 = relative path

my $wscell = `fs wscell 2>&1`;
$wscell =~ s/.*'(.*)'\n/$1/;

my $cells = get_cells;
my $voltypes = get_voltypes;

while (<STDIN>) {
	next if m/Processing Partition/;
	next if m/volume type/;
	s/\n//;
	my @a = split(/\|/, $_);
	
	my $mtpt = $a[7];
	
	$mtpt =~ s/(%|#)(.+)/$2/;
	my $mtpttype = $1;

	my $mtptcell = '';
	$mtpt =~ m/(.+:)?(.*)/;
	$mtptcell = $1;
	my $mtptvol = $2;

	next if (grep $_ eq $mtptvol || $_ eq $a[1], @volskip);

	if (!$mtptcell) {
		$mtptcell = $wscell;
	}

	my $voltype = $a[0];
	my $volname = $a[1];
	my $volid = $a[2];
	my $pvolid = $a[3];
	my $mtptpath = $a[8];

	printf "%s ; type = %s ; name = %s ; id = %s ; pid = %s ; mtptvol = %s ; mtptcell = %s ; mtpttype = %s ; mtptpath = %s\n",
		time, $voltype, $volname, $volid, $pvolid, $mtptvol, $mtptcell, $mtpttype, $mtptpath;
	
	if (!defined($cells->{$mtptcell})) {
		insert_cell($mtptcell);
		$cells = get_cells;
	}
	if (!defined($voltypes->{$voltype})) {
		insert_voltype($voltype);
		$voltypes = get_voltypes;
	}
	insert_volume($volid, $voltypes->{$a[0]}, $volname, $cells->{$mtptcell});
	insert_mountpoint($mtptvol, $pvolid, $cells->{$mtptcell}, $mtpttype, $mtptpath, time);
	
}





