package volmountsdb;

use base 'Exporter';
use DBI;

our @EXPORT = qw(
	volmountsdb_init 
	insert_cell 
	get_cells 
	insert_voltype 
	get_voltypes 
	insert_volume 
	insert_mountpoint
	get_volume_id_by_name
	mounts_from_root_id
	print_mountpoints_by_path
	print_mountpoints_by_vol
);


my $dbh;
my %mounts_by_path = ();
my %mounts_by_vol = ();

##
## initialize connection to db
##
sub volmountsdb_init {
	my ($dbuser, $dbpass, $dbhost, $dbname) = @_;
	$dbh = DBI->connect("DBI:mysql:database=$dbname;host=$dbhost",
		$dbuser, $dbpass) or die "Can't connect to DB\n";
}

##
## cells
##
sub insert_cell {
	my %existing_cells = get_cells();
	if (!defined($existing_cells{$_[0]})) {
		$dbh->do("INSERT INTO cell (cell_name) VALUES (\"" .  $_[0] . "\")");
	}
}

sub get_cells {
	my %return;
	my $sth = $dbh->prepare("SELECT cell_name,cell_id FROM cell");
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref) {
		$return{$ref->{'cell_name'}} = $ref->{'cell_id'};
	}
	return \%return;
}

sub get_cell_by_id {
	my ($cell_id) = @_;
	my $sth = $dbh->prepare("SELECT cell_name FROM cell WHERE cell_id=$cell_id LIMIT 1");
	$sth->execute();
	my $ref = $sth->fetchrow_hashref();
	return $ref->{'cell_name'};
}

##
## voltypes
##
sub insert_voltype {
	my %existing_voltypes = get_voltypes();
	if (!defined($existing_voltypes{$_[0]})) {
		$dbh->do("INSERT INTO voltype (voltype_name) VALUES (\"" .  $_[0] . "\")");
	}
}
sub get_voltypes {
	my %return;
	$sth = $dbh->prepare("SELECT voltype_name,voltype_id FROM voltype");
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref) {
		$return{$ref->{'voltype_name'}} = $ref->{'voltype_id'};
	}
	return \%return;
}

##
## volumes
##
sub insert_volume {
	my ($volume_id, $voltype_id, $volume_name, $cell_id) = @_;
	$dbh->do("INSERT INTO volume (volume_id, voltype_id, volume_name, cell_id) 
		VALUES ($volume_id, $voltype_id, '$volume_name', $cell_id) 
		ON DUPLICATE KEY UPDATE voltype_id=$voltype_id, volume_name='$volume_name'");
}

sub get_volume_id_by_name {
	my ($volume_name) = @_;
	my $sth = $dbh->prepare("SELECT volume_id FROM volume WHERE volume_name='$volume_name' LIMIT 1");
	$sth->execute();
	if (my $ref = $sth->fetchrow_hashref()) {
		$sth->finish();
		return $ref->{'volume_id'};
	} else {
		$sth->finish();
		return 0;
	}
}

##
## mountpoints
##
sub insert_mountpoint {
	my ($volume_name, $mountpoint_parent_id, $cell_id, $mountpoint_type, $mountpoint_path, $mountpoint_lastseen) = @_;
	$dbh->do("INSERT INTO mountpoint
		(volume_name, mountpoint_parent_id, cell_id, mountpoint_path, mountpoint_type, mountpoint_lastseen) 
		VALUES (\"$volume_name\", $mountpoint_parent_id, $cell_id, \"$mountpoint_path\", '$mountpoint_type', $mountpoint_lastseen) 
		ON DUPLICATE KEY UPDATE 
		mountpoint_type='$mountpoint_type', mountpoint_lastseen=$mountpoint_lastseen");
}

sub mounts_from_root_id {
	my ($root_volume_id, $path) = @_;
	#my (%return_by_path, %return_by_vol);
	my $sth = $dbh->prepare("SELECT volume_name,mountpoint_path,mountpoint_type,cell_id FROM mountpoint 
		WHERE mountpoint_parent_id=$root_volume_id");
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref()) {
		my $thispath = $path . $ref->{'mountpoint_path'};
		
		$mounts_by_path{$thispath}{'mtpttype'} = $ref->{'mountpoint_type'};
		$mounts_by_path{$thispath}{'volname'} = $ref->{'volume_name'};
		$mounts_by_path{$thispath}{'cell'} = get_cell_by_id($ref->{'cell_id'});

		$mounts_by_vol{$ref->{'volume_name'}}{'cell'} = get_cell_by_id($ref->{'cell_id'});
		$mounts_by_vol{$ref->{'volume_name'}}{'mounts'}{$thispath} = $ref->{'mountpoint_type'};

		my $volid = get_volume_id_by_name($ref->{'volume_name'});
		if ($volid ne 0) {
			mounts_from_root_id($volid, $thispath);
		}
	}
	$sth->finish();
}

sub init_mounts {
	%mounts_by_path = ();
	%mounts_by_vol = ();
}

sub get_mounts_by_path {
	return %mounts_by_path;
}

sub get_mounts_by_vol {
	return %mounts_by_vol;
}

sub print_mountpoints_by_path {
	my %by_path = get_mounts_by_path();
	foreach (sort keys %by_path) {
		printf "%s|%s|%s|%s\n", 
			$_, $by_path{$_}{'mtpttype'}, $by_path{$_}{'volname'}, $by_path{$_}{'cell'};
	}
}

sub print_mountpoints_by_vol {
	my %by_vol = get_mounts_by_vol();
	foreach my $vol (sort keys %by_vol) {
		printf "%s|%s\n", $vol, $by_vol{$vol}{'cell'}; 
		foreach (sort keys %{$by_vol{$vol}{'mounts'}}) {
			printf "\t%s %s\n", $by_vol{$vol}{'mounts'}{$_}, $_;
		}
		print "\n";
	}
}

##
## prune mountpoints
##
sub prune_mountpoints {
	my ($date) = @_;
	$dbh->do("DELETE FROM mountpoint WHERE lastseen < $date");
}
##
## prune mountpoints
##
sub prune_volumes {
	$dbh->do("DELETE FROM volume  
		WHERE NOT EXISTS 
			(SELECT * FROM mountpoint WHERE volume.volume_name = mountpoint.volume_name)");
}

1;
