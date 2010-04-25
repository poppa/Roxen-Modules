// NOTE: Very much work in progress

#include <module.h>
#include <roxen.h>
#include <stat.h>

inherit "module";
inherit "roxenlib";

import Parser.XML.Tree;

#define POPPA_DEBUG
#define _ok RXML_CONTEXT->misc[" _ok"]
#ifdef  POPPA_DEBUG
# define TRACE(X...) report_debug("Mima: " + sprintf(X))
#else
# define TRACE(X...)
#endif

#define QUOTE_SQL(X)       get_db()->quote((X))
#define QUOTE_DB(X)        db->quote((X))
#define THIS_OBJECT        object_program(this)
#define TRIM               String.trim_all_whites
#define EMPTY(X)           (!((X) && sizeof((X))))
#define NULL_IF_EMPTY(X)   { if (EMPTY(X)) X = 0; }
#define RXML_ERROR(X...) { RXML.user_set_var("mima.error",sprintf(X));_ok=0; }
#define TYPEOF_SELF(OTHER) (object_program(this) == object_program((OTHER)))
#define INHERITS_THIS(CHILD) Program.inherits(object_program(CHILD),    \
			                      object_program(this))

constant thread_safe = 1;
constant module_type = MODULE_TAG|MODULE_LOCATION|MODULE_FIRST;
constant module_name = "Mima: Main Module";
constant module_doc  = "";

typedef mapping(string:string) SqlRow;
typedef array(SqlRow) SqlResult;
Configuration conf;
string db_name;

private string this_path = dirname(__FILE__);
//private string local_mima_root = combine_path("..", "local", "mima");
private string mima_location;

/**
 * Mima constants (like)
 */

mapping TICKET_TYPE = ([
  "defect"      : "Defect",
  "enhancement" : "Enhancement",
  "task"        : "Task"
]);

mapping TICKET_PRIORITY = ([
  "blocker"  : "Blocker",
  "critical" : "Critical",
  "major"    : "Major",
  "minor"    : "Minor",
  "trivial"  : "Trivial"
]);

mapping TICKET_RESOLUTION = ([
  "fixed"      : "Fixed",
  "invalid"    : "Invalid",
  "duplicate"  : "Duplicate",
  "wontfix"    : "Won't fix",
  "worksforme" : "Works for me"
]);

constant MEMBER_ROLE_MEMBER = "member";
constant MEMBER_ROLE_ADMIN  = "admin";
constant MEMBER_ROLES = (< MEMBER_ROLE_ADMIN, MEMBER_ROLE_MEMBER >);

/**
 * Mima utils
 */

User get_mima_user(string|int handle) // {{{
{
  SqlResult r;
  if (stringp(handle))
    r = q("SELECT * FROM `user` WHERE username=%s", handle);
  else
    r = q("SELECT * FROM `user` WHERE id=%d", handle);

  return r && sizeof(r) && User()->set_from_sql( r[0] );
} // }}}

Project project_exist(string name) // {{{
{
  SqlResult r = q("SELECT * FROM `project` WHERE name=%s", name);
  return r && sizeof(r) && Project()->set_from_sql( r[0] );
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

/**
 * Mima classes
 */

class AbstractMima // {{{
{
  object_program set_from_sql(SqlRow sqlrow);
  object_program save();
  int(0..1) delete();
} // }}}

class Project // {{{
{
  inherit AbstractMima;

  DB.Sql.Int id             = DB.Sql.Int("id");
  DB.Sql.String name        = DB.Sql.String("name");
  DB.Sql.String description = DB.Sql.String("description");
  DB.Sql.String identifier  = DB.Sql.String("identifier");
  array(Member) members;

  void create(int|void _id, string|void _name, string|void _description,
              string|void _identifier)
  {
    id->set(_id);
    name->set(_name);
    description->set(_description);
    identifier->set(_identifier);
  }

  object_program set_from_sql(SqlRow sqlrow)
  {
    id->set(sqlrow->id);
    name->set(sqlrow->name);
    description->set(sqlrow->description);
    identifier->set(sqlrow->identifier);
    return this;
  }
  
  int get_id()
  {
    return (int)id;
  }

  string get_name()
  {
    return (string)name;
  }

  string get_description()
  {
    return (string)description;
  }

  string get_identifier()
  {
    return (string)identifier;
  }

  array(Member) get_members()
  {
    if (!members) {
      members = ({});
      SqlResult r = q("SELECT t1.id AS id, t1.username AS username,"
                      " t1.fullname AS fullname, t2.role AS role,"
                      " t2.project_id AS project_id "
                      "FROM `user` t1 "
                      "INNER JOIN project_member t2"
                      " ON t2.project_id=%d", (int)id);
      foreach (r||({}), SqlRow row)
	if (row) members += ({ Member()->set_from_sql(row) });
    }

    return members;
  }

  void add_user(User u, string type)
  {
    array(Member) users = get_members();
    if (sizeof(users) == sizeof(users - ({ u })))
      members += ({ Member((int)id, type)->set_from_user(u)->save() });
  }

  object_program save()
  {
    string sql;
    array fields = ({ name, description, identifier });
    // Add
    if ((int)id < 1) {
      sql = "INSERT INTO `project` (name, description, identifier) VALUES (%s)";
      Sql.Sql db = get_db();
      db->query(sprintf(sql, fields->get_quoted()*","));
      id->set(db->master_sql->insert_id());
    }
    // Update
    else {
      sql = "UPDATE `project` SET " + fields->get()*"," + " WHERE id=%d";
      q(sql, id);
    }

    return this;
  }
  
  string _sprintf(int t)
  {
    return sprintf("%O(%O, \"%s\", \"%s\", \"%s\")", THIS_OBJECT,
                   id->get_value(), name, description, identifier);
  }
} // }}}

class User // {{{
{
  inherit AbstractMima;

  DB.Sql.Int id          = DB.Sql.Int("id");
  DB.Sql.String username = DB.Sql.String("username");
  DB.Sql.String fullname = DB.Sql.String("fullname");
  DB.Sql.String email    = DB.Sql.String("email");

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
    sql = "DELETE FROM project_member WHERE user_id=%d";
    db->query(sql, (int)id);
    sql = "UPDATE ticket SET owner=NULL WHERE owner=%s";
    db->query(sql, (string)username);

    return 1;
  }

  string _sprintf(int t)
  {
    return sprintf("%O(%O, \"%s\", \"%s\", \"%s\")", THIS_OBJECT,
                   id->get_value(), username, fullname, email);
  }
} // }}}

class Member // {{{
{
  inherit User;
  protected DB.Sql.String role = DB.Sql.String("role", MEMBER_ROLE_MEMBER);
  protected DB.Sql.Int project_id = DB.Sql.Int("project_id");

  void create(int|void _project_id, void|string _role, void|int id, 
              void|string username, void|string fullname)
  {
    ::create(id, username, fullname);

    project_id->set(_project_id);

    if (_role) {
      if ( !MEMBER_ROLES[_role] ) {
	error("Unknown member role %O. Must be %s! ",
	      _role, String.implode_nicely((array)MEMBER_ROLES, "or"));
      }

      role->set(_role);
    }
  }

  string get_role()
  {
    return (string)role;
  }

  int get_project_id()
  {
    return (int)project_id;
  }

  int(0..1) `==(object_program other)
  {
    if (TYPEOF_SELF(other)) {
      return ::`==(other) && (string)role == other->get_role() &&
                             (int)project_id == other->get_project_id();
    }

    return ::`==(other);
  }
  
  object_program set_from_sql(SqlRow sqlrow)
  {
    ::set_from_sql(sqlrow);
    project_id->set(sqlrow->project_id);
    role->set(sqlrow->role);

    return this;
  }
  
  object_program set_from_user(User u)
  {
    id->set(u->get_id());
    username->set(u->get_username());
    fullname->set(u->get_fullname());
    email->set(u->get_email());
    return this;
  }
  
  object_program save()
  {
    ::save();
    q("INSERT INTO `project_member` (project_id, user_id, role) "
      "VALUES (%d, %d, %s)", (int)project_id, (int)id, (string)role);

    return this;
  }
  
} // }}}

class KeyValueField // {{{
{
  inherit AbstractMima;

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

class Ticket // {{{
{
  inherit AbstractMima;
  
  DB.Sql.Int    id           = DB.Sql.Int("id");
  DB.Sql.Int    project_id   = DB.Sql.Int("project_id");
  DB.Sql.Enum   deleted      = DB.Sql.Enum("deleted", (< "y","n" >), "n");
  DB.Sql.Date   date_created = DB.Sql.Date("date_created", 0, 1);
  DB.Sql.Date   date_edited  = DB.Sql.Date("date_edited");
  DB.Sql.String owner        = DB.Sql.String("owner");
  DB.Sql.String reporter     = DB.Sql.String("reporter");
  DB.Sql.String summary      = DB.Sql.String("summary");
  DB.Sql.String text         = DB.Sql.String("text");
  DB.Sql.Int    resolution   = DB.Sql.Int("resolution");
  DB.Sql.Int    type         = DB.Sql.Int("type");
  DB.Sql.Int    priority     = DB.Sql.Int("priority");
  DB.Sql.Enum   accepted     = DB.Sql.Enum("accepted", (< "y","n" >), "n");

  void create(int|void _id)
  {
    if (_id) {
      SqlResult r = q("SELECT * FROM `ticket` WHERE id=%d", _id);
      if (r && sizeof(r))
      	set_from_sql( r[0] );
    }
  }

  object set_from_sql(SqlRow row)
  {
    foreach (indices(row), string key)
      if ( this[key] && object_variablep(this, key))
	this[key]->set( row[key] );

    return this;
  }

  object save()
  {
    string sql;
    array(DB.Sql.Field) flds = ({ project_id, deleted, date_created, date_edited,
                                  owner, reporter, summary, text, resolution,
                                  type, priority, accepted });
    // Add
    if ((int)id == 0) {
      string fields = flds->get_quoted_name()*",";
      string values = flds->get_quoted()*",";
      sql = sprintf("INSERT INTO `ticket` (%s) VALUES (%s)", fields, values);
      Sql.Sql db = get_db();
      db->query(sql);
      id->set(db->master_sql->insert_id());
    }
    // Update
    else {
      sql = "UPDATE `ticket` SET " + (flds->get()*",") + " WHERE id=%d";
      q(sql, (int)id);
    }

    return this;
  }
  
  string _sprintf(int t)
  {
    return t == 'O' && sprintf("%O(%d, \"%s\")", THIS_OBJECT, id, summary);
  }
} // }}}

/**
 * Mima tags
 */

//! Sets the page title for the current page
class TagMimaTitle // {{{
{
  inherit RXML.Tag;
  constant name = "mima-title";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "value"  : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string v;
      if (args->value)
      	v = args->value;
      else if (sizeof(content))
      	v = content;
      else
      	v = "Untitled";

      RXML.user_set_var("var.mima-page-title", sprintf("Mima - %s", v));

      return 0;
    }
  }
} // }}}

class TagMimaMountpoint // {{{
{
  inherit RXML.Tag;
  constant name = "mima-mountpoint";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "variable"  : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (args->variable)
	RXML.user_set_var(args->variable, mima_location);
      else
      	result = mima_location;

      return 0;
    }
  }
} // }}}

class TagMimaAdminCreateProject // {{{
{
  inherit RXML.Tag;
  constant name = "mima-admin-project-create";

  mapping(string:RXML.Type) req_arg_types = ([
    "name" : RXML.t_text(RXML.PEnt),
    "description" : RXML.t_text(RXML.PEnt),
    "identifier"  : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string handle = get_username(id);
      string fullname = get_user_fullname(id);

      Project p;
      if (p = project_exist(TRIM(args->name))) {
      	RXML_ERROR("A project with name \"%s\" already exist!", args->name);
      	return 0;
      }

      p = Project(0, args->name, args->description, args->identifier)->save();

      if (!EMPTY( args["add-current-user"] )) {
	User u;
	if (!(u = get_mima_user(handle)))
	  u = User(0, handle, fullname)->save();

	p->add_user(u, MEMBER_ROLE_ADMIN);
      }

      return 0;
    }
  }
} // }}}

class TagEmitMimaProject // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "mima-project";

  mapping(string:RXML.Type) req_arg_types = ([
    "identifier" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array ret = ({});
    string sql = "SELECT * FROM `project` WHERE identifier=%s ";

    if (args->id)
      sql += "AND id=" + (int)args->id;

    return q(sql, args->identifier)||({});
  }
} // }}}

class TagEmitMimaField // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "mima-field";

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

class TagMimaUpdateField // {{{
{
  inherit RXML.Tag;
  constant name = "mima-update-fields";

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

class TagMimaAddField // {{{
{
  inherit RXML.Tag;
  constant name = "mima-add-field";

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

class TagMimaFieldValue // {{{
{
  inherit RXML.Tag;
  constant name = "mima-field-value";

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

class TagMimaDeleteField // {{{
{
  inherit RXML.Tag;
  constant name = "mima-delete-field";

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

class TagMimaAddTicket // {{{
{
  inherit RXML.Tag;
  constant name = "mima-add-ticket";

  mapping(string:RXML.Type) req_arg_types = ([
    "summary"     : RXML.t_text(RXML.PEnt),
    "reporter"    : RXML.t_text(RXML.PEnt),
    "text"        : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "project-id" : RXML.t_text(RXML.PEnt),
    "owner"      : RXML.t_text(RXML.PEnt),
    "type"       : RXML.t_text(RXML.PEnt),
    "priority"   : RXML.t_text(RXML.PEnt),
    "mysql-id"   : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      mapping nargs = ([]);
      foreach (args; string key; string val)
	nargs[replace(key, "-", "_")] = val;

      m_delete(nargs, "mysql_id");

      if (nargs->project_id && nargs->project_id == "0")
      	m_delete(nargs, "project_id");

      mixed e = catch {
	Ticket ticket = Ticket()->set_from_sql(nargs)->save();

	if ( args["mysql-id"] )
	  RXML.user_set_var(args["mysql-id"], (string)ticket->id);

	TRACE("Ticket: %O\n", ticket);
      };

      if (e) RXML_ERROR("Unable to save ticket: %s", describe_error(e));

      return 0;
    }
  }
} // }}}

class TagMimaUpdateTicket // {{{
{
  inherit RXML.Tag;
  constant name = "mima-update-ticket";

  mapping(string:RXML.Type) req_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt),
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "summary"    : RXML.t_text(RXML.PEnt),
    "reporter"   : RXML.t_text(RXML.PEnt),
    "text"       : RXML.t_text(RXML.PEnt),
    "project-id" : RXML.t_text(RXML.PEnt),
    "owner"      : RXML.t_text(RXML.PEnt),
    "type"       : RXML.t_text(RXML.PEnt),
    "resolution" : RXML.t_text(RXML.PEnt),
    "priority"   : RXML.t_text(RXML.PEnt),
    "accepted"   : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      mapping nargs = ([]);
      foreach (args; string key; string val)
	nargs[replace(key, "-", "_")] = val;

      if (nargs->project_id && nargs->project_id == "0")
      	m_delete(nargs, "project_id");

      //TRACE("Args: %O\n", nargs);
      Ticket ticket = Ticket((int)args->id);
      if (!ticket) {
      	_ok = 0;
      	return 0;
      }

      ticket->date_edited->set("NOW()");
      ticket->set_from_sql(nargs)->save();

      return 0;
    }
  }
} // }}}

class TagEmitMimaTicket // {{{
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "mima-ticket";

  mapping(string:RXML.Type) req_arg_types = ([
    "identifier" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "id"         : RXML.t_text(RXML.PEnt),
    "project-id" : RXML.t_text(RXML.PEnt),
    "owner"      : RXML.t_text(RXML.PEnt),
    "reporter"   : RXML.t_text(RXML.PEnt),
    "from-date"  : RXML.t_text(RXML.PEnt),
    "to-date"    : RXML.t_text(RXML.PEnt),
    "report-id"  : RXML.t_text(RXML.PEnt),
    "accepted"   : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array ret = ({});
    string sql =
    "SELECT t1.id AS id, t1.deleted AS deleted, t1.project_id AS project_id,\n"
    "       t1.date_created AS date_created, t1.date_edited AS date_edited,\n"
    "       t1.owner AS owner, t1.reporter AS reporter,\n"
    "       t1.summary AS summary, t1.text AS text,\n"
    "       t1.resolution AS resolution_id, t1.type AS type_id,\n"
    "       t1.priority AS priority_id, t1.accepted AS accepted,\n"
    "       t2.name AS project_name,\n"
    "       t2.description AS project_description\n"
    "FROM `ticket` t1\n"
    "LEFT JOIN `project` t2\n"
    "       ON t2.id=t1.project_id\n";

    if (args->id) {
      sql += "WHERE t1.id=%d AND (t2.identifier=%s OR t2.identifier IS NULL)";
      SqlResult r = q(sql, (int)args->id, args->identifier);
      return r || ({});
    }

    Sql.Sql db = get_db();

    sql += "WHERE t2.identifier='" + QUOTE_DB(args->identifier) + "' "
           "OR t2.identifier IS NULL ";
    
    if (args->owner)
      sql += "AND t1.owner='" + QUOTE_DB(args->owner) + "' ";
    if (args->reporter)
      sql += "AND t1.reporter='" + QUOTE_DB(args->reporter) + "' ";
    if ( args["project-id"] )
      sql += "AND t2.id=" + (int)args["project-id"] + " ";

    sql += "ORDER BY t1.date_created DESC";

    SqlResult r = db->query(sql);

    return r||ret;
  }
} // }}}

class TagEmitMimaUser // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "mima-user";

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

class TagEmitMimaUserSearch // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "mima-user-search";

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
      if (get_mima_user(un) || ut != "user")
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

class TagAddUser // {{{
{
  inherit RXML.Tag;
  constant name = "mima-add-user";

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
      User u = User(0, args->username, args->fullname, args->email);
      if (!u->save())
      	_ok = 0;
      return 0;
    }
  }
} // }}}

class TagEditUser // {{{
{
  inherit RXML.Tag;
  constant name = "mima-edit-user";

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
      User u = get_mima_user((int)args->id);

      if (!u) {
      	_ok = 0;
      	return 0;
      }

      u->username->set(args->username);
      u->fullname->set(args->fullname);
      u->email->set(args->email);

      if (!u->save())
      	_ok = 0;

      return 0;
    }
  }
} // }}}

class TagDeleteUser // {{{
{
  inherit RXML.Tag;
  constant name = "mima-delete-user";

  mapping(string:RXML.Type) req_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      User u = get_mima_user((int)args->id);
      _ok = 1;
      if (!u || !u->delete())
      	_ok = 0;
      return 0;
    }
  }
} // }}}

//! Sets the page title for the current page
class TagSafeJs // {{{
{
  inherit RXML.Tag;
  constant name = "safe-js";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "encoding" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (!args->type)
      	args->type = "text/javascript";

      string s = sprintf(
	"<script%{ %s='%s'%}>\n//<![CDATA[\n%s\n"
	"//]]>\n</script>", (array)args, TRIM(content||"")
      );
      result = replace(s, ({ "&amp;", "&lt;", "&gt;" }), ({ "&", "<", ">" }));
      return 0;
    }
  }
} // }}}

#define RE_PCRE Regexp.PCRE
#define RE_OPT  Regexp.PCRE.OPTION

class TagMima // {{{
{
  inherit RXML.Tag;

  constant name = "mima";
  constant flags = (RXML.FLAG_COMPILE_RESULT|
		    RXML.FLAG_EMPTY_ELEMENT|
		    RXML.FLAG_DONT_CACHE_RESULT);

  array(RXML.Type) result_types = ::result_types (RXML.PXml);

  mapping(string:object) result_cache = ([]);

  RE_PCRE re_ticket = RE_PCRE("\\\[ticket:[0-9]+( .*)\\\]",
                              RE_OPT.UNGREEDY|RE_OPT.DOTALL);

  class Frame
  {
    inherit RXML.Frame;
    string scope_name = "mima";
    mapping|object vars;

    array do_enter(RequestID id)
    {
      vars = ([]);
      vars["identifier"] = args["identifier"];
      vars["base"]       = args["mima-base"];
      vars["self"]       = "/" + id->misc->localpath 
                               + (id->misc->path_info||"");
      vars["parent-dir"] = dirname( vars["self"] );
      vars["mountpoint"] = mima_location;
      vars["wiki"]       = args["wiki-root"];

      Web.Wiki.Parser wp = Web.Wiki.Parser( args["wiki-root"] );
      wp->add_macro("CLEAR", "<div class='clear'></div>");
      wp->add_regexp(re_ticket,
		     lambda (string m) {
		       sscanf(m, "[ticket:%d%*[ ]%s]", int tid, m);
		       return sprintf("<a href='%sticket/view/%d'>%s</a>",
		                      vars->base, tid, m||"ticket:"+tid);
		     }
      );

      RoxenModule wiki = conf->get_provider("wiki");
      wiki->register_wiki_parser(wp);

      if ( args["svn-repository-uri"] ) {
      	vars["svn-repository-uri"] = args["svn-repository-uri"];
      	RC.SVN.set_repository_base( args["svn-repository-uri"] );
      }

#ifdef POPPA_DEBUG
      vars["debug"] = 1;
#endif
    }

    /* TODO: fix cacheing here...
     */
    array do_return(RequestID id)
    {
      NOCACHE();
      string file = args["rxml-file"];

      if (!file || !sizeof(file))
      	RXML.parse_error("Missing RXML file!\n");

      array(string) r = ({ id->conf->try_get_file(file, id) });
      string cont = Roxen.parse_rxml(r*"", id);
      RoxenModule xslt = conf->get_provider("xsltransform");
      mapping xargs = ([ "xsl" : args["template-file"] ]);
      cont = xslt->xsltransform(name, xargs, cont, id);
      result = Roxen.parse_rxml(cont, id);
      /*
      NOCACHE();
      string file = args["rxml-file"];

      if (!file || !sizeof(file))
      	RXML.parse_error("Missing RXML file!\n");

      string key = file + ":" + (string)id->misc->sbobj->get_userid();
      array(string) r;
      if (r = (result_cache[key] && result_cache[key]->data)) {
	return r;
      }

      r = ({ id->conf->try_get_file(file, id) });
      
      TRACE("R: %O\n",r);
      
      if( !r[0] )
	RXML.run_error("No such file ("+Roxen.fix_relative( file, id )+").\n");

      object cache_obj = class { array data; }();
      object sbobj = id->misc->wa->sbobj(file, id);
      if (sbobj) sbobj->content_dep(cache_obj);
      if (cache_obj) cache_obj->data = r;

      result_cache[key] = cache_obj;
      return r;
      */
      return 0;
    }
  }
} // }}}

//  This cache stores all RXML definitions indexed on user ID. The
//  definitions are wrapped in objects which will be destructed when a
//  XSLT template is modified.
//
//  The user ID string is not only the ID itself but includes the name
//  of the template set we want to use. This enables multiple template
//  definitions in parallel. The string is build as <id> + "|" + <set>.
mapping(string : object) rxml_cache = ([ ]);

//  Initialization mutex for the RXML glue. Having several threads run the
//  same transform in parallel will not benefit any of the threads so it's
//  better to have them wait for the mutex. This mainly affects server
//  startup where there may be outstanding requests.
#if constant(thread_create)
object rxml_init_mutex = Thread.Mutex();
#endif

//  Weak reference to RXML tags module so we can detect when it's reloaded.
//  This is necessary because the user tag definitions which we parse are
//  stored in a tag-set in that module and it will be purged when the module
//  is reloaded.
array(RoxenModule) rxml_tags_module = ({ });

class TagMimaInit // {{{
{
  inherit RXML.Tag;

  constant name = "mima-init";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  array(RXML.Type) result_types = ({ RXML.t_nil }); // No result.

  mapping(string:RXML.Type) req_arg_types = ([
    "glue-file"     : RXML.t_text(RXML.PEnt),
    "template-file" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      TRACE("do_return(%O)\n", name);

      mapping|RXML.Scope    formvars, varvars;
      mapping               newdefs;
      RXML.Context          ctx = RXML_CONTEXT;
      Sitebuilder.Workarea  wa = id->misc->wa;
      mapping vars = ([]);

      //  Handle repeated initialization attempts gracefully
      if (id->misc->mimaisinit)
	return 0;

      id->misc->mimaisinit = 1;
/*
      //  Get user ID from id->misc->sbobj which in turn gets initialized
      //  in find_file().
      int userid = id->misc->sbobj->get_userid();
      string rxml_cache_key = (string) userid        + "|" +
                              args["glue-file"]      + "|" +
	                      args["template-file"]  + "|" +
	                      id->misc->sbobj->real_abspath();

      //  If the page is generated by CompassServlet we can safely cache
      //  it since all state is in the URL when not logged in. However,
      //  as soon as any authenticated user changes the compass we need
      //  to clear all compass pages.
      //int no_auth = !id->misc->authenticated_user->name();

      //  Search for cached RXML definitions. We'll check our reference to
      //  the RXML tags module to see whether the cache data is stale or not.
      int cache_ok = sizeof(rxml_tags_module) && !!rxml_tags_module[0];
      if (!cache_ok)
	rxml_cache = ([ ]);

      if ( object cache_entry = rxml_cache[rxml_cache_key] ) {
      	//TRACE("Found in cache: %O, %O\n", rxml_cache_key, cache_entry);
	[newdefs, formvars, varvars] = cache_entry->data;
      }
      else {
	//  Load and parse RXML definitions and serialize all initializations
#if constant(thread_create)
	Thread.MutexKey lock = rxml_init_mutex->lock();
	
	//  We'll check for a cache hit again when we get the mutex in case
	//  another thread just updated it. We could have accomplised
	//  the same thing by moving the mutex lock earlier but we don't
	//  want to access the mutex unnecessarily during normal execution.
	if (object cache_entry = rxml_cache[rxml_cache_key]) {
	  [newdefs, formvars, varvars] = cache_entry->data;
	} 
	else
#endif
	{
	  string glue_file = args["glue-file"];
	  RXML.user_set_var("var.mima-template-file", args->template);
	  if (int|string rxml_text = id->conf->try_get_file(glue_file, id)) {
	    //  Get new RXML parser
	    RXML.Parser parser = Roxen.get_rxml_parser(id);
	    parser->context->set_var("mima-template-file",
	                             args["template-file"], "var");
	    parser->write_end(rxml_text);
	    parser->eval();

	    [newdefs, formvars, varvars] = ({
	      parser->context->misc - ({ " _extra_heads"," _error"," _stat" }),
	      parser->context->get_scope("form"),
	      parser->context->get_scope("var") });
	  } 
	  else {
	    RXML.run_error("Can not find glue file: %O\n", glue_file);
	    return 0;
	  }

	  //  Add to cache and install dependency tracking so the entry is
	  //  destructed if any of the SB files are modified.
	  object cache_obj = class { array data; }();
#if 0
	  array(Sitebuilder.FS.SBNotification.NotifyObjRef) notify_refs =
	    (array) (wa->notification->get_notify_refs_for_key(id->misc->cachekey)
		     || ({ }) );
	  array(Sitebuilder.FS.SBObject) dep_sbobjs =
	    map(notify_refs,
		lambda(Sitebuilder.FS.SBNotification.SBObjRef sbref) {
		  //  Must be careful here since sbobj() treats user ID 0 as
		  //  admin user. We need to pass a negative value in that
		  //  case.
		  return
		    (sscanf(sbref, "%d:%s", int uid, string path) == 2) &&
		    wa->sbobj(path, uid || -1);
		}) - ({ 0 });
	  foreach(dep_sbobjs, Sitebuilder.FS.SBObject dep_sbobj)
	    dep_sbobj->content_dep(cache_obj);
#else
	  wa->notification->merge_dependencies (cache_obj, id->misc->cachekey);
#endif
	  if (cache_obj)
	    cache_obj->data = ({ newdefs, formvars, varvars });

	  rxml_cache[rxml_cache_key] = cache_obj;
	}

	//  Update reference to RXML tags module
	RoxenModule m = id->conf->get_provider("rxmltags");
	rxml_tags_module = set_weak_flag( ({ m }), Pike.WEAK);

#if constant(thread_create)
	//  Workaround for Pike misfeature
	lock = 0;
#endif
      }

      foreach (indices(newdefs), string defname) {
	mixed def = ctx->misc[defname] = newdefs[defname];
	if (has_prefix(defname, "tag\0"))
	  ctx->add_runtime_tag(def[3]);
      }
      ctx->extend_scope("form", formvars);
      ctx->extend_scope("var", varvars);
      
      TRACE("Initialized\n");
*/
      return 0;
    }
  }
} // }}}

/**
 * Utility
 */

//! Returns the username of the current user
string get_username(RequestID id) // {{{
{
  return id->misc->sb && 
         id->misc->sb->mac && id->misc->sb->mac->id_get_handle(id);
} // }}}

//! Returns the full name of the current user
string get_user_fullname(RequestID id) // {{{
{
  return id->misc->sb->mac->id_get_name(get_username(id));
} // }}}
 
/**
 * Module first API
 */
mapping first_try( RequestID id) // {{{
{
  if (!id->variables["__xsl"] && id->misc->path_info &&
      search(id->misc->localpath, "index.xml/ajax") > -1)
  {
    NOCACHE();
    string qs = "?__xsl=ajax.xsl" + (id->query ? "&" + id->query : "");
    string p = "/" + id->misc->localpath + qs;
    mapping ret = Roxen.http_redirect(p, id);
    ret->error = 301;
    return ret;
  }
  return 0;
} // }}}

/**
 * Module location API
 */

string query_location() // {{{
{
  return mima_location;
} // }}}

#ifdef THREADS
private Thread.Mutex lfm = Thread.Mutex();
#endif
 
constant dir_stat  = ({ 0777|S_IFDIR, -1, 10, 10, 10, 0, 0 });
constant null_stat = ({ 0, 0 });

protected array low_stat_file(string f, RequestID id) // {{{
{
  if (f == "/")
    return dir_stat;

  if (has_value(f, "%"))
    return 0;

#ifdef THREADS
  Thread.MutexKey k = lfm->lock();
#endif

  Stdio.Stat st = file_stat(f);
  if (!st || st->isdir) return 0;

  return (array)st;
} // }}}

Stat stat_file( string f, RequestID id ) // {{{
{
  array s = low_stat_file(f, id);
  return s && s[0];
} // }}}

mapping find_file(string f, RequestID id) // {{{
{
  if(!strlen(f)) return 0;
  f = normalized_path(f);

  if (has_prefix(f, "ckeditor")) {
    f = combine_path(this_path, f);
    array st = low_stat_file(f, id);
    if(!st || st[1] == -1) return 0;

    return Roxen.http_string_answer(Stdio.read_bytes(f),
                                    conf->type_from_filename(f));
  }

  TRACE("Find attachment or alike: %O\n", f);

  return 0;
} // }}}

/**
 * Misc methods
 */

string normalized_path(string p) // {{{
{
  return p-"..";
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
      "mima_" + (conf ? Roxen.short_name(conf->name):""), 0,
      "Mima Database",
      "The database where Mima data is stored."
    )->set_configuration_pointer(my_configuration)
  );

  defvar("mima_location", Variable.Location(
    "/__mima/", 0, "Module mountpoint",
    "Where in the site's virtual file system Mima will look for uploaded files "
    "etc"
  ));
} // }}}

void start(int when, Configuration _conf) // {{{
{
  module_dependencies(_conf, ({ "svn", "pathinfo" }));

  db_name = query("db_name");
  mima_location = query("mima_location");

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

  return "'" + get_db()->quote((string)value) + "'";
} // }}}

void init_db() // {{{
{
  if (db_name == " none") return;
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      report_error("No permission to read Mima database: %s\n", db_name);
      return;
    }
    
    report_notice("No Mima database present. Creating \"%s\".\n", 
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
			   "Used by the Mima module to store its data.");

    if (!get_db()) {
      report_error("Unable to create Mima database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
} // }}}

void setup_tables() // {{{
{
  q(#"CREATE TABLE IF NOT EXISTS `project` (
    `id`           INT NOT NULL AUTO_INCREMENT,
    `name`         VARCHAR(255) NULL,
    `description`  TEXT NULL,
    `identifier`   VARCHAR(255) NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  q(#"CREATE TABLE IF NOT EXISTS `user` (
    `id`           INT NOT NULL AUTO_INCREMENT,
    `username`     VARCHAR(45) NULL,
    `fullname`     VARCHAR(255) NULL,
    `email`        VARCHAR(255) NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

  q(#"CREATE  TABLE IF NOT EXISTS `project_member` (
    `user_id`      INT NOT NULL,
    `project_id`   INT NOT NULL,
    `role`         ENUM('admin','member') NOT NULL DEFAULT 'member')
    ENGINE = MyISAM");

  q(#"CREATE  TABLE IF NOT EXISTS `field` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `index`        VARCHAR(45) NULL,
    `value`        VARCHAR(100) NULL,
    `order`        TINYINT NULL DEFAULT -1,
    `default`      ENUM('y','n') NULL DEFAULT 'n',
    `group`        VARCHAR(45) NULL,
    PRIMARY KEY (`id`))
    ENGINE = MyISAM");

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

  DBManager.is_module_table(this_object(), db_name, "project",        0);
  DBManager.is_module_table(this_object(), db_name, "user",           0);
  DBManager.is_module_table(this_object(), db_name, "project_member", 0);
  DBManager.is_module_table(this_object(), db_name, "field",          0);
  DBManager.is_module_table(this_object(), db_name, "ticket",         0);

  /* Add some defaults */

  int i;
  string def;
  if (!sizeof(get_key_value_fields("ticket-type"))) {
    foreach (TICKET_TYPE; string index; string value) {
      string def = index == "enhancement" ? "y" : "n";
      KeyValueField f = KeyValueField(0, index,value,i++,def,"ticket-type");
      f->save();
    }
  }

  i = 0;
  if (!sizeof(get_key_value_fields("ticket-priority"))) {
    foreach (TICKET_PRIORITY; string index; string value) {
      string def = index == "major" ? "y" : "n";
      KeyValueField f = KeyValueField(0, index,value,i++,def,"ticket-priority");
      f->save();
    }
  }

  i = 0;
  if (!sizeof(get_key_value_fields("ticket-resolution"))) {
    foreach (TICKET_RESOLUTION; string index; string value) {
      string def = index == "fixed" ? "y" : "n";
      KeyValueField f = KeyValueField(0, index,value,i++,def,
                                      "ticket-resolution");
      f->save();
    }
  }
} // }}}

SqlResult q(mixed ... args) // {{{
{
  return get_db()->query(@args);
} // }}}

TAGDOCUMENTATION; // {{{
#ifdef manual
constant tagdoc = ([
"tagdoc" :
  #"<desc type='tag'><p><short>
  Short desc here...</short>
  </p></desc>

  <attr name='attribute' optional='optional' value='string'><p>
  Attribute here...
  </p></attr>"
]);

#endif /* manual */
// }}}
