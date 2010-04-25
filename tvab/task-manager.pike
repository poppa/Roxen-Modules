/* -*- Mode: Pike; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
//! @b{[PROG-NAME]@}
//!
//! Copyright © 2010, Pontus Östlund - @url{http://www.poppa.se@}
//!
//! @pre{@b{License GNU GPL version 3@}
//!
//! [PROG-NAME].pike is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! [PROG-NAME].pike is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with [PROG-NAME].pike. If not, see <@url{http://www.gnu.org/licenses/@}>.
//! @}

#include <module.h>
#include <roxen.h>
#include <stat.h>

inherit "module";
inherit "roxenlib";

#define TM_DEBUG
#define _ok RXML_CONTEXT->misc[" _ok"]
#ifdef  TM_DEBUG
# define TRACE(X...) report_debug("TM:%d: %s", __LINE__, sprintf(X))
#else
# define TRACE(X...)
#endif

#define QUOTE_SQL(X)       DB.Sql.quote((X))
#define THIS_OBJECT        object_program(this)
#define TRIM               String.trim_all_whites
#define EMPTY(X)           (!((X) && sizeof((X))))
#define NULL_IF_EMPTY(X)   { if (EMPTY(X)) X = 0; }
#define RXML_ERROR(X...) { RXML.user_set_var("var.error",sprintf(X));_ok=0; }
#define TYPEOF_SELF(OTHER) (object_program(this) == object_program((OTHER)))
#define INHERITS_THIS(CHILD) Program.inherits(object_program(CHILD),    \
			                      object_program(this))

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "TVAB Tags: Task Manager";
constant module_doc  = "";

typedef mapping(string:string) SqlRow;
typedef array(SqlRow) SqlResult;
Configuration conf;
string db_name;

constant TASK_TYPE = ([
  "web"     : "Webb",
  "print"   : "Print",
  "project" : "Projektledning"
]);

constant TASK_PRIO = ([
  "urgent"  : "Bråttom",
  "medium"  : "Medium",
  "trivial" : "Trivial"
]);

constant TASK_RESOLUTION = ([
  "fixed" : "Fixad",
  "ivalid" : "Ogiltig"
]);

/**
 * Utility stuff
 */
array(KeyValueField) get_key_value_fields(string group) // {{{
{
  SqlResult r = q("SELECT * FROM `field` WHERE `group`=%s ORDER BY `order`", 
                  group);
  array(KeyValueField) o = ({});
  foreach (r||({}), SqlRow row)
    o += ({ KeyValueField()->set_from_sql(row) });

  return o;
} // }}}

KeyValueField get_key_value_field_from_id(int id) // {{{
{
  SqlResult r = q("SELECT * FROM `field` WHERE id=%d", id);
  if (r && sizeof(r))
    return KeyValueField()->set_from_sql( r[0] );

  return 0;
} // }}}

class ATaskManager // {{{
{
  object_program set_from_sql(SqlRow sqlrow);
  object_program save();
  int(0..1) delete();
} // }}}

class KeyValueField // {{{
{
  inherit ATaskManager;

  DB.Sql.Int    id         = DB.Sql.Int("id");
  DB.Sql.String index      = DB.Sql.String("index");
  DB.Sql.String value      = DB.Sql.String("value");
  DB.Sql.Int    order      = DB.Sql.Int("order");
  DB.Sql.Enum   is_default = DB.Sql.Enum("default", (< "y","n" >), "n");
  DB.Sql.String group      = DB.Sql.String("group");

  void create(int|void _id, string|void _index, string|void _value,
              int|void _order, string|void _is_default, string|void _group)
  {
    id->set(_id);
    index->set(_index);
    value->set(_value);
    order->set(_order);
    is_default->set(_is_default);
    group->set(_group);
  }

  object set_from_sql(SqlRow row)
  {
    id->set(row->id);
    index->set(row->index);
    value->set(row->value);
    order->set(row->order);
    is_default->set( row["default"] );
    group->set(row->group);

    return this;
  }
  
  int get_id()
  {
    return (int)id;
  }

  string get_index()
  {
    return (string)index;
  }

  string get_value()
  {
    return (string)value;
  }
  
  int get_order()
  {
    return (int)order;
  }
  
  int get_is_default()
  {
    return is_default == "y";
  }
  
  string get_group()
  {
    return (string)group;
  }
  
  object inc()
  {
    int norder = (int)order;
    order->set(--norder);
    return this;
  }
  
  object deinc()
  {
    int norder = (int)order;
    order->set(++norder);
    return this;
  }
  
  object set_is_default(int(0..1)|void _is_default)
  {
    is_default->set(_is_default ? "y" : "n");
    return this;
  }

  object save()
  {
    KeyValueField the_default, the_same_order;

    foreach (get_key_value_fields((string)group)||({}),
             KeyValueField the_other)
    {
      if (the_other->get_id() != (int)id) {
	if (the_other->get_is_default())
	  the_default = the_other;

	if (the_other->get_order() > -1 && the_other->get_order() == (int)order)
	  the_same_order = the_other;
      }
    }

    if (is_default == "y" && the_default)
      q("UPDATE `field` SET `default`='n' WHERE id=%d", the_default->get_id());

    if (the_same_order) {
      q("UPDATE `field` SET `order`=`order`+1 WHERE `order`>=%d "
        "AND `order` != -1 AND `group`=%s", (int)order, (string)group);
    }

    array(DB.Sql.Field) flds = ({ index, value, order, is_default, group });
    string sql;

    // Add
    if ((int)id == 0) {
      sql = "INSERT INTO `field` (`index`,`value`,`order`,`default`,`group`) "
            "VALUES(" + (flds->get_quoted()*",") + ")";

      Sql.Sql db = get_db();
      db->query(sql);
      id->set(db->master_sql->insert_id());
    }
    // Update
    else {
      sql = "UPDATE `field` SET " + (flds->get()*",") + " WHERE id=%d";
      q(sql, (int)id);
    }

    return this;
  }

  void delete()
  {
    q("DELETE FROM `field` WHERE id=%d", (int)id);
    if ((int)order > -1) {
      q("UPDATE `field` SET `order`=`order`-1 WHERE `order` > %d "
        "AND `order` != -1 AND `group`=%s", (int)order, (string)group);
    }
  }

  string _sprintf(int t)
  {
    return t == 'O' && sprintf("%O(\"%s\", \"%s\")", THIS_OBJECT, index, value);
  }
} // }}}

SqlResult q(mixed ... args) // {{{
{
  return get_db()->query(@args);
} // }}}

/**
 * Tags
 */
 
class TagEmitTMField // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "tm-field";

  mapping(string:RXML.Type) req_arg_types = ([
    "group" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([]);

  array get_dataset(mapping args, RequestID id)
  {
    string s = "SELECT * FROM `field` WHERE `group`=%s ORDER BY `order`";
    return q(s, args->group)||({});
  }
} // }}}

class TagTMUpdateField // {{{
{
  inherit RXML.Tag;
  constant name = "tm-update-fields";

  mapping(string:RXML.Type) req_arg_types = ([
    "group" : RXML.t_text(RXML.PEnt)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      array collectable = ({ "id", "index","value","order","default" });
      array fields = allocate(sizeof(id->real_variables->id), ([]));
      foreach (collectable, string idx) {
      	int i = 0;
      	if ( array items = id->real_variables[idx] ) {
      	  foreach (items, string v) {
      	    fields[i][idx] = v;
      	    i++;
      	  }
      	}
      }

      foreach (fields, mapping field) {
      	KeyValueField((int)field->id, field->index, field->value,
      	              (int)field->order, field->default||"n",
      	              args->group)->save();
      }

      return 0;
    }
  }
} // }}}

class TagTMAddField // {{{
{
  inherit RXML.Tag;
  constant name = "tm-add-field";

  mapping(string:RXML.Type) req_arg_types = ([
    "index" : RXML.t_text(RXML.PEnt),
    "value" : RXML.t_text(RXML.PEnt),
    "group" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "default"  : RXML.t_text(RXML.PEnt),
    "order"    : RXML.t_text(RXML.PEnt),
    "mysql-id" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      NULL_IF_EMPTY( args["default"] );
      mixed e = catch {
	KeyValueField f = KeyValueField(0, args->index, args->value,
					(int)args->order, args["default"],
					args->group)->save();

	if ( args["mysql-id"] )
	  RXML.user_set_var(args["mysql-id"], f->get_id());
      };

      if (e) RXML_ERROR("Error adding field: %s", describe_error(e));

      return 0;
    }
  }
} // }}}

class TagTMFieldValue // {{{
{
  inherit RXML.Tag;
  constant name = "tm-field-value";

  mapping(string:RXML.Type) req_arg_types = ([]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt),
    "index" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (!args->id && !args->index)
      	RXML.parse_error("Missing required arguments \"id\" or \"index\"!");

      string sql = "SELECT value FROM `field` WHERE ";
      sql += args->id ? "id=%s" : "index=&s";

      SqlResult r = q(sql, args->id||args->index);
      _ok = 1;
      if (r && sizeof(r))
      	result = r[0]->value;
      else
      	_ok = 0;

      return 0;
    }
  }
} // }}}

class TagTMDeleteField // {{{
{
  inherit RXML.Tag;
  constant name = "tm-delete-field";

  mapping(string:RXML.Type) req_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      array ids = args->id/"\0";

      foreach (ids, string idx) {
	KeyValueField f = get_key_value_field_from_id((int)idx);
	f && f->delete();
      }

      return 0;
    }
  }
} // }}}


/**
 * Module API 
 */

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");
  conf = _conf;

  defvar("db_name",
    Variable.DatabaseChoice(
      "taskmanager_" + (conf ? Roxen.short_name(conf->name):""), 0,
      "TaskManager Database",
      "The database where TaskManager data is stored."
    )->set_configuration_pointer(my_configuration)
  );

  /*
  defvar("mima_location", Variable.Location(
    "/__mima/", 0, "Module mountpoint",
    "Where in the site's virtual file system Mima will look for uploaded files "
    "etc"
  ));
  */
} // }}}

void start(int when, Configuration _conf) // {{{
{
  //module_dependencies(_conf, ({ "svn", "pathinfo" }));

  db_name = query("db_name");
  //mima_location = query("mima_location");

  if (db_name)
    init_db();
} // }}}

Sql.Sql get_db() // {{{ 
{
  return DBManager.get(db_name, conf);
} // }}}

string quote_sql(mixed value) // {{{
{
  if (arrayp(value))
    value = value*",";
  else if (intp(value))
    return "'" + (string)value + "'";

  return "'" + DB.Sql.quote((string)value) + "'";
} // }}}

void init_db() // {{{
{
  if (db_name == " none") return;
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      report_error("No permission to read TaskManager database: %s\n", db_name);
      return;
    }
    
    report_notice("No TaskManager database present. Creating \"%s\".\n", 
                  db_name);

    if (!DBManager.get_group("poppa")) {
      DBManager.create_group( 
	"poppa", "Poppa Modules",
	"Various databases used by the Poppa modules", "" 
      );
    }

    DBManager.create_db(db_name, 0, 1, "poppa");
    DBManager.set_permission(db_name, conf, DBManager.WRITE);
    perms = DBManager.get_permission_map()[db_name];
    DBManager.is_module_db(0, db_name,
			   "Used by the TaskManager module to store its data.");

    if (!get_db()) {
      report_error("Unable to create TaskManager database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
} // }}}

void setup_tables() // {{{
{
  q(#"CREATE TABLE IF NOT EXISTS `user` (
    `id`           INT NOT NULL AUTO_INCREMENT,
    `username`     VARCHAR(45) NULL,
    `fullname`     VARCHAR(255) NULL,
    `email`        VARCHAR(255) NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  /*
  q(#"CREATE  TABLE IF NOT EXISTS `project_member` (
    `user_id`      INT NOT NULL,
    `project_id`   INT NOT NULL,
    `role`         ENUM('admin','member') NOT NULL DEFAULT 'member')
    ENGINE = MyISAM");
  */

  q(#"CREATE  TABLE IF NOT EXISTS `field` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `index`        VARCHAR(45) NULL,
    `value`        VARCHAR(100) NULL,
    `order`        TINYINT NULL DEFAULT -1,
    `default`      ENUM('y','n') NULL DEFAULT 'n',
    `group`        VARCHAR(45) NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");
/*
  q(#"CREATE  TABLE IF NOT EXISTS `ticket` (
    `id`           INT ZEROFILL UNSIGNED NOT NULL AUTO_INCREMENT,
    `project_id`   INT NULL,
    `deleted`      ENUM('y','n') NULL DEFAULT 'n',
    `date_created` DATETIME NOT NULL,
    `date_edited`  DATETIME NULL,
    `owner`        VARCHAR(45) NULL,
    `reporter`     VARCHAR(255) NOT NULL,
    `summary`      VARCHAR(255) NULL,
    `text`         TEXT NULL,
    `resolution`   INT NULL,
    `type`         INT NULL,
    `priority`     INT NULL,
    `accepted`     ENUM('y','n') NULL DEFAULT 'n',
    PRIMARY KEY (`id`)) 
    ENGINE = MyISAM");
  
  if (!sizeof(q("DESCRIBE ticket accepted"))) {
    report_notice("No \"accepted\" column in `ticket`! Adding...");
    q("ALTER TABLE ticket ADD accepted ENUM('y','n') NULL DEFAULT 'n'");
  }
*/
  //DBManager.is_module_table(this_object(), db_name, "project",        0);
  DBManager.is_module_table(this_object(), db_name, "user",           0);
  //DBManager.is_module_table(this_object(), db_name, "project_member", 0);
  DBManager.is_module_table(this_object(), db_name, "field",          0);
  //DBManager.is_module_table(this_object(), db_name, "ticket",         0);

  /* Add some defaults */

  int i;
  string def;
  if (!sizeof(get_key_value_fields("task-type"))) {
    foreach (TASK_TYPE; string index; string value) {
      KeyValueField f = KeyValueField(0,index,value,i++, "n" ,"task-type");
      f->save();
    }
  }

  i = 0;
  if (!sizeof(get_key_value_fields("task-prio"))) {
    foreach (TASK_PRIO; string index; string value) {
      string def = index == "medium" ? "y" : "n";
      KeyValueField f = KeyValueField(0,index,value,i++,def,"task-prio");
      f->save();
    }
  }

  i = 0;
  if (!sizeof(get_key_value_fields("task-resolution"))) {
    foreach (TASK_RESOLUTION; string index; string value) {
      string def = index == "fixed" ? "y" : "n";
      KeyValueField f = KeyValueField(0,index,value,i++,def,"task-resolution");
      f->save();
    }
  }
} // }}}
