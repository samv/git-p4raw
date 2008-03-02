-- git-p4raw state

-- Note that the order of columns in here is important; it must match
-- the Perforce checkpoint/journal format.

-- tag every row with a source file, but factor these out
create table source_filename (
    source_file_id serial primary key,
    source_file text
);

create table source_file (
    source_file_id  integer,
    source_file_max integer
);

-- lookup table - integration types
create table int_type (
    int_type int not null primary key,
    title text,
    description text
);
  
-- some integration types which I have yet to fully decypher; however,
-- I considered their variation relatively disinteresting historically
-- as it is derivable.  So, these are for display and possible use as
-- comments as seen fit.
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
	(10, 'edit into',    'patch picked but altered??'),
	(11, 'edit from',    'patch poked but altered??'),
	(12, 'edit from',    'patch picked but altered from obj to subj.'),
	(13, 'edit into',    'patch picked but altered from subj to obj.');

-- integration history (branch/merge/ignore)
--
-- This is the meat of the metadata, really.  We index 12 distinct
-- varieties of crap out of this once it's loaded, and end up querying
-- it a lot.
create table integed (
    subject text not null,	-- what file this log refers to
    object  text not null,	-- file the record refers to in objective
    object_minrev int not null,	-- objective revisions range - lower bound
    object_maxrev int not null,	-- upper bound
    subject_minrev int not null, -- subject revision range - lower
    subject_maxrev int not null, -- upper
    int_type int not null references int_type,
    change int not null,	-- Change this occurred in
    primary key (change, subject, subject_maxrev, object, object_maxrev)
) inherits (source_file);

-- users.  This is easily supplanted with a 'p4raw-extra-users.csv' if
-- seen fit.
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
) inherits (source_file);

-- A row in each of these for the change
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
) inherits (source_file);

-- change description table
create table change_desc (
       change_desc_id INT not null primary key,
       description TEXT
) inherits (source_file);

-- change types
create table change_type (
    change_type int not null primary key,
    title text,
    description text
);

insert into change_type values
	(0, 'add',       'File added to repository'),
	(1, 'edit',      'File modified'),
	(2, 'delete',    'File removed'),
	(3, 'branch',    'File copied from another location'),
	(4, 'integrate', 'File metadata and/or contents changed');

-- change inventories for revisions
create table revcx (
       change int not null,	-- change this occurred in
       depotpath text,		-- what changed
       primary key (change, depotpath),
       revision int,		-- new file revision (#number)
       change_type int REFERENCES change_type
) inherits (source_file);

-- p4 also has a revdx, revhx which presumably correspond to many of
-- the indexes that we create (see constraints.sql), as their data
-- does not appear in the checkpoints or journal files.

-- detail on depot RCS files
create table rev (
       depotpath TEXT,
       revision INT,
       primary key (depotpath, revision),
       file_type INT,	-- type; generally ignored by this tool, save execute
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
       useless_epoch1 INT, -- who cares :)
       useless_epoch2 INT,
       revision_md5 TEXT,
       unknown INT,
       rcs_file TEXT,
       rcs_revision VARCHAR(10),
       checkout_type INT   -- this name is a guess.
) inherits (source_file);

-- tags
create table label (
       tagname TEXT not null,
       depotpath TEXT not null,
       primary key (tagname, depotpath),
       revision int NOT NULL       
) inherits (source_file);

-- this table holds the marks that we send to git fast-import
create sequence gfi_mark;
create table marks (
	mark int not null primary key,
	commitid char(40) null,
	blobid char(40) null,
	CHECK (
		(commitid is not null) OR
		(blobid is not null)
	)
) inherits (source_file);

-- this table obviously lists the "depots", but this tool doesn't
-- currently do much sensible with this information.
create table depot (
	depot TEXT not null primary key,
	num1 int not null,
	string1 text,
	pathspec text
) inherits (source_file);

-- mapping file revisions to marks - join with marks to get blobids
create table rev_marks (
	depotpath TEXT not null,
	revision int not null,
	primary key (depotpath,revision),
	mark int not null references marks DEFERRABLE INITIALLY DEFERRED
) inherits (source_file);

-- what branches we determined exist along the way
create table change_branches (
       branchpath TEXT not null,
       change INT null,
       primary key (branchpath, change)
) inherits (source_file);

-- mapping changes to branches and marks - join with marks to get
-- commitids
create table change_marks (
	branchpath TEXT not null,
	change int not null,
	primary key (branchpath, change),
	mark int not null references marks DEFERRABLE INITIALLY DEFERRED
	-- unique (mark)
) inherits (source_file);

-- parentage of changes.  There are actually two types of fact
-- disguised in this one table.  I don't use inheritance because Pg's
-- inherited tables don't inherit constraints!
create table change_parents (
	branchpath TEXT not null,
	change int not null,

	-- a parent exists of a branchpath/change,
	parent_branchpath TEXT null,
	parent_change int null,

	-- OR an explicit reference is given (anything that will 'git
	-- rev-parse')
	ref TEXT null,

	-- enforce this rule
	CHECK (
		((parent_change is not null and parent_branchpath is not null)
		 AND
		 (ref is null))
	OR	((parent_change is null and parent_branchpath is null)
		 AND
		 (ref is not null))
	),

	-- presence of data in this column invalidates all the rows
	-- that don't have it.  This hack should be do-away-able once
	-- "p4raw dump" knows how to save row deletes.
	manual boolean NOT NULL default true,

	-- These were all information which was derived, and should be
	-- removed.
	all_headrev boolean NULL,
	none_unseen boolean NULL,
	octopus boolean NOT NULL DEFAULT false,
	evil boolean NOT NULL default false,
	json_info text

) inherits (source_file);
