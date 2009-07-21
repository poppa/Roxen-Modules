#include <module.h>
inherit "module";
inherit "roxenlib";

import Parser.XML.Tree;

#define POPPA_DEBUG

#define _ok RXML_CONTEXT->misc[" _ok"]

#ifdef POPPA_DEBUG
# define TRACE(X...) report_debug("TTracker: " + sprintf(X))
#else
# define TRACE(X...)
#endif

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Time Tracker";
constant module_doc  = "Time tracker...";

typedef mapping(string:string) SqlRow;
typedef array(SqlRow)          SqlResult;
Configuration conf;
string db_name;

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus Östlund <pontus@poppa.se>");
  conf = _conf;

  defvar("db_name",
    Variable.DatabaseChoice(
      "timetrack_" + (conf ? Roxen.short_name(conf->name):""), 0,
      "TimeTracker Database",
      "The database where all TimeTracker data is stored."
    )->set_configuration_pointer(my_configuration)
  );
} // }}}

void start(int when, Configuration _conf) // {{{
{
  db_name = query("db_name");
  if (db_name)
    init_db();
} // }}}

//! Add a new TimeTrack
class TagTimeTrackAdd // {{{
{
  inherit RXML.Tag;
  constant name = "timetrack-add";

  mapping(string:RXML.Type) req_arg_types = ([
   "username" : RXML.t_text(RXML.PEnt),
   "text"     : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
   "date"     : RXML.t_text(RXML.PEnt),
   "tags"     : RXML.t_text(RXML.PEnt),
   "minutes"  : RXML.t_text(RXML.PEnt),
   "mysql-insert-id" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      Track track = Track(0, args->text, args->date, args->username,
                          args->tags, args->minutes);
      int myid = track->save();

      _ok = 1;
      if (myid)
	RXML.user_set_var(args["mysql-insert-id"]||"var.mysql-insert-id", myid);
      else
	_ok = 0;

      return 0;
    }
  }
} // }}}

//! Update a TimeTrack
class TagTimeTrackUpdate // {{{
{
  inherit RXML.Tag;
  constant name = "timetrack-update";

  mapping(string:RXML.Type) req_arg_types = ([
   "id" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
   "text"     : RXML.t_text(RXML.PEnt),
   "date"     : RXML.t_text(RXML.PEnt),
   "tags"     : RXML.t_text(RXML.PEnt),
   "minutes"  : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      Track t = get_track_by_id(args->id);

      if (!t) {
	_ok = 0;
	return 0;
      }

      t->set("text",    args->text);
      t->set("date",    args->date);
      t->set("tags",    args->tags);
      t->set("minutes", args->minutes);

      _ok = t->save();

      return 0;
    }
  }
} // }}}

// Delete TimeTrack
class TagTimeTrackDelete // {{{
{
  inherit RXML.Tag;
  constant name = "timetrack-delete";

  mapping(string:RXML.Type) req_arg_types = ([
   "id" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      _ok = 0;
      Track t = get_track_by_id(args->id);
      if (t) _ok = t->delete();
      return 0;
    }
  }
} // }}}

//! Emit TimeTrack(s)
class TagEmitTimeTracks // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "timetrack";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "id"        : RXML.t_text(RXML.PEnt),
    "username"  : RXML.t_text(RXML.PEnt),
    "maxrows"   : RXML.t_text(RXML.PEnt),
    "startat"   : RXML.t_text(RXML.PEnt),
    "from-date" : RXML.t_text(RXML.PEnt),
    "to-date"   : RXML.t_text(RXML.PEnt),
    "order-by"  : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array(Track) tracks = get_tracks( args->id, args->username, args->startat,
                                      args->maxrows, args["from-date"], 
				      args["to-date"], args["order-by"] );

    return tracks && tracks->cast("mapping")||({});
  }
} // }}}

//! Add a new TimeTrack
class TagTimeTrackServiceServer // {{{
{
  inherit RXML.Tag;
  constant name = "timetrack-service-server";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "id"        : RXML.t_text(RXML.PEnt),
    "username"  : RXML.t_text(RXML.PEnt),
    "maxrows"   : RXML.t_text(RXML.PEnt),
    "startat"   : RXML.t_text(RXML.PEnt),
    "from-date" : RXML.t_text(RXML.PEnt),
    "to-date"   : RXML.t_text(RXML.PEnt),
    "order-by"  : RXML.t_text(RXML.PEnt),
    "minutes"   : RXML.t_text(RXML.PEnt),
    "tags"      : RXML.t_text(RXML.PEnt),
    "text"      : RXML.t_text(RXML.PEnt),
    "date"      : RXML.t_text(RXML.PEnt)
  ]);

  multiset(string) rest_args = (< "id", "username", "maxrows", "startat",
                                  "from-date", "to-date", "order-by" >);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string res = "";

      make_args(id);

#define RESP_OK(V...)   " <ok>"    + sprintf(V) + "</ok>"
#define RESP_FAIL(V...) " <error>" + sprintf(V) + "</error>"

      switch (id->method)
      {
	case "DELETE":
	  TRACE("*** Got delete call\n");
	  break;

	case "POST":
	  if (args->id && (int)args->id > 0) {
	    Track t = get_track_from_args(args);
	    if (t->save())
	      res = RESP_OK("Update ok");
	    else
	      res = RESP_FAIL("Unable to save to database");
	  }
	  // Add new
	  else {
	    Track track = Track(0, args->text, args->date, args->username,
		                args->tags, args->minutes);
	    int myid = track->save();
	    if (myid)
	      res = RESP_OK((string)myid);
	    else
	      res = RESP_FAIL("Unable to save TimeTrack!");
	  }

	  break;

	case "GET":
	  array(Track) tracks = get_tracks( args->id, args->username,
	                                    args->startat, args->maxrows,
					    args["from-date"], args["to-date"],
					    args["order-by"] );

	  if (sizeof(tracks))
	    res = " <tracks>\n" + (tracks->cast("xml")*"\n") + "\n </tracks>";
	  else
	    res = " <tracks/>";

	  break;
      }

      result = "<timetrack>\n" + res + "\n</timetrack>";

#undef RESP_OK
#undef RESP_FAIL

      return 0;
    }

    void make_args(RequestID id)
    {
      foreach (indices(id->variables), string key)
	if ( opt_arg_types[key] )
	  args[key] = safe_utf8_decode( id->variables[key] );
    }
  }
} // }}}

//! Constructs a Track object from an SQL record
Track get_track_from_sql(SqlRow row) // {{{
{
  return Track((int)row->id, row->text, row->date, row->username, row->tags,
               (int)row->minutes);
} // }}}


//! Fetches track with id @[id] and creates a @[Track] object
Track get_track_by_id(string|int id) // {{{
{
  array(Track) t = get_tracks(id, 0, 0, 0, 0, 0, 0);
  return t && sizeof(t) && t[0];
} // }}}

//! Fetches a track from arguments given to timetrack-service-server
Track get_track_from_args(mapping args) // {{{
{
  Track t = Track(args->id, args->text, args->date, args->username,
                  args->tags, (int)args->minutes);
  return t;
} // }}}

string safe_utf8_decode(string s)
{
  catch(s = utf8_to_string(s));
  return s;
}

//! Fetches tracks from the DB and creates an array of @[Track] obejects
//! from the DB result.
//!
//! @param id
//!  Database ID of a specific track
//! @param username
//! @param startat
//!  Offset from where to list the results
//! @param maxrows
//! @param from
//!  Start date of listing
//! @param to
//!  End date of listing
//! @param order
//!  @tt{ASC@} or @tt{DESC@} order
array(Track) get_tracks(int|string id, void|string username, // {{{
                        void|int startat, void|int maxrows, void|string from, 
			void|string to, void|string order)
{
  array ret = ({});
  string sql = "SELECT * FROM `track`";

  id = (int)id;

  if (id)
    sql += " WHERE id = " + id;
  else if (username||from||to) {
    array(string) rules = ({});

    if (username) rules += ({ "`username`=" + quote_sql(username) });
    if (from)     rules += ({ "`date` >= "  + quote_sql(from)     });
    if (to)       rules += ({ "`date` <= "  + quote_sql(to)       });

    sql += " WHERE " + (rules*" AND ");
  }

  string sort = "DESC";

  if (order && sizeof(order)) {
    if (order[0] == '-')
      order = order[1..];
    else
      sort = "ASC";
  }
  else order = "`date` DESC, id";

  sql += sprintf(" ORDER BY %s %s", order, sort);
  
  if (maxrows)
    sql += " LIMIT " + (int)startat + ", " + (int)maxrows;

  TRACE("Tracks SQL: %s\n", sql);

  foreach (q(sql)||({}), SqlRow row)
    ret += ({ get_track_from_sql(row) });
  
  return ret;
} // }}}

class Track // {{{
{
  private int(0..1) exists = 1;
  int           id = 0;
  int           minutes;
  string        text;
  string        date;
  string        username;
  array(string) tags = ({});

  void create(int _id, string _text, string _date, string _username, // {{{
              string|array _tags, int _minutes)
  {
    id       = (int)_id;
    exists   = !!id;
    text     = _text;
    date     = _date;
    username = _username;
    minutes  = parse_time(_minutes);

    if (_tags) {
      if (stringp(_tags))
	tags = map(_tags/",", String.trim_all_whites) - ({ 0 })  - ({ "" });
      else
	tags = _tags - ({ 0 }) - ({ "" });
    }
  } // }}}

  int save() // {{{
  {
    string sql = "";
    if (exists) {
      sql = "UPDATE `track` SET"
            " minutes = %d,"
	    " text    = %s,"
	    " date    = %s,"
	    " tags    = %s "
	    "WHERE id = %d";

      if (mixed e = catch(q(sql, minutes, text, date, tags*",", id))) {
	report_error("Unable to update track(%d): %s\n", id,
	             describe_backtrace(e));
	return 0;
      }

      return 1;
    }
    else {
      array k = ({}), v = ({});

      foreach (sort(indices(this_object())), mixed member) {
	if (functionp( this_object()[member] ) || member == "id")
	  continue;

	k += ({ member });
	v += ({ quote_sql(this_object()[member] ) });
      }

      sql = sprintf("INSERT INTO `track` (%s) VALUES (%s)", k*",", v*",");
      if (mixed e = catch(q(sql))) {
	report_error("Error inserting to db: %s\n", describe_backtrace(e));
	return 0;
      }
      else
	return get_db()->master_sql->insert_id();
    }

    return 0;
  } // }}}

  int(0..1) delete() // {{{
  {
    if (mixed e = catch(q("DELETE FROM `track` WHERE id=%d", id))) {
      report_error("Unable to delete TimeTrack with id %d: %s\n", id,
                   describe_backtrace(e));
      return 0;
    }

    return 1;
  } // }}}

  mixed cast(string how) // {{{
  {
    switch (how)
    {
      case "mapping":
	return ([ "id"       : id,
	          "text"     : text,
		  "date"     : date,
		  "username" : username,
		  "minutes"  : minutes,
		  "tags"     : tags*"," ]);

#define TAG(NAME,VALUE) "   <" + NAME + ">" + (VALUE) + "</" + NAME + ">\n"
      case "xml":
	return  "  <track>\n"
	        TAG("id", id)
	        TAG("date", date)
		TAG("text", text)
	        TAG("username", username)
	        TAG("minutes", minutes)
	        TAG("tags", tags_as_xml())
	        "  </track>";
#undef TAG
    }

    error("Can't cast Track to %O\n", how);
  } // }}}
  
  protected string tags_as_xml() // {{{
  {
    string o = "";
    if (sizeof(tags) && arrayp(tags)) {
      o += "\n";
      foreach (tags, string tag)
	o += "    <tag>" + tag + "</tag>\n";
      o += "   ";
    }

    return o;
  } // }}}
  
  protected int parse_time(string|int t) // {{{
  {
    if (!t || intp(t)) return t;

    t = lower_case(t);

    int h, m;
    if (sscanf(t, "%dh%dm", h, m) == 2)
      m += h*60;
    else if (sscanf(t, "%d%*[,.]%d", h, m) == 3) {
      float dec;
      if (m > 10) dec = (float)m/100;
      else dec = (float)m/10;
      m = h*60 + (int)(60*dec);
    }
    else if (sscanf(t, "%d%[h]", h, string c) == 2 && sizeof(c))
      m = h*60;
    else
      m = (int)t;

    return m;
  } // }}}

  void set(string key, mixed value) // {{{
  {
    if (stringp(value) && !sizeof(value))
      return 0;
    // Cant set ID
    if (key == "id")
      return;
    else if (key == "minutes")
      value = parse_time(value);
    else if (key == "tags" && stringp(value))
      value = map(value/",", String.trim_all_whites) - ({ 0 }) - ({ "" });

    this[key] = value;
  } // }}}
} // }}}

/**
 * Module API 
 */

Sql.Sql get_db() 
{
  return DBManager.get(db_name, conf);
}

string quote_sql(mixed value)
{
  if (arrayp(value))
    value = value*",";
  else if (intp(value))
    return "'" + (string)value + "'";

  return "'" + get_db()->quote((string)value) + "'";
}

void init_db()
{
  if (db_name == " none") return;
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      report_error("No permission to read TimeTracker database: %s\n", db_name);
      return;
    }
    
    report_notice("No TimeTracker database present. Creating \"%s\".\n", 
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
			   "Used by the TimeTracker module to "
			   "store its data.");

    if (!get_db()) {
      report_error("Unable to create TimeTracker database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
}

void setup_tables()
{
  q(#"CREATE TABLE IF NOT EXISTS `track` (
     `id`        INT UNSIGNED PRIMARY KEY AUTO_INCREMENT NOT NULL,
     `username`  VARCHAR(100),
     `date`      DATE NOT NULL,
     `tags`      VARCHAR(255),
     `text`      TEXT,
     `minutes`   INT UNSIGNED
     ) TYPE=MYISAM");

  q(#"CREATE TABLE IF NOT EXISTS `group` (
     `id`        INT UNSIGNED PRIMARY KEY AUTO_INCREMENT NOT NULL,
     `name`      VARCHAR(100)
     ) TYPE=MYISAM");

  q(#"CREATE TABLE IF NOT EXISTS `group_member` (
     `id_group`  INT UNSIGNED NOT NULL,
     `username`  VARCHAR(100)
     ) TYPE=MYISAM");

  q(#"CREATE TABLE IF NOT EXISTS `attachment` (
     `id`        INT UNSIGNED PRIMARY KEY AUTO_INCREMENT NOT NULL,
     `id_track`  INT UNSIGNED NOT NULL,
     `filename`  VARCHAR(255) NOT NULL,
     `title`     VARCHAR(255) NOT NULL,
     `mimetype`  VARCHAR(50)  NOT NULL,
     `size`      INT UNSIGNED NOT NULL,
     `data`      LONGBLOB
     ) TYPE=MYISAM");

  DBManager.is_module_table(this_object(), db_name, "track",        0);
  DBManager.is_module_table(this_object(), db_name, "group",        0);
  DBManager.is_module_table(this_object(), db_name, "group_member", 0);
  DBManager.is_module_table(this_object(), db_name, "attachment",   0);
}

SqlResult q(mixed ... args)
{
  return get_db()->query(@args);
}

TAGDOCUMENTATION;
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
