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
 
User get_tm_user(string|int handle) // {{{
{
  SqlResult r;
  if (stringp(handle))
    r = q("SELECT * FROM `user` WHERE username=%s", handle);
  else
    r = q("SELECT * FROM `user` WHERE id=%d", handle);

  return r && sizeof(r) && User()->set_from_sql( r[0] );
} // }}}
 
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

string sql_quote(string|int value) // {{{
{
  if (intp(value))
    return (string)value;

  return "'" + DB.Sql.quote(value) + "'";
} // }}}

#define SQL_INT    DB.Sql.Int
#define SQL_FLOAT  DB.Sql.Float
#define SQL_STRING DB.Sql.String
#define SQL_ENUM   DB.Sql.Enum
#define SQL_DATE   DB.Sql.Date

class ATaskManager // {{{
{
  object_program set_from_sql(SqlRow sqlrow);
  object_program save();
  int(0..1) delete();
} // }}}

class KeyValueField // {{{
{
  inherit ATaskManager;

  SQL_INT    id         = SQL_INT("id");
  SQL_STRING index      = SQL_STRING("index");
  SQL_STRING value      = SQL_STRING("value");
  SQL_INT    order      = SQL_INT("order");
  SQL_ENUM   is_default = SQL_ENUM("default", (< "y","n" >), "n");
  SQL_STRING group      = SQL_STRING("group");

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

class User // {{{
{
  inherit ATaskManager;

  SQL_INT id          = SQL_INT("id");
  SQL_STRING username = SQL_STRING("username");
  SQL_STRING fullname = SQL_STRING("fullname");
  SQL_STRING email    = SQL_STRING("email");

  void create(int|void _id, string|void _username, string|void _fullname,
              string|void _email)
  {
    id->set(_id);
    username->set(_username);
    fullname->set(_fullname);
    email->set(_email);
  }

  object_program set_from_sql(SqlRow sqlrow)
  {
    id->set(sqlrow->id);
    username->set(sqlrow->username);
    fullname->set(sqlrow->fullname);
    email->set(sqlrow->email);
    return this;
  }

  int get_id()
  {
    return (int)id;
  }

  string get_username()
  {
    return (string)username;
  }

  string get_fullname()
  {
    return (string)fullname;
  }
  
  string get_email()
  {
    return (string)email;
  }

  int(0..1) `==(object_program other)
  {
    return (TYPEOF_SELF(other) || INHERITS_THIS(other)) &&
           (int)id          == other->get_id()          &&
           (string)username == other->get_username()    &&
           (string)fullname == other->get_fullname()    &&
           (string)email    == other->get_email();
  }

  object_program save()
  {
    string sql;
    // Add
    if ((int)id < 1) {
      sql = "INSERT INTO `user` (username, fullname, email) VALUES (%s)";
      Sql.Sql db = get_db();
      db->query(sprintf(sql, ({ username,fullname,email })->get_quoted()*","));
      id->set(db->master_sql->insert_id());
    }
    // Update
    else {
      sql = "UPDATE `user` SET " + ({ username,fullname,email })->get()*"," + 
            " WHERE id=%d";
      q(sprintf(sql, id));
    }

    return this;
  }
  
  int(0..1) delete()
  {
    string sql = "DELETE FROM `user` WHERE id=%d";
    Sql.Sql db = get_db();
    db->query(sql, (int)id);
    /*
    sql = "DELETE FROM project_member WHERE user_id=%d";
    db->query(sql, (int)id);
    sql = "UPDATE ticket SET owner=NULL WHERE owner=%s";
    db->query(sql, (string)username);
    */
    return 1;
  }

  string _sprintf(int t)
  {
    return sprintf("%O(%O, \"%s\", \"%s\", \"%s\")", THIS_OBJECT,
                   id->get_value(), username, fullname, email);
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

class TagEmitTMUser // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "tm-user";

  mapping(string:RXML.Type) req_arg_types = ([]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt),
    "username" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string sql = "SELECT * FROM `user`";

    if (args->id)
      sql += " WHERE id='" + QUOTE_SQL(args->id) + "'";
    else if (args->username)
      sql += " WHERE username='" + QUOTE_SQL(args->username) + "'";

    sql += " ORDER BY `fullname`";

    return q(sql)||({});
  }
} // }}}

class TagEmitTMUserSearch // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "tm-user-search";

  mapping(string:RXML.Type) req_arg_types = ([
    "find" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array ret = ({});
    string rxml = sprintf(
      "<emit source='ac-identities' search='%s'>" 
      "&_.name;\1&_.fullname;\1&_.id;\1&_.type;\1&_.zone-id;"
      "<delimiter>\0</delimiter></emit>",
      args->find
    );

    string res = Roxen.parse_rxml(rxml, id);
    if (!sizeof(res))
      return ret;

    array r = res/"\0";
    foreach (r, string u) {
      [string un, string fn, string uid, string ut, string uz] = u/"\1";

      // Skip already added user, skip groups
      if (get_tm_user(un) || ut != "user")
      	continue;

      mapping m = ([
	"name"     : un,
	"fullname" : fn,
	"id"       : uid,
	"type"     : ut,
	"zone-id"  : uz
      ]);

      rxml = 
      "<emit source='ac-identity-extras' identity='%s'>"
      "&_.firstname;\1&_.lastname;\1&_.email;"
      "</emit>";

      res = Roxen.parse_rxml(sprintf(rxml, m->name), id);
      if (sizeof(res)) {
      	[un, fn, ut] = res/"\1";
      	m->firstname = un;
      	m->lastname  = fn;
      	m->email     = ut;
      }

      ret += ({ m });
    }

    return ret;
  }
} // }}}

class TagTMAddUser // {{{
{
  inherit RXML.Tag;
  constant name = "tm-add-user";

  mapping(string:RXML.Type) req_arg_types = ([
    "username" : RXML.t_text(RXML.PEnt),
    "fullname" : RXML.t_text(RXML.PEnt),
    "email"    : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      _ok = 1;
      User u = User(0, args->username, args->fullname, args->email);
      if (!u->save()) _ok = 0;
      return 0;
    }
  }
} // }}}

class TagTMEditUser // {{{
{
  inherit RXML.Tag;
  constant name = "tm-edit-user";

  mapping(string:RXML.Type) req_arg_types = ([
    "id"       : RXML.t_text(RXML.PEnt),
    "username" : RXML.t_text(RXML.PEnt),
    "fullname" : RXML.t_text(RXML.PEnt),
    "email"    : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      _ok = 1;
      User u = get_tm_user((int)args->id);

      if (!u) {
      	_ok = 0;
      	return 0;
      }

      u->username->set(args->username);
      u->fullname->set(args->fullname);
      u->email->set(args->email);

      if (!u->save()) _ok = 0;

      return 0;
    }
  }
} // }}}

class TagTMDeleteUser // {{{
{
  inherit RXML.Tag;
  constant name = "tm-delete-user";

  mapping(string:RXML.Type) req_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      _ok = 1;
      User u = get_tm_user((int)args->id);
      if (!u || !u->delete()) _ok = 0;
      return 0;
    }
  }
} // }}}

class TagTMAddTask // {{{
{
  inherit RXML.Tag;
  constant name = "tm-add-task";

  mapping(string:RXML.Type) req_arg_types = ([
    "title"       : RXML.t_text(RXML.PEnt),
    "description" : RXML.t_text(RXML.PEnt),
    "reporter"    : RXML.t_text(RXML.PEnt),
    "type"        : RXML.t_text(RXML.PEnt)
  ]);
  
  mapping(string:RXML.Type) opt_arg_types = ([
    "priority" : RXML.t_text(RXML.PEnt),
    "owner"    : RXML.t_text(RXML.PEnt),
    "biller"   : RXML.t_text(RXML.PEnt),
    "due-date" : RXML.t_text(RXML.PEnt),
    "mysql-id" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      _ok = 1;
      
      array(DB.Sql.Field) flds = ({
      	SQL_STRING("title",       args->title),
      	SQL_STRING("description", args->description),
      	SQL_STRING("reporter",    args->reporter),
      	SQL_INT("type",           (int)args->type),
      	SQL_INT("priority",       (int)args->priority),
      	SQL_STRING("owner",       args->owner),
      	SQL_STRING("biller",      args->biller),
      	SQL_DATE("due_date",      args["due-date"] ),
      	SQL_DATE("date_added",    "NOW()")
      });

      string sql = sprintf("INSERT INTO `task` (%s) VALUES (%s)",
                           flds->get_quoted_name()*",",
                           flds->get_quoted()*",");

      Sql.Sql db = get_db();
      mixed e = catch {
      	db->query(sql);
      	if ( args["mysql-id"] )
      	  RXML.user_set_var(args["mysql-id"], db->master_sql->insert_id());
      };

      if (e) {
      	TRACE("Error: %s\n", describe_backtrace(e));
      	RXML_ERROR(describe_error(e));
      }

      return 0;
    }
  }
} // }}}

class TagTMAddAttachment // {{{
{
  inherit RXML.Tag;
  constant name = "tm-add-attachment";

  mapping(string:RXML.Type) req_arg_types = ([
    "id"          : RXML.t_text(RXML.PEnt),
    "type"        : RXML.t_text(RXML.PEnt),
    "file-prefix" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "description-prefix" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      _ok = 1;

      if (!sizeof(args->id))
      	RXML.parse_error("Required argument \"id\" is empty!\n");

      if ( !(< "task", "message" >)[args->type] )
      	RXML.parse_error("Type attribute must be \"task\" or \"message\"!");

      array(mapping) files = ({});
      string fp = args["file-prefix"] + "*";
      string dp = args["description-prefix"];

      foreach (indices(id->variables), string k) {
      	if (glob(fp, k)) {
      	  if (search(k, ".") > -1) continue;
      	  sscanf(k, fp + "%d", int|string idx);
      	  idx = (string)idx;
      	  mapping m = ([]);
      	  m->contents = id->variables[k];
      	  m->mimetype = id->variables[k + ".mimetype"];
      	  m->filename = id->variables[k + ".filename"];
      	  m->filesize = sizeof(m->contents);

      	  if (dp)
      	    m->description = id->variables[dp+idx];

      	  files += ({ m });
      	}
      }

      foreach (files, mapping m) {
      	array(DB.Sql.Field) flds = ({
      	  SQL_INT(args->type + "_id", args->id),
      	  SQL_STRING("filename",      m->filename),
      	  SQL_STRING("mimetype",      m->mimetype),
      	  SQL_STRING("description",   m->description),
      	  SQL_STRING("content",       m->contents),
      	  SQL_INT("filesize",         m->filesize),
      	  SQL_DATE("mtime",           "NOW()")
	});

	string sql = sprintf("INSERT INTO `attachment` (%s) VALUES (%s)",
	                     flds->get_quoted_name()*",",
	                     flds->get_quoted()*",");

	if (mixed e = catch(q(sql))) {
	  _ok = 0;
	  report_debug("SQL Error: %s\n", describe_backtrace(e));
	}
      }

      return 0;
    }
  }
} // }}}

class TagEmitTMAttachment // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "tm-attachment";

  mapping(string:RXML.Type) opt_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt),
    "task-id" : RXML.t_text(RXML.PEnt),
    "message-id" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) req_arg_types = ([]);

  array get_dataset(mapping args, RequestID id)
  {
    string tbl;
    if (args->id) 
      tbl = "attachment";
    if ( args["task-id"] )
      tbl = "task";
    else if ( args["message-id"] )
      tbl = "message";

    if (!tbl || EMPTY(tbl)) {
      RXML.parse_error("Missing required argument \"id\" or \"task-id\" or "
                       "\"message-id\"!\n");
    }

    SqlResult res;
    string sql = "SELECT * FROM attachment WHERE ";
    if (args->id)
      res = q(sql + "id=%d", (int)args->id);
    else if ( args["task-id"] )
      res = q(sql + "task_id=%d", (int)args["task-id"] );
    else if ( args["message-id"] )
      res = q(sql + "message-id=%d", (int)args["message-id"] );

    return res;
  }
} // }}}

class TagEmitTMTask // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "tm-task";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "id"         : RXML.t_text(RXML.PEnt),
    "reporter"   : RXML.t_text(RXML.PEnt),
    "owner"      : RXML.t_text(RXML.PEnt),
    "biller"     : RXML.t_text(RXML.PEnt),
    "resolution" : RXML.t_text(RXML.PEnt),
    "type"       : RXML.t_text(RXML.PEnt),
    "priority"   : RXML.t_text(RXML.PEnt),
    "accepted"   : RXML.t_text(RXML.PEnt),
    "page"       : RXML.t_text(RXML.PEnt),
    "per-page"   : RXML.t_text(RXML.PEnt),
    "order-by"   : RXML.t_text(RXML.PEnt)
  ]);

  array(string) where_clauses = ({ "reporter", "owner", "biller", "resolution",
                                   "type", "priority", "accepted" });

  array get_dataset(mapping args, RequestID id)
  {
    string sql = #"
    SELECT t1.id AS id, t1.reporter AS reporter, t1.title AS title,
           t1.description AS description, t1.date_added AS date_added,
           t1.due_date AS due_date, t1.accepted AS accepted,
           t1.biller AS biller, t1.type AS type, t1.priority AS priority,
           t1.resolution AS resolution, t1.owner AS owner,
           t2.fullname AS owner_fullname, t2.email AS owner_email
    FROM `task` t1
    LEFT JOIN `user` t2 on t1.owner = t2.username ";

    if (!EMPTY(args->id)) {
      sql += "WHERE t1.id=" + QUOTE_SQL(args->id);
    }
    else {
      array wheres = ({});
      foreach (where_clauses, string where)
      	if (!EMPTY( args[where] ))
	  wheres += ({ "t1." + where + "=" + sql_quote( args[where] ) });

      if (sizeof(wheres))
	sql += "WHERE " + (wheres*" AND ");


      if ( args["order-by"] )
	sql += "";
      else
	sql += " ORDER BY t1.date_added DESC";
      
      if (!EMPTY( args["per-page"] )) {
      	int from = (int)args->page * (int)args["per-page"];
      	sql += sprintf( " LIMIT %d, %s", from, args["per-page"] );
      }
    }

    //TRACE("SQL: %s\n", sql);

    SqlResult res;
    if (mixed e = catch(res = q(sql))) {
      TRACE("QUERY ERROR: %s\n", describe_backtrace(e));
      RXML_ERROR(describe_error(e));
      return ({});
    }

    //TRACE("RESULT: %O\n", res);

    return res;
  }
} // }}}

class TagIfTMUser // {{{
{
  inherit RXML.Tag;

  constant name = "if";
  constant plugin_name = "tm-user";

  mapping(string:RXML.Type) opt_arg_types = ([
  ]);

  int eval(string a, RequestID id, mapping args)
  {
    return !!get_tm_user(a);
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
    `id` INT NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(45) NULL,
    `fullname` VARCHAR(255) NULL,
    `email` VARCHAR(255) NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  q(#"CREATE TABLE IF NOT EXISTS `field` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `index` VARCHAR(45) NULL,
    `value` VARCHAR(100) NULL,
    `order` TINYINT NULL DEFAULT -1,
    `default` ENUM('y','n') NULL DEFAULT 'n',
    `group` VARCHAR(45) NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  q(#"CREATE TABLE IF NOT EXISTS `task` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `reporter` VARCHAR(255) NULL,
    `title` VARCHAR(255) NULL,
    `description` TEXT NULL,
    `date_added` DATETIME NULL,
    `due_date` DATETIME NULL,
    `type` INT NULL,
    `priority` INT NULL,
    `resolution` INT NULL,
    `owner` VARCHAR(45) NULL,
    `accepted` ENUM('y','n') NULL DEFAULT 'n',
    `biller` VARCHAR(255) NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  q(#"CREATE TABLE IF NOT EXISTS `timetrack` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `task_id` INT UNSIGNED NOT NULL,
    `username` VARCHAR(255) NULL,
    `date_added` DATETIME NULL,
    `minutes` INT NULL,
    `billable` ENUM('y','n') NULL DEFAULT 'y',
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  q(#"CREATE TABLE IF NOT EXISTS `attachment` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `task_id` INT UNSIGNED NOT NULL,
    `filename` VARCHAR(255) NULL,
    `mimetype` VARCHAR(255) NULL,
    `description` VARCHAR(255) NULL,
    `filesize` INT NULL,
    `mtime` DATETIME NULL,
    `content` LONGBLOB NULL,
    `message_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  q(#"CREATE TABLE IF NOT EXISTS `message` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `task_id` INT UNSIGNED NOT NULL,
    `date_added` DATETIME NULL,
    `username` VARCHAR(255) NULL,
    `fullname` VARCHAR(255) NULL,
    `email` VARCHAR(255) NULL,
    `message` TEXT NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  DBManager.is_module_table(this_object(), db_name, "user",       0);
  DBManager.is_module_table(this_object(), db_name, "field",      0);
  DBManager.is_module_table(this_object(), db_name, "task",       0);
  DBManager.is_module_table(this_object(), db_name, "timetrack",  0);
  DBManager.is_module_table(this_object(), db_name, "attachment", 0);
  DBManager.is_module_table(this_object(), db_name, "message",    0);

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
