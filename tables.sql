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
	(10, 'edit into',    'patch picked but altered??'),
	(11, 'edit from',    'patch poked but altered??'),
	(12, 'edit from',    'patch picked but altered from obj to subj.'),
	(13, 'edit into',    'patch picked but altered from subj to obj.');

-- integration history (branch/merge/ignore)
create table integed (
    source_file text not null,
    subject text not null,	-- what file this log refers to
    object  text not null,	-- file the record refers to in objective
    object_minrev int not null,	-- objective revisions range - lower bound
    object_maxrev int not null,	-- upper bound
    subject_minrev int not null, -- subject revision range - lower
    subject_maxrev int not null, -- upper
    int_type int not null references int_type,
    change int not null,	-- Change this occurred in
    primary key (change, subject, subject_maxrev, object, object_maxrev)
);

create table p4user (
    source_file text not null,
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
    source_file text not null,
    change int not null primary key,
    change_desc_id int,	-- this almost always contained the same value as
			-- 'change', or a dead revision.  The one time it
			-- referred to an extant revision, the change was
			-- described as "Some weirdness in the intgrate"
    who_host text,
    who_user text,
    change_time int, 	-- epoch time of change
    closed int,		-- whether this change is committed yet jjjjjjj
    short_desc text     -- short description of change
);

-- change description table
create table change_desc (
    source_file text not null,
       change_desc_id INT not null primary key,
       description TEXT
);

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
    source_file text not null,
       change int not null,	-- change this occurred in
       depotpath text,		-- what changed
       primary key (change, depotpath),
       revision int,		-- new file revision (#number)
       change_type int REFERENCES change_type
);



-- detail on depot RCS files
create table rev (
    source_file text not null,
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
    source_file text not null,
       tagname TEXT not null,
       depotpath TEXT not null,
       primary key (tagname, depotpath),
       revision int NOT NULL       
);

-- this table holds the marks that we send to git fast-import
create sequence gfi_mark;
create table marks (
    source_file text not null default 'new',
	mark int not null primary key,
	commitid char(40) null,
	blobid char(40) null,
	CHECK (
		(commitid is not null) OR
		(blobid is not null)
	)
);

-- mapping file revisions to marks - join with marks to get blobids
create table rev_marks (
    source_file text not null default 'new',
	depotpath TEXT not null,
	revision int not null,
	primary key (depotpath,revision),
	mark int not null references marks DEFERRABLE INITIALLY DEFERRED
);

-- what branches we determined exist along the way
create table change_branches (
    source_file text not null default 'new',
       branchpath TEXT not null,
       change INT null,
       primary key (branchpath, change)
);

-- mapping changes to branches and marks - join with marks to get
-- commitids
create table change_marks (
    source_file text not null default 'new',
	branchpath TEXT not null,
	change int not null,
	primary key (branchpath, change),
	mark int not null references marks DEFERRABLE INITIALLY DEFERRED,
	unique (mark)
);

-- parentage of changes
create table change_parents (
    source_file text not null default 'new',
	branchpath TEXT not null,
	change int not null,

	parent_branchpath TEXT null,
	parent_change int null,

	ref TEXT null,
	manual boolean NOT NULL default true,
	all_headrev boolean NULL,
	none_unseen boolean NULL,
	octopus boolean NOT NULL DEFAULT false,
	evil boolean NOT NULL default false,

	CHECK (
		((parent_change is not null and parent_branchpath is not null)
		 AND
		 (ref is null))
	OR	((parent_change is null and parent_branchpath is null)
		 AND
		 (ref is not null))
	),

	-- zomg no .. he's not going to put JSON in there is he?
	json_info TEXT
);

-- TODO create language 'plperl';

-- this is a memoization that will be important.
-- TODOcreate table merge_bases (	
-- TODO	left_branch TEXT not null,
-- TODO	left_change int not null,
-- TODO	foreign key (branchpath, change)
-- TODO		references change_branches (branchpath,change)
-- TODO		on delete cascade,
-- TODO	
-- TODO	right_branch TEXT not null,
-- TODO	right_change int not null,
-- TODO	foreign key (branchpath, change)
-- TODO		references change_branches (branchpath,change)
-- TODO		on delete cascade,
-- TODO	
-- TODO	base_branch TEXT not null,
-- TODO	base_change int not null,
-- TODO	foreign key (branchpath, change)
-- TODO		references change_branches (branchpath,change)
-- TODO		on delete cascade,
-- TODO
-- TODO	CHECK (
-- TODO		CASE WHEN
-- TODO			(left_change = right_change)
-- TODO		THEN 
-- TODO			(left_branch < right_branch)
-- TODO		ELSE
-- TODO			(left_change < right_change)
-- TODO		END
-- TODO	),
-- TODO	CHECK (
-- TODO		base_change <= right_change or
-- TODO		base_change <= left_change
-- TODO	)
-- TODO);
-- TODO
-- TODOcreate function find_merge_base(text, int, text, int) returns bool AS $$
-- TODO	my ($left_bp, $left_chg, $right_bp, $right_chg) = @_;
-- TODO
-- TODO	my $sth = spi_prepare
-- TODO		("select * from change_parents where "
-- TODO       		."branchpath = ? and change = ? order by manual desc");
-- TODO	
-- TODO	my @start = map { join '@', @$_ }
-- TODO		[$left_bp,$left_chg], [$right_bp, $right_chg];
-- TODO
-- TODO$$ language 'plperl';
-- TODO
-- TODOcreate function find_merge_branch(text, int, text, int) returns text AS $$
-- TODO
-- TODO
-- TODO$$ language 'plperl';
-- TODO
-- TODOcreate function find_merge_branch(text, int, text, int) returns text AS $$
-- TODO
-- TODO
-- TODO$$ language 'plperl';
