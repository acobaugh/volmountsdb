DROP TABLE IF EXISTS volume;
CREATE TABLE volume (
	volume_id	INTEGER(9) PRIMARY KEY,
	volume_name	CHAR(30) NOT NULL default '',
	voltype_id	TINYINT(1),
	cell_id		INTEGER(2)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS voltype;
CREATE TABLE voltype (
	voltype_id	TINYINT(1) auto_increment PRIMARY KEY,
	voltype_name	CHAR(2) NOT NULL default ''
) ENGINE=InnoDB;

DROP TABLE IF EXISTS mountpoint;
CREATE TABLE mountpoint (
	mountpoint_parent_id	INTEGER(9),
	mountpoint_path		VARCHAR(128),
	mountpoint_type		CHAR(1) NOT NULL default '',
	mountpoint_lastseen	INTEGER(10),
	volume_name		CHAR(30) NOT NULL default '',
	cell_id			INTEGER(2),
	PRIMARY KEY (volume_name, cell_id, mountpoint_path)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS cell;
CREATE TABLE cell (
	cell_id		INTEGER(2) auto_increment PRIMARY KEY,
	cell_name	VARCHAR(255) UNIQUE,
	INDEX cell_index (cell_name)
) ENGINE=InnoDB;
