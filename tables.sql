
-- integration history (branch/merge/ignore)
create table integed (
    subject text not null,	-- what file this log refers to
    object  text not null,	-- file the record refers to in objective
    object_minrev int not null,	-- objective revisions range - lower bound
    object_maxrev int not null,	-- upper bound
    subject_minrev int not null, -- subject revision range - lower
    subject_maxrev int not null, -- upper
    int_type int not null CHECK (int_type BETWEEN 0 and 13),
    	     -- 0 = "merge from".
	     -- 1 = "merge into".
    	     -- 2 = "branch from".  The subject was originally the object
	     -- 3 = "branch into".  New file made at location
	     -- 4 = "copy from".  The subject got revisions from object
	     -- 5 = "copy info".  The object got revisions from subject
	     -- 6 = "ignored".  subject marked revisions from object as done
	     -- 7 = "ignored by".  object marked revisions from subject as done
	     -- 8 = "delete from".  ???
	     -- 9 = "delete into".  ???
	     -- 10 = "copy from".  ??? DUP ???
	     -- 11 = "copy into".  ???
	     -- 12 = "edit from"
	     -- 13 = "edit into"
    revision int not null	-- Change this occurred in
    --primary key (revision, subject, subject_maxrev, object, int_type)
);

-- we'll create these indexes after loading the data:
-- create index revision_idx on integed (revision);
-- create index subject_idx on integed (subject, subject_maxrev);
-- create index object_idx on integed (object, object_maxrev);

-- change master records
create table change (
    change int not null primary key,
    junk_change int,	-- this almost always contained the same value as
			-- 'change', or a dead revision.  The one time it
			-- referred to an extant revision, the change was
			-- described as "Some weirdness in the intgrate"
    who_host text,
    who_user text,
    change_time int, 	-- epoch time of change
    closed int,		-- whether this change is committed yet
    short_desc text     -- short description of change
);

-- change description table
create table change_desc (
       change INT not null primary key,
       description TEXT
);
-- constraints we'll be checking later
-- create foreign key constraint on desc(change) references change;

-- change inventories for revisions
create table revcx (
       change int not null,	-- change this occurred in
       depotpath text,		-- what changed
       primary key (change, depotpath),
       revision int,		-- new file revision (#number)
       change_type int CHECK (change_type BETWEEN 0 and 4)
       		   -- 0 = add       		      
       		   -- 1 = edit
       		   -- 2 = delete
		   -- 3 = branch
		   -- 4 = integrate
);

-- constraints we'll be checking later
-- create foreign key constraint on revcx(change) references change;
-- create unique index revision_to_change_idx on revcx(depotpath, revision);

-- detail on depot RCS files
create table rev (
       depotpath TEXT,
       revision INT,
       primary key (depotpath, revision),
       file_type INT,	-- type;
       		 -- 0 0000 0000 0000 - text
       		 -- 0 0010 0000 0000 - xtext (executable bit set)
       		 -- 0 0000 0010 0000 - ktext (euc type)
       		 -- 0 0010 0010 0000 - kxtext
       		 -- 0 0001 0000 0001 - ubinary
       		 -- 0 0001 0000 0011 - binary
       		 -- 0 0001 0000 0000 - binary+D
       		 -- 1 0000 0000 0001 - text+w
       		 -- 0 1101 0000 0011 - apple
       		 -- 0 0100 0000 0000 - symlink
       some_enum INT,
       change INT,
       useless_epoch1 INT,
       useless_epoch2 INT,
       revision_md5 TEXT,
       unknown INT,
       rcs_file TEXT,
       rcs_revision VARCHAR(10),
       checkout_type INT
);
-- create foreign key constraint on rev(change) references change;
-- create unique index rcs_file on rev(rcs_file, rcs_revision);

-- tags
create table label (
       tagname TEXT not null,
       depotpath TEXT not null,
       primary key (tagname, depotpath),
       revision int NOT NULL       
);

create table rev_blobs {
	depotpath TEXT not null,
	revision int not null,
	primary key (depotpath,revision) references rev,
	blobid char[40] not null
}
