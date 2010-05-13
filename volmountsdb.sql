DROP TABLE IF EXISTS mountpoint;
CREATE TABLE mountpoint (
	parent_volume_type		CHAR(2) NOT NULL default '', 
	parent_volume_name		CHAR(30) NOT NULL default '',
	parent_volume_id		INTEGER(9),
	parent_volume_group_id		INTEGER(9),		
	mountpoint_type			CHAR(1) NOT NULL default '',
	mountpoint_volume_name		CHAR(30) NOT NULL default '',
	mountpoint_relative_path	VARCHAR(128),
	mountpoint_cell			VARCHAR(30),
	lastseen			INTEGER(10),
	PRIMARY KEY (
		mountpoint_volume_name, 
		mountpoint_cell, 
		mountpoint_relative_path, 
		parent_volume_name
	)
) ENGINE=InnoDB;
