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

#	$self->refresh_mounts();

	return $self;
}

##
## mountpoints
##
sub insert_mountpoint($$$$$$$$$$) {
	my $self = shift;
	my ($parent_volume_type, $parent_volume_name, $parent_volume_id, $parent_volume_group_id,
		$mountpoint_volume_name, $mountpoint_cell, $mountpoint_type, $mountpoint_relative_path, $lastseen) = @_;
	$self->{dbh}->do("
		INSERT INTO mountpoint
			(parent_volume_type, parent_volume_name, parent_volume_id, parent_volume_group_id,
			mountpoint_volume_name, mountpoint_cell, mountpoint_type, mountpoint_relative_path, lastseen) 
		VALUES
			(\"$parent_volume_type\", \"$parent_volume_name\", \"$parent_volume_id\", \"$parent_volume_group_id\",
			\"$mountpoint_volume_name\", \"$mountpoint_cell\", \"$mountpoint_type\",
			\"$mountpoint_relative_path\", \"$lastseen\") 
		ON DUPLICATE KEY UPDATE 
			parent_volume_id=\"$parent_volume_id\", parent_volume_group_id=\"$parent_volume_group_id\", parent_volume_type=\"$parent_volume_type\",
			mountpoint_type=\"$mountpoint_type\", lastseen=\"$lastseen\"
		");
}

##
## walk mountpoints recursively, given root volume id, base path, and initial volume stack
##
sub walkmounts($$%) {
	my $self = shift;
	my ($root_volume_name, $path, %volstack) = @_;
	$volstack{$root_volume_name} = 1;
	my $sth = $self->{dbh}->prepare("SELECT * FROM mountpoint WHERE parent_volume_name='$root_volume_name'");
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref()) {
		my $thispath = $path . $ref->{'mountpoint_relative_path'};
		$self->{mounts_by_path}{$thispath}{'mtpttype'} = $ref->{'mountpoint_type'};
		$self->{mounts_by_path}{$thispath}{'volname'} = $ref->{'mountpoint_volume_name'};
		$self->{mounts_by_path}{$thispath}{'cell'} = $ref->{'mountpoint_cell'};

		$self->{mounts_by_vol}{$ref->{'mountpoint_volume_name'}}{'cell'} = $ref->{'mountpoint_cell'};
		$self->{mounts_by_vol}{$ref->{'mountpoint_volume_name'}}{'paths'}{$thispath} = $ref->{'mountpoint_type'};

		if ($volstack{$ref->{'mountpoint_volume_name'}} ne 1) {
			$self->walkmounts($ref->{'mountpoint_volume_name'}, $thispath, %volstack);
		}
	}
	$sth->finish();
}

sub fetch_mounts {
	my $self = shift;
	$self->{mounts_by_path} = ();
	$self->{mounts_by_vol} = ();
	$self->walkmounts('root.cell', $self->{basepath}, ('root.cell', 'root.afs'));
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
	return $self->{dbh}->do("DELETE FROM mountpoint WHERE lastseen < $date");
}

1;
