
/*
 * Example & Tests
create table testtable
(
  id int
  , path1 text
  , path2 text
  , change int
);
insert into testtable values ( 1, '//depot/one','//depot/one', 10);
insert into testtable values ( 1, '//depot/two','//depot/three', 100);
alter table testtable alter column path1 type integer using create_or_find_depotpaths(path1);

alter table testtable alter column path2 type integer;
insert into testtable values ( 2, '//depot/one/two/three','//depot/one/2/3', 10);
insert into testtable values ( 2, '//depot/two/three','//depot/three/2/3', 100);
*/
/* produciton change */
-- alter table revcx alter column depotpath type integer using create_or_find_depotpaths(depotpath);

/* depot paths */
create table depotpaths
(
  depotpaths_id serial
  , depotpath text
  , hash int
);
create index depotpaths_hash on depotpaths(hash) ;

create function create_or_find_depotpaths( in_path text) returns integer
language 'plpgsql' as
$$
DECLARE
  in_hash int;
  id int;
BEGIN
    in_hash := hashtext(in_path);
    select into id depotpaths_id from depotpaths where hash = in_hash and depotpath = in_path;
    if id is null then
        insert into depotpaths(depotpaths_id, depotpath, hash) values
              ( DEFAULT, in_path, in_hash) returning depotpaths_id into id;
    end if;
    return id;
END;
$$;

/*
 *
 * root mappings 
 *
 */
--      NEW.root_mapping := create_or_find_root_mapping(NEW.root_mapping);
create table root_mappings 
(
  root_mapping_id serial
  , root_mapping text
  , hash int
);
create index root_mappings_hash on root_mappings(hash) ;

create function create_or_find_root_mapping(in_map text ) returns integer
language 'plpgsql' as
$$
DECLARE
  in_hash int;
  id int;
BEGIN
    in_hash := hashtext(in_map);
    select into id root_mapping_id from root_mappings 
                  where hash = in_hash and root_mapping = in_map;
    if id is null then
        insert into root_mappings(root_mapping_id, root_mapping, hash) values
              ( DEFAULT, in_map, in_hash) returning root_mapping_id into id;
    end if;
    return id;
END;
$$;

/*
 *
 * label tags 
 *
 */
--      NEW.tagname := create_or_find_tagname(NEW.tagname); 
create table tagnames 
(
  tagname_id serial
  , tagname text
  , hash int
);
create index tagname_hash on tagnames(hash) ;

create function create_or_find_tagname(in_tag text ) returns integer
language 'plpgsql' as
$$
DECLARE
  in_hash int;
  id int;
BEGIN
    in_hash := hashtext(in_tag);
    select into id tagname_id from tagnames
                  where hash = in_hash and tagname = in_tag;
    if id is null then
        insert into tagnames(tagname_id, tagname, hash) values
              ( DEFAULT, in_tag, in_hash) returning tagname_id into id;
    end if;
    return id;
END;
$$;
-- -------------------------------------------------------------
create function depotpath_rewrite() RETURNS trigger 
language 'plpgsql' as
$$
DECLARE

BEGIN

  IF TG_TABLE_NAME = 'integed' then
      NEW.subject := create_or_find_depotpaths(NEW.subject);
      NEW.object := create_or_find_depotpaths(NEW.object);
  ELSIF TG_TABLE_NAME = 'rev' then
      NEW.rcs_file := create_or_find_depotpaths(NEW.rcs_file);
      NEW.depotpath := create_or_find_depotpaths(NEW.depotpath);
  ELSIF TG_TABLE_NAME = 'revcx'  then
      NEW.depotpath := create_or_find_depotpaths(NEW.depotpath);
  ELSIF TG_TABLE_NAME = 'change'  then
      NEW.root_mapping := create_or_find_root_mapping(NEW.root_mapping);
      -- NEW.who_host:= create_or_find_clients(NEW.who_host);
      -- NEW.who_user := create_or_find_users(NEW.who_user);
  ELSIF TG_TABLE_NAME = 'label'  then
      NEW.depotpath := create_or_find_depotpaths(NEW.depotpath);
      NEW.tagname := create_or_find_tagname(NEW.tagname); 
  END IF;

  return NEW;
END;
$$;

/* add triggers to all the tables */
create trigger tg_depotpath_rewrite 
BEFORE INSERT ON 
integed  
FOR  EACH  ROW EXECUTE PROCEDURE 
  depotpath_rewrite ()
;
create trigger tg_depotpath_rewrite  
BEFORE INSERT ON 
rev
FOR  EACH  ROW EXECUTE PROCEDURE 
  depotpath_rewrite ()
;
create trigger tg_depotpath_rewrite  
BEFORE INSERT ON 
revcx
FOR  EACH  ROW EXECUTE PROCEDURE 
  depotpath_rewrite ()
;
create trigger tg_depotpath_rewrite  
BEFORE INSERT ON 
label
FOR  EACH  ROW EXECUTE PROCEDURE 
  depotpath_rewrite ()
;
create trigger tg_depotpath_rewrite  
BEFORE INSERT ON 
change
FOR  EACH  ROW EXECUTE PROCEDURE 
  depotpath_rewrite ()
;

/*
TODO: create update triggers
TODO: fix queries to join tables.
*/
/*
          name          |    bytes    |  pages  |    size    
------------------------+-------------+---------+------------
 public.integed         | 24609824768 | 2910239 | 23 GB
 public.revcx           | 18659000320 |  794270 | 17 GB
 public.rev             | 26493878272 | 1783629 | 25 GB
 public.label           | 64189489152 | 2757268 | 60 GB

*/

