#!/usr/bin/env perl

use warnings;
use strict;
use Fcntl qw(:flock);

# make sure we're the only instance running on this machine
open(SELF, "<", $0) or die "Cannot open $0 - $!";
flock(SELF, LOCK_EX|LOCK_NB) or die "$0 - Already running.";

use VolmountsDB;

my $vdb = VolmountsDB->new('dbuser', 'dbpass', 'dbhost', 'dbname', 'basepath');
if (!$vdb) {
	print "Failed to initiated VolmountsDB\n";
	exit 1;
}

# volumes to skip
my @volskip = ();

# output format of volmounts:
# volume type|volume name|volume id|parent volume id|vnode id|uniquifier|dataVersion|mount point|relative path

# 0 = volume type
# 1 = volume name
# 2 = volume id
# 3 = parent volume id
# 4 = vnode id
# 5 = uniquifier
# 6 = DV
# 7 = mount point
# 8 = relative path

my $wscell = `fs wscell 2>&1`;
$wscell =~ s/.*'(.*)'\n/$1/;

while (<STDIN>) {
	next if m/Processing Partition/;
	next if m/volume type/;
	s/\n//;
	my @a = split(/\|/, $_);
	
	my $mtpt = $a[7];
	
	$mtpt =~ s/(%|#)(.+)/$2/;
	my $mtpt_type = $1;

	my $mtpt_cell = '';
	$mtpt =~ m/(.+:)?(.*)/;
	$mtpt_cell = $1;
	my $mtpt_vol_name = $2;

	next if (grep $_ eq $mtpt_vol_name || $_ eq $a[1], @volskip);

	if (!$mtpt_cell) {
		$mtpt_cell = $wscell;
	}

	my $p_vol_type = $a[0];
	my $p_vol_name = $a[1];
	my $p_vol_id = $a[2];
	my $p_volgroup_id = $a[3];
	my $mtpt_rel_path = $a[8];

	printf "%s ; p_vol_type = %s ; p_vol_name = %s ; p_vol_id = %s ; p_volgroup_id = %s ; mtpt_vol_name = %s ; mtpt_cell = %s ; mtpt_type = %s ; mtpt_rel_path = %s\n",
		time, $p_vol_type, $p_vol_name, $p_vol_id, $p_volgroup_id, $mtpt_vol_name, $mtpt_cell, $mtpt_type, $mtpt_rel_path;
	
	$vdb->insert_mountpoint($p_vol_type, $p_vol_name, $p_vol_id, $p_volgroup_id, $mtpt_vol_name, $mtpt_cell, $mtpt_type, $mtpt_rel_path, time);
}





