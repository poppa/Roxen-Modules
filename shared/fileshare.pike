#include <module.h>
#include <roxen.h>
#include <stat.h>
inherit "module";
inherit "roxenlib";

//<locale-token project="mod_sqlfs">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_sqlfs",X,Y)
// end of the locale related stuff

import Parser.XML.Tree;

#define POPPA_DEBUG

#define _ok RXML_CONTEXT->misc[" _ok"]

#ifdef POPPA_DEBUG
# define TRACE(X...) \
  report_debug("%s:%d: %s", basename(__FILE__), __LINE__, sprintf(X))
#else
# define TRACE(X...)
#endif

constant thread_safe   = 1;
constant module_type   = MODULE_TAG|MODULE_LOCATION;
constant module_name   = "Poppa Tags: FileShare";
constant module_doc    = "Share files...";
constant module_unique = 0;

typedef mapping(string:string) SqlRow;
typedef array(SqlRow)          SqlResult;
Configuration conf;
string db_name;
string repository;
string mountpoint;

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus Östlund <pontus@poppa.se>");
  conf = _conf;

  defvar("db_name",
    Variable.DatabaseChoice(
      "fileshare_" + (conf ? Roxen.short_name(conf->name):""), 0,
      "Fileshare Database",
      "The database where all Fileshare data is stored."
    )->set_configuration_pointer(my_configuration)
  );

  defvar("repository", Variable.String(
    "", 0, "Repository path",
    "Path on local filesystem where to store the files"
  ));

  defvar("location", Variable.Location(
    "/", 0, "Module mountpoint",
    "Where the repository will be mounted in the site's virtual file system"
  ));
} // }}}

void start(int when, Configuration _conf) // {{{
{
  db_name    = query("db_name");
  repository = query("repository");
  mountpoint = query("location");

  TRACE("Mountpoint: %O\n", mountpoint);

  if (!sizeof(repository)) {
    report_warning("Can't start module until a repository path is set\n");
    return;
  }

  if (!Stdio.exist(repository)) {
    report_error("Repository path \"%s\" doesn't exist!\n", repository);
    return;
  }

  if (!sizeof(mountpoint)) {
    report_warning("Can't start module until a mountpoint is set\n");
    return;
  }

  if (db_name)
    init_db();
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
      report_error("No permission to read Fileshare database: %s\n", db_name);
      return;
    }
    
    report_notice("No Fileshare database present. Creating \"%s\".\n", 
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
			   "Used by the Fileshare module to "
			   "store its data.");

    if (!get_db()) {
      report_error("Unable to create Fileshare database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
}

void setup_tables()
{
  q(#"CREATE TABLE IF NOT EXISTS `file` (
     `id`        INT UNSIGNED PRIMARY KEY AUTO_INCREMENT NOT NULL,
     `hash`      VARCHAR(50),
     `username`  VARCHAR(100),
     `date`      DATETIME NOT NULL,
     `name`      VARCHAR(255),
     `size`      BIGINT UNSIGNED,
     `type`      VARCHAR(50),
     `last`      DATETIME,
     `real_file` VARCHAR(255)
     ) TYPE=MYISAM");

  DBManager.is_module_table(this_object(), db_name, "file", 0);
}

/**
 * Module location API
 */

string query_location()
{
  return mountpoint;
}
 
#ifdef THREADS
private Thread.Mutex lfm = Thread.Mutex();
#endif
 
constant dir_stat  = ({ 0777|S_IFDIR, -1, 10, 10, 10, 0, 0 });
constant null_stat = ({ 0, 0 });

protected array low_stat_file(string f, RequestID id)
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
}

Stat stat_file( string f, RequestID id )
{
  array s = low_stat_file("/" + f, id);
  return s && s[0];
}

mixed find_file(string f, RequestID id)
{
  if(!strlen(f)) return -1;
  f = normalized_path(f);
  array st = low_stat_file(f, id);

  if(!st) return 0;
  if(st[1] == -1) return -1;

  string fname = basename(f);
  array(string) tmp = id->conf->type_from_filename(f, 1);

  return Roxen.http_file_answer( Stdio.File(f, "r"), tmp[0] ) + ([ 
                                 "encoding" : tmp[1], 
				 "Content-Disposition" : 
				 "attachment; filename=\"" + fname +"\"" ]);
}

/**
 * Misc methods
 */

string normalized_path(string p)
{
  return combine_path(repository, p-"..");
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
