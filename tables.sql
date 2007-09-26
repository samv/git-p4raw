-- lookup table - integration types
create table int_type (
    int_type int not null primary key,
    title text,
    description text
);

insert into int_type values
	(0, 'merge from',    'change copied from subj. to obj.'),
	(1, 'merge into',    'change copied from obj. to subj.'),
	(2, 'branch from',   'revision copied from obj. to subj.'),
	(3, 'branch into',   'revision copied from subj. to obj.'),
	(4, 'copy from',     'patch copied from obj. to subj ??'),
	(5, 'copy into',     'patch copied from subj. to obj ??'),
	(6, 'ignored',       'patch from obj. were ignored by subj.'),
	(7, 'ignored by',    'patch from subj. were ignored by obj.'),
	(8, 'delete from',   'patch marked reverted??'),
	(9, 'delete into',   'patch marked reverted??'),
	(10, 'copy2 from',   'copied, but in a different way??'),
	(11, 'copy2 into',   'copied, but in a different way??'),
	(12, 'edit from',    'patch picked but altered from obj to subj.'),
	(13, 'edit into',    'patch picked but altered from subj to obj.');

-- integration history (branch/merge/ignore)
create table integed (
    subject text not null,	-- what file this log refers to
    object  text not null,	-- file the record refers to in objective
    object_minrev int not null,	-- objective revisions range - lower bound
    object_maxrev int not null,	-- upper bound
    subject_minrev int not null, -- subject revision range - lower
    subject_maxrev int not null, -- upper
    int_type int not null references int_type,
    change int not null		-- Change this occurred in
    --primary key (revision, subject, subject_maxrev, object, int_type)
);

create table p4user (
    who_user text, -- username
    email text,    -- e-mail address
    junk text,     -- always empty?
    effective int, -- a guess.
    until int,     -- keep guessing.
    realname text, -- name in RL
    dunno1 text,   -- ???
    alwayzero1 int,-- ???
    dunno2 text,   -- ???
    alwayzero2 int -- ???
);

-- change master records
create table change (
    change int not null primary key,
    change_desc_id int,	-- this almost always contained the same value as
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
       change_desc_id INT not null primary key,
       description TEXT
);

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

-- detail on depot RCS files
create table rev (
       depotpath TEXT,
       revision INT,
       primary key (depotpath, revision),
       file_type INT,	-- type;
       		 -- 0 0000 0000 0000 - text
       		 -- 0 0010 0000 0000 - xtext (executable bit set)
       		 -- 0 0000 0010 0000 - ktext (keyword expansion)
       		 -- 0 0010 0010 0000 - kxtext
       		 -- 0 0001 0000 0001 - ubinary
       		 -- 0 0001 0000 0011 - binary
       		 -- 0 0001 0000 0000 - binary+D
       		 -- 1 0000 0000 0001 - text+w
       		 -- 0 1101 0000 0011 - apple
       		 -- 0 0100 0000 0000 - symlink
       rev_change_type INT,
       change INT NOT NULL,
       useless_epoch1 INT,
       useless_epoch2 INT,
       revision_md5 TEXT,
       unknown INT,
       rcs_file TEXT,
       rcs_revision VARCHAR(10),
       checkout_type INT
);
-- we ignore 'revdx'; doesn't look to be any useful information there.

-- tags
create table label (
       tagname TEXT not null,
       depotpath TEXT not null,
       primary key (tagname, depotpath),
       revision int NOT NULL       
);

-- mapping revisions to blob ID, or "0" x 40 if deleted
create table rev_blobs (
	depotpath TEXT not null,
	revision int not null,
	primary key (depotpath,revision),
	blobid char(40) not null
);
