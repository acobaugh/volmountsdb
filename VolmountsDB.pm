package VolmountsDB;

use DBI;

sub new {
	my ($class, $dbuser, $dbpass, $dbhost, $dbname, $basepath) = @_;
	my $self = {};
	
	bless ($self, $class);
	
	$self->{mounts_by_path} = ();
	$self->{mounts_by_vol} = ();
	$self->{basepath} = $basepath;

	$self->{dbh} = DBI->connect("DBI:mysql:database=$dbname;host=$dbhost", $dbuser, $dbpass);
	if (!$self->{dbh}) {
		printf "%s %s\n", $DBI::err, $DBI::errstr;
		return 0;
	}

	$self->refresh_mounts();

	return $self;
}

##
## cells
##
sub insert_cell {
	my $self = shift;
	my %existing_cells = $self->get_cells();
	if (!defined($existing_cells{$_[0]})) {
		$self->{dbh}->do("INSERT INTO cell (cell_name) VALUES (\"" .  $_[0] . "\")");
	}
}

sub get_cells {
	my $self = shift;
	my %return;
	my $sth = $self->{dbh}->prepare("SELECT cell_name,cell_id FROM cell");
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref) {
		$return{$ref->{'cell_name'}} = $ref->{'cell_id'};
	}
	return \%return;
}

sub get_cell_by_id {
	my $self = shift;
	my ($cell_id) = @_;
	my $sth = $self->{dbh}->prepare("SELECT cell_name FROM cell WHERE cell_id=$cell_id LIMIT 1");
	$sth->execute();
	my $ref = $sth->fetchrow_hashref();
	return $ref->{'cell_name'};
}

##
## voltypes
##
sub insert_voltype {
	my $self = shift;
	my %existing_voltypes = get_voltypes();
	if (!defined($existing_voltypes{$_[0]})) {
		$self->{dbh}->do("INSERT INTO voltype (voltype_name) VALUES (\"" .  $_[0] . "\")");
	}
}
sub get_voltypes {
	my $self = shift;
	my %return;
	$sth = $self->{dbh}->prepare("SELECT voltype_name,voltype_id FROM voltype");
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
	my $self = shift;
	my ($volume_id, $voltype_id, $volume_name, $cell_id) = @_;
	$self->{dbh}->do("INSERT INTO volume (volume_id, voltype_id, volume_name, cell_id) 
		VALUES ($volume_id, $voltype_id, '$volume_name', $cell_id) 
		ON DUPLICATE KEY UPDATE voltype_id=$voltype_id, volume_name='$volume_name'");
}

sub get_volume_id_by_name {
	my $self = shift;
	my ($volume_name) = @_;
	my $sth = $self->{dbh}->prepare("SELECT volume_id FROM volume WHERE volume_name='$volume_name' LIMIT 1");
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
	my $self = shift;
	my ($volume_name, $mountpoint_parent_id, $cell_id, $mountpoint_type, $mountpoint_path, $mountpoint_lastseen) = @_;
	$self->{dbh}->do("INSERT INTO mountpoint
		(volume_name, mountpoint_parent_id, cell_id, mountpoint_path, mountpoint_type, mountpoint_lastseen) 
		VALUES (\"$volume_name\", $mountpoint_parent_id, $cell_id, \"$mountpoint_path\", '$mountpoint_type', $mountpoint_lastseen) 
		ON DUPLICATE KEY UPDATE 
		mountpoint_type='$mountpoint_type', mountpoint_lastseen=$mountpoint_lastseen");
}

##
## walk mountpoints recursively, given root volume id, base path, and initial volume stack
##
sub walkmounts {
	my $self = shift;
	my ($root_volume_id, $path, %volstack) = @_;
	#my (%return_by_path, %return_by_vol);
	my $sth = $self->{dbh}->prepare("SELECT volume_name,mountpoint_path,mountpoint_type,cell_id FROM mountpoint 
		WHERE mountpoint_parent_id=$root_volume_id");
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref()) {
		my $thispath = $path . $ref->{'mountpoint_path'};
		$self->{mounts_by_path}{$thispath}{'mtpttype'} = $ref->{'mountpoint_type'};
		$self->{mounts_by_path}{$thispath}{'volname'} = $ref->{'volume_name'};
		$self->{mounts_by_path}{$thispath}{'cell'} = $self->get_cell_by_id($ref->{'cell_id'});

		$self->{mounts_by_vol}{$ref->{'volume_name'}}{'cell'} = $self->get_cell_by_id($ref->{'cell_id'});
		$self->{mounts_by_vol}{$ref->{'volume_name'}}{'paths'}{$thispath} = $ref->{'mountpoint_type'};

		my $volid = $self->get_volume_id_by_name($ref->{'volume_name'});
		if ($volid ne 0 and $volstack{$ref->{'volume_name'}} ne 1) {
			$volstack{$ref->{'volume_name'}} = 1;
			$self->walkmounts($volid, $thispath, %volstack);
		}
	}
	$sth->finish();
}

sub refresh_mounts {
	my $self = shift;
	$self->{mounts_by_path} = ();
	$self->{mounts_by_vol} = ();
	$self->walkmounts($self->get_volume_id_by_name('root.cell'), $self->{basepath}, ('root.cell', 'root.afs'));
}

##
## return mounts_by_path
##
# this is a hash that looks like this:
#
# $hash = (
#	/path/to/mountpoint = (
#		mtpttype = '#|%',
#		volname = 'name of volume',
#		cell = 'cell name'
#	)
#	...
# )
#
sub get_mounts_by_path {
	my $self = shift;
	return %{$self->{mounts_by_path}};
}

##
## return mounts_by_vol
##
# this is a hash that looks like this:
#
# %hash = (
#	volume_name = (
#		cell = 'name of cell',
#		paths = (
#			/path/to/mountpoint = '#|%',
#			...
#		)
#	)
#	...
# )
#
sub get_mounts_by_vol {
	my $self = shift;
	return %{$self->{mounts_by_vol}};
}

sub print_mountpoints_by_path {
	my $self = shift;
	my %by_path = $self->get_mounts_by_path();
	foreach (sort keys %by_path) {
		printf "%s|%s|%s|%s\n", 
			$_, $by_path{$_}{'mtpttype'}, $by_path{$_}{'volname'}, $by_path{$_}{'cell'};
	}
}

sub print_mountpoints_by_vol {
	my $self = shift;
	my %by_vol = $self->get_mounts_by_vol();
	foreach my $vol (sort keys %by_vol) {
		printf "%s|%s\n", $vol, $by_vol{$vol}{'cell'}; 
		foreach (sort keys %{$by_vol{$vol}{'paths'}}) {
			printf "\t%s %s\n", $by_vol{$vol}{'paths'}{$_}, $_;
		}
		print "\n";
	}
}

##
## prune mountpoints
##
sub prune_mountpoints {
	my $self = shift;
	my ($date) = @_;
	if ($date lt 0) {
		print "prune_mountpoints(): Must supply non-zero value.\n";
		return 0;
	}
	return $self->{dbh}->do("DELETE FROM mountpoint WHERE mountpoint_lastseen < $date");
}
##
## prune mountpoints
##
sub prune_volumes {
	my $self = shift;
	return $self->{dbh}->do("DELETE FROM volume  
		WHERE NOT EXISTS 
			(SELECT * FROM mountpoint WHERE volume.volume_name = mountpoint.volume_name)");
}

1;
