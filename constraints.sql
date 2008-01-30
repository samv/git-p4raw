
-- adding constraints pertaining to datafile load state
alter table source_file add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;

-- *sigh* and the rest
alter table integed add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table p4user add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table change add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table change_desc add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table revcx add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table rev add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table label add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table marks add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table depot add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table rev_marks add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table change_branches add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table change_marks add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;
alter table change_parents add constraint source_file_id_valid
      foreign key (source_file_id) references source_filename;

-- checking all change number references are valid
alter table rev add constraint rev_change_valid
      foreign key (change) references change deferrable;

alter table revcx add constraint revcx_change_valid
      foreign key (change) references change deferrable;

alter table change_branches add constraint change_branches_change_valid
      foreign key (change) references change deferrable;

-- p4users primary key
alter table p4user
      add primary key (who_user);

-- checking all change description references are unique
create unique index change_desc_idx on change(change_desc_id);

-- these change descriptions don't correspond to any change:
select * from change_desc where not exists
       (select * from change where change.change_desc_id = change_desc.change_desc_id);

-- checking all depotpaths + revnums are valid
alter table revcx add constraint revcx_depot_rev_valid
      foreign key (depotpath, revision) references rev deferrable;
alter table rev_marks add constraint rev_marks_depot_rev_valid
      foreign key (depotpath,revision) references rev deferrable;

-- set up safety constraints for later additions
alter table change_marks add constraint change_marks_branch_valid
      foreign key (branchpath,change) references change_branches deferrable;

create unique index change_parents_unique on change_parents
	(branchpath,change,parent_branchpath,parent_change,ref);
alter table change_parents add constraint change_branchpath_valid
      foreign key (branchpath,change)
      references change_branches deferrable;
alter table change_parents add constraint change_parents_valid
      foreign key (parent_branchpath, parent_change)
      references change_branches(branchpath, change) deferrable;
create unique index change_parents_sanity
       on change_parents(change, branchpath, parent_branchpath,
       parent_change, manual);

-- create indexes:
create index integed_change_idx on integed (change);
create index integed_subject_idx on integed (subject, subject_maxrev);
create index integed_object_idx on integed (object, object_maxrev);
create index rev_rcs_file on rev(rcs_file, rcs_revision);
create index rev_change on rev(change);
create index change_marks_chg_idx on change_marks(change);
create index change_parents_idx on change_parents(branchpath, change);

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
      foreign key (who_user) references p4user deferrable;

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

-- all revisions which are of type 'delete' should have revision MD5
-- of 0000..0000.  These ones don't:
select
	*
from
	rev
where
	rev_change_type = 2 and
	revision_md5 != '00000000000000000000000000000000';

-- all revisions should be MD5 checksummed.  This many aren't:
-- ONEROW
select
	count(*) as count_no_md5
from
	rev
where
	rev_change_type != 2 and
	revision_md5 = '00000000000000000000000000000000';

-- create some views that are used by later methods
create view revcx_path
as
select
	revcx.depotpath,
	revcx.revision,
	revcx.change,
	change_type.title as change_type,
	rev.file_type,
	change.change_time,
        change.who_user,
	change.who_host,
        change.short_desc,
	p4user.realname,
	p4user.email
from
        revcx
        inner join change_type
                using (change_type)
        left join rev
                using (depotpath,revision)
        left join change
                on (revcx.change = change.change)
        left join p4user
                using (who_user);

create or replace view revcx_integed
as
select
	-- basic stuff
	r.change,
	r.depotpath,
	r.revision,
	r.change_type,
	rev_marks.mark,
	marks.blobid,
	rev.file_type,

	-- any integration records for this change.
	int_obj.subject as int_obj,
	int_obj.int_type as int_obj_type,
	int_obj.title as int_obj_title,

	int_obj.object_minrev as int_obj_min,
	int_obj.object_maxrev as int_obj_max,

	int_obj.subject_minrev as int_subj_min,
	int_obj.subject_maxrev as int_subj_max,

	int_subj_min.change as int_subj_min_change,
	int_subj_max.change as int_subj_max_change,

	-- in order to detect cross-branch merging, we need to know
        -- the latest change which affected the source of a
        -- merged-in path
	not exists
		(select change
		 from	rev
		 where	depotpath = int_obj.subject and
			rev.change > int_subj_max.change and
			rev.change <= r.change
		) as int_subj_headrev

from
	revcx r
	left join rev
		using (depotpath, revision)
	left join rev_marks
		using (depotpath, revision)
	left join marks
		using (mark)
	left join
		(select
			*
		from
			integed
			inner join int_type
				using (int_type)
		) int_obj
		on (r.depotpath = int_obj.object and
			int_obj.change = r.change)
	left join rev int_subj_min
		on (int_subj_min.depotpath    = int_obj.subject  and
			int_subj_min.revision = int_obj.subject_minrev)
	left join rev int_subj_max
		on (int_subj_max.depotpath    = int_obj.subject  and
			int_subj_max.revision = int_obj.subject_maxrev);

-- this view will return the contents of a change
create or replace view change_state
as
select
	c.change,
	r.depotpath,
	r.revision,
	r.change as last_change,
	r.file_type,
	r.revision_md5,
        r.rcs_file,
        r.rcs_revision
from
	change c,
	rev r
where
	r.change <= c.change AND
	not exists (select * from rev r2
	    	    where r2.revision > r.revision
		    and r2.change <= c.change
	    	    and r.depotpath = r2.depotpath) AND
	r.revision_md5 != '00000000000000000000000000000000'

