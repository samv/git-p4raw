
-- checking all change number references are valid
alter table rev add constraint rev_change_valid
      foreign key (change) references change;

alter table revcx add constraint revcx_change_valid
      foreign key (change) references change;

alter table change_commits add constraint change_commits_change_valid
      foreign key (change) references change;

-- checking all change description references are unique
create unique index change_desc_idx on change(change_desc_id);

-- these change descriptions don't correspond to any change:
select * from change_desc where not exists
       (select * from change where change.change_desc_id = change_desc.change_desc_id);

-- checking all depotpaths + revnums are valid
alter table revcx add constraint revcx_depot_rev_valid
      foreign key (depotpath, revision) references rev;
alter table rev_blobs add constraint rev_blobs_depot_rev_valid
      foreign key (depotpath,revision) references rev;

-- set up safety constraints for later additions
alter table change_commits add constraint change_commits_branch_valid
      foreign key (branchpath) references branches;
alter table branches add constraint change_commits_branchpoint_valid
      foreign key(sourcebranch,revision) references change_commits(branchpath, change);

-- create indexes
create index integed_change_idx on integed (change);
create index integed_subject_idx on integed (subject, subject_maxrev);
create index integed_object_idx on integed (object, object_maxrev);
create index rev_rcs_file on rev(rcs_file, rcs_revision);
create index change_commits_chg_idx on change_commits(change);

-- these users made changes, but don't exist in the users table:
-- FOUND: add_p4users
select
	c.who_user,
	count(c.change) as changes
from
	change c
	left join p4user u
		using (who_user)
where
	u.who_user is null
group by
	c.who_user;

-- checking all change number references are valid
alter table change add constraint change_who_user_valid
      foreign key (who_user) references p4user;

-- the 'integed' table is denormalised, with rows normally appearing
-- in pairs.  However, these rows were missing their partners:
select								      
	i1.change,
	i1.subject || '#' || i1.subject_minrev || ',' || i1.subject_maxrev,
	int_type.title,
	i1.object || '#' || i1.object_minrev || ',' || i1.object_maxrev
from
	integed i1
	inner join int_type
		using (int_type)
	left join integed i2
		on (i1.subject = i2.object and
		       i1.subject_maxrev = i2.object_maxrev)
where
	i2.object is null
order by
	i1.change;

-- normally, if a 'revcx' row has type 4 = 'integrate', there is a
-- corresponding row (or row pair) in the 'integed' table.  These
-- integration records have forgotten (or never knew) what they
-- integrated:
select
	r.change,
	r.depotpath || '#' || r.revision
from
	revcx r
	left join integed i
		on (i.change = r.change and
			(i.subject = r.depotpath or i.object = r.depotpath))
where
	i.change is null and
	r.change_type = 4
order by
	r.change;
