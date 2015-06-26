/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  This is a Roxen® CMS module

  This module contains tags for commenting on pages and managing these
  comments as well as tags for "liking" pages.
*/

#charset utf8

//#define CMT_DEBUG
//#define CMT_LOW_DEBUG

#if constant(Crypto.MD5)
# define MD5(S) String.string2hex(Crypto.MD5.hash((S)))
#else
# define MD5(S) Crypto.string_to_hex(Crypto.md5()->update((S))->digest());
#endif

#ifdef CMT_LOW_DEBUG
# define YTRACE(X...) do { \
  if (id->variables->debug) \
    werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X)); \
  } while (0)
#else
# define YTRACE(X...) 0
#endif

#ifdef CMT_DEBUG
# define TRACE(X...) werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...) 0
#endif

#include <module.h>
#include <config.h>
inherit "module";

import Sitebuilder;
inherit SBConnect;

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y) _DEF_LOCALE("sitebuilder",X,Y)

#define _ok RXML_CONTEXT->misc[" _ok"]

constant thread_safe = 1;
constant module_type = MODULE_TAG;
LocaleString module_name = DLOCALE(0, "Poppa Tags CMS: Comments");
LocaleString module_doc  = DLOCALE(0, #"
<p>This module listens on the SiteBuilder event hook and should always
be connected to a SiteBuilder module.</p>

<p>Provides commenting functionality to Roxen CMS pages.<br />
As of now this module should only be used in controlled environments, i.e where
users are authenticated, unless you whish to drown in spam comments. Spam
filtering will be added in a later version...</p>");

int    form_expires;
string db_name;
string anon_user;
string mail_server;
string mail_template;
string mail_from;
string mail_subject;
array(string) banned_users;
object hook;
mapping(string:function)
  rollback_action = ([]), //| Action to run when operation is discarded
  commit_action   = ([]); //| Action to run when page is checked in

Configuration conf;

//| Metadata values for external visibility (that we are interested in).
constant VISIBLE_ALWAYS = -1;
constant VISIBLE_NEVER  = 0;

typedef mapping(string:string) SqlRecord;
typedef array(SqlRecord) SqlResult;
#define SqlError -10

void cmt_error(mixed ... args)
{
  report_error("Comments: " + args[0], @args[1..]);
}

void create(Configuration _conf)
{
  conf = _conf;
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");

  defvar("form_expires",
    Variable.Int(
      60, 0, DLOCALE(0, "Form expires"), DLOCALE(0,
      "Number of days the comment form should be enabled. "
      "When the expire date is reached the already added comments "
      "will still be displayed but the ability to add comments will "
      "be removed. This variable is used togheter with "
      "<tt>if#comment-form-expired</tt>.<br/>"
      "If set to zero the if plugin will always return false, i.e "
      "commenting will always be enabled."
    ))
  );

  defvar("anon_user",
    Variable.String(
      "Guest", 0, "Anonymous comment author",
      "If non-authorized users are allowed to add comments and the "
      "\"author\" field is optional, i.e anonymous comments are allowed, "
      "this will be the default name in the \"author\" db table column. "
      "This value can be overridden by setting the attribute "
      "<tt>guest</tt> in <tt>&lt;comment-add>&lt;/comment-add></tt>"
    )
  );

  defvar("dump_file",
    Variable.String(
      "comments", 0, "Dump file",
      "You can make a backup file of the comments DB and the data will "
      "be stored to this file."
    )
  );

  defvar("do_email",
    Variable.Int(
      0, 0, "Send email",
      "If non-zero an email will be sent to commenters when a new comment "
      "arrives"
    )
  );

  defvar("mail_subject",
    Variable.String(
      "[no subject]", 0, "Mail subject",
      "The subject of the notification mails"
    )
  );

  defvar("mail_template",
    Variable.Text(
      "", 0, "Mail template",
      "Layout of the mail to send to notify previous commenters to an article "
      "that a new comment has arrived. Subsitution variables:<br/><ul>"
      "<li>[url] : The url to the page that has the comments</li>"
      "<li>[commenter] : The name of the commenter</li>"
      "<li>[receiver] : The name of the one receiving the mail</li>"
      "<li>[id] : The id of the just added comment</li>"
    )
  );

  defvar("mail_server",
    Variable.String(
      "localhost", 0, "Mail server",
      "The address of the mail server to use to send emails"
    )
  );

  defvar("mail_from",
    Variable.String(
      "no-reply@localhost", 0, "Mail sender",
      "The email address that will be in the \"From\" field"
    )
  );

  defvar("banned_users",
    Variable.Text(
      "", 0, "Banned users",
      "These users (usernames) can't leave comments. Space, comma or row "
      "separated list!"
    )
  );

  defvar("db_name",
    Variable.DatabaseChoice(
      "comment_" + (conf ? Roxen.short_name(conf->name) : ""), 0,
      "Comments database",
      "The database where we store page comments"
    )->set_configuration_pointer(my_configuration)
  );

  defvar("sitebuilder",
    ChooseSiteVariable(conf, VAR_INITIAL,
      DLOCALE(842,"SiteBuilder"),
      DLOCALE(843,"The SiteBuilder to connect to.")
    )
  );

  visible_chooser = CHOOSE_SITE;
}


void start(int when, Configuration _conf)
{
  db_name       = query("db_name");
  form_expires  = query("form_expires");
  anon_user     = query("anon_user");

  if (query("do_email") != 0) {
    mail_subject  = query("mail_subject");
    mail_template = query("mail_template");
    mail_from = query("mail_from");
    mail_server = query("mail_server");
  }

  banned_users = setup_banned_users(query("banned_users"));

  init_db();
  module_dependencies(conf, ({ "sitebuilder" }));
  Site s = site();

  // Only run hooks on backends
  if (s && s->frontend_mode() == 0)
    connect_hook();
}

array(string) setup_banned_users(string list)
{
  list = String.trim_all_whites(list) - "\r";
  array(string) tmp = ({});
  map(list/"\n", lambda (string s) {
    s = String.trim_all_whites(s);
    if (!sizeof(s))
      return 0;

    if (search(s, " ") > -1)
      s = replace(s, " ", ",");

    map(s/",", lambda (string ss) {
      ss = String.trim_all_whites(ss);
      if (sizeof(ss))
        tmp += ({ lower_case(ss) });
    });
  });

  return tmp;
}

/*
void ready_to_receive_requests(Configuration conf)
{
  connect_hook();
}
*/


mapping(string:function) query_action_buttons()
{
  Site s = site();
  if(!s || s->frontend_mode())
    return ([]);

  return ([
    LOCALE(0, "Create Dump") : create_comments_dump,
    LOCALE(0, "Load Dump")   : load_comments_dump,
    LOCALE(0, "Clear")       : clear
  ]);
}


void connect_hook()
{
  Site s = site();
  if (!s) {
    report_warning(module_name + ": Not connected to CMS Main Module.\n");
    hook = 0;
    return;
  }
  hook = s && s->set_event_hooks("comments", 0, sb_after_hook, 0);
}


void clear()
{
  get_db()->query("TRUNCATE TABLE comments");
  get_db()->query("TRUNCATE TABLE comments_mail");
}

void sb_after_hook(string operation, string path, RequestID id,
                   void|mapping info, object obj)
{
  if ((< "dir_change_flat", "file_change" >)[operation]) {
    TRACE("Skipping operation: %s\n", operation);
    return;
  }

  mixed err = catch
  {
    if (!id || !id->misc || !id->misc->wa)
      return;

    object  wa = id->misc->wa;
    mapping md = obj->md;

    switch (operation)
    {
      //| Handle external visibility
      //| This is per se not neccessary since hidden pages comments
      //| will be discarded by the Workarea notifcation, but if we
      //| set the visibility flag directly in the database we will get
      //| smaller datasets when querying the database and thus fewer
      //| iterations and so on...
      case "set_metadata":
        array old_external_use = info->old_md && info->old_md->external_use;
        array new_external_use = info->new_md && info->new_md->external_use;

        if (!equal(new_external_use, old_external_use)) {
          if (new_external_use[1] == VISIBLE_ALWAYS)
            commit_action[path] = set_comments_visible;

          else if (new_external_use[1] == VISIBLE_NEVER)
            commit_action[path] = set_comments_invisible;
        }

        break;

      //| The page is permanently deleted, just clear the comments
      case "purge":
        clear_comments(path);
        break;

      case "undelete":
        commit_action[path] = md->external_use[1] == VISIBLE_ALWAYS ?
                              set_comments_visible : set_comments_invisible;
        break;

      //| Page is moved/renamed
      case "move":
        rollback_action[info->dst] = clear_comments;
        copy_comments(path, info->dst);
        break;

      case "discard":
        if (has_index(rollback_action, path))
          rollback_action[path](path);
        break;

      case "commit":
        string type = info && info->commit_type;
        TRACE("Commit type: %s (%s)\n", type, path);

        switch (type)
        {
          case "delete":
            set_comments_invisible(path);
            break;

          //| Why set_comments_visible on a newly created page?
          //| If we rename/move a Sitebuilder page we copy the
          //| comments to the orginal page and set them invisble.
          //| When the new renamed/moved page the is being checked
          //| in it will have the operation "create" so we need to
          //| set the copied comments to "visible".
          case "create":
            set_comments_visible(path);
            break;

          case "undelete":
          case "edit":
            if (has_index(commit_action, path))
              commit_action[path](path);
            break;
        }

        m_delete(commit_action, path);
        m_delete(rollback_action, path);
        break;
    }
  };

  if (err) {
    cmt_error(
      "\nERROR: clearing/updating comments failed. "
      "This event was not recorded.\n"
      "       Reason: " + describe_backtrace(err) + "\n"
    );
    TRACE("%s\n", describe_backtrace(err));
  }

  /*
  TRACE("sb_after_hook(%O, %O, %O, %O, %O, %O, %O)\n",
            operation, path, id, info, obj, rollback_action[path],
            commit_action[path]);
  */
}


string status()
{
  if (Site s = site()) {
    int|string n = get_db()->query("SELECT COUNT(id) as n FROM comments")[0]->n;
    n = (int)n;
    string cmts = sprintf(
      "There %s <b>%s comment%s</b> in the database",
      (n != 1 ? "are" : "is"), (n > 0 ? (string)n : "no") ,
      (n != 1 ? "s" : "")
    );
    return LOCALE(844,"Connected to") + ": <b>" +
           Roxen.html_encode_string(search(sitebuilders(), s)->query_name()) +
           "</b><br/>" + cmts;
  }
  else
    return "<b>" + LOCALE(845,"Not connected") + "</b>";
}


void init_db()
{
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      cmt_error("No permission to read Form database: %s\n", db_name);
      return;
    }

    report_notice("No comments database present. Creating \"%s\".\n", db_name);

    if(!DBManager.get_group("platform")) {
      DBManager.create_group("platform",
        "Roxen platform",
        "Various databases used by the Roxen "
        "Platform modules",
        ""
      );
    }
    DBManager.create_db(db_name, 0, 1, "platform");
    DBManager.set_permission(db_name, conf, DBManager.WRITE);
    perms = DBManager.get_permission_map()[db_name];
    DBManager.is_module_db(0, db_name,
                           "Used by the Comments Module to "
                           "store its data.");

    if (!get_db()) {
      cmt_error("Unable to create Comments database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
}


Sql.Sql get_db()
{
  return DBManager.get(db_name, conf);
}


SqlResult|int q(mixed ... args)
{
  SqlResult r;
  if (mixed e = catch(r = get_db()->query(@args))) {
    cmt_error("Error in query: %s", describe_backtrace(e));
    return SqlError;
  }

  return r;
}

void setup_tables()
{
  if (Sql.Sql db = get_db()) {
    // db->query("DROP TABLE IF EXISTS comments_mail");
    db->query(#"
      CREATE TABLE IF NOT EXISTS `comments` (
        `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
        `path` VARCHAR(255) DEFAULT NULL,
        `date` DATETIME DEFAULT NULL,
        `visible` ENUM('y','n') DEFAULT 'y',
        `body` BLOB,
        `author` VARCHAR(255) DEFAULT NULL,
        `email` VARCHAR(255) DEFAULT NULL,
        `url` VARCHAR(255) DEFAULT NULL,
        `ip` VARCHAR(255) DEFAULT NULL,
        `owner` ENUM('y','n') DEFAULT 'n',
        `username` VARCHAR(50) DEFAULT NULL,
        `userid` INT(11) UNSIGNED DEFAULT NULL,
        PRIMARY KEY  (`id`)
      ) TYPE=MYISAM"
    );

    db->query(#"
      CREATE TABLE IF NOT EXISTS `comments_mail` (
        `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
        `path` VARCHAR(255) NOT NULL,
        `username` VARCHAR(255) NOT NULL,
        `email` VARCHAR(255) NOT NULL,
        `has_new` ENUM('0','1') NOT NULL DEFAULT '0',
        `notify` ENUM('0','1') DEFAULT '1',
        `hash` VARCHAR(32),
        PRIMARY KEY (`id`),
        KEY (`path`),
        KEY (`username`),
        KEY (`email`)
      ) TYPE=MYISAM"
    );

    db->query(#"
      CREATE TABLE IF NOT EXISTS `likes` (
        `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
        `path` VARCHAR(255) NOT NULL,
        `username` VARCHAR(255) NOT NULL,
        `fullname` VARCHAR(255) NOT NULL,
        PRIMARY KEY (`id`),
        KEY (`path`),
        KEY (`username`)
      ) TYPE=MYISAM
    ");

    if (!sizeof(q("DESCRIBE `comments_mail` notify"))) {
      report_notice("Altered comments_mail table by adding 'notify' column.\n");
      q("ALTER TABLE comments_mail "
        "ADD notify ENUM('0','1') DEFAULT '1' AFTER has_new");
    }

    if (!sizeof(q("DESCRIBE `comments_mail` hash"))) {
      report_notice("Altered comments_mail table by adding 'hash' column.\n");
      q("ALTER TABLE comments_mail "
        "ADD hash VARCHAR(32) AFTER notify");
    }

    if (!sizeof(q("DESCRIBE `likes` fullname"))) {
      report_notice("Altered likes table by adding 'fullname' column.\n");
      q("ALTER TABLE likes "
        "ADD fullname VARCHAR(255) AFTER username");
    }

    DBManager.is_module_table(this_object(), db_name, "comments",      0);
    DBManager.is_module_table(this_object(), db_name, "comments_mail", 0);
    DBManager.is_module_table(this_object(), db_name, "likes",         0);
  }
  else cmt_error("Couldn't get DB connection");
}

string|void create_comments_dump()
// Dump the comments database to a flat file
{
  string file;
  if (Sql.Sql db = get_db()) {
    file = query("dump_file");
    if (!sizeof(file)) {
      report_warning("No dump file specified. Leaving..");
      return;
    }
    file = site()->storage + file;
    object(Stdio.FILE) fh = Stdio.FILE();
    if (fh->open(file + ".t", "ctw")) {
      if (!_dump(fh)) {
        fh->close();
        rm(file + ".t");
        cmt_error(LOCALE(198, "Error writing dump") + "\n");
        return;
      }
      else {
        fh->close();
        if (!mv(file + ".t", file)) {
          cmt_error(
            LOCALE(0,"Error renaming newly written file to dump '%s': %s")+"\n",
            file, strerror(errno())
          );
          return;
        }
      }
    }
    else {
      cmt_error(LOCALE(200, "Error opening file '%s' for write: ") +
                            "%s\n", file, strerror(fh->errno()));
      return;
    }
  }
  else
    return "No database present";

  report_notice("Comments DB dump written to %s", file);
}

string|void load_comments_dump()
// Load the comments dump file into the database
{
  string file;
  if (Sql.Sql db = get_db()) {
    file = query("dump_file");
    if (!sizeof(file)) {
      report_warning("No dump file specified. Leaving..");
      return;
    }
    file = site()->storage + file;

    if (!Stdio.exist(file)) {
      report_warning("The dump file %s doesn't exist", file);
      return;
    }

    object(Stdio.FILE) fh = Stdio.FILE();
    if (!fh->open(file, "r")) {
      cmt_error("Couldn't read dump file %s: %s", file, strerror(fh->errno()));
      return;
    }

    String.SplitIterator sp = fh->line_iterator(1);
    if (sizeof(sp)) {
      do {
        if (mixed e = catch { db->query(utf8_to_string(sp->value()));} )
          cmt_error("Error importing comments dump:\n%s", describe_error(e));
      } while (sp->next());
    }
  }
  else return "No database present";
}

int(0..1) _dump(Stdio.FILE f)
//| Write the DB content to the dump file
{
  string tbl = "";
  SqlResult r = q("SELECT * FROM comments");

  if (r && sizeof(r)) {
    map(r,
      lambda (mapping m) {
        foreach (glob("*.*", indices(m)), string key)
          m_delete(m, key);
      }
    );
  }

  if (!sizeof(r)) {
    report_notice("No comments to dump");
    return 0;
  }

  function quote = get_db()->quote;

  foreach (r, SqlRecord m) {
    array cols = ({}), vals = ({});
    foreach (m; string key; mixed val) {
      cols += ({ key });
      vals += ({ "'" + quote((string)val) + "'" });
    }
    f->write(string_to_utf8(sprintf(
      "INSERT INTO comments (%s) VALUES (%s);\n", cols*",", vals*","
    )));
  }

  r = q("SELECT * FROM comments_mail");

  if (r && sizeof(r)) {
    f->write("\n# Comments mail\n");
    foreach (r, SqlRecord m) {
      array cols = ({}), vals = ({});
      foreach (m; string key; string val) {
        cols += ({ key });
        vals += ({ "'" + quote((string)val) + "'" });
      }
      f->write(string_to_utf8(sprintf(
        "INSERT INTO comments_mail (%s) VALUES (%s);\n", cols*",", vals*","
      )));
    }
  }

  return 1;
}

void copy_comments(string from, string to)
// If someone is moving a Sitebuilder page to a new location we want the
// comments to be copied to. We're setting them to not visible and later
// when the page is commited the comments visibility is set to 'y'
{
  TRACE("Copying comments from /%s to /%s\n", from, to);

  from = prefix(from);
  to   = prefix(to);

  string sql =
    "INSERT INTO comments "
    "  (date, path, visible, body, author, email, ip, url)"
    "  SELECT date, %s, visible, body, author, email, ip, url "
    "  FROM comments WHERE path = %s";

  q(sql, to, from);
  q("UPDATE comments_mail SET path = %s WHERE path = %s", to, from);
}

string prefix(string in)
// Paths in the sb_after_hook has no beginning / so we check if it's there
// and if not we add one
{
  return (has_prefix(in, "/") ? in : "/" + in);
}

void clear_comments(string path)
//| Delete all comments from path "path"
{
  path = prefix(path);
  TRACE("Clearing comments for path '%s'\n", path);
  string sql = "DELETE FROM comments WHERE path = %s";
  if (path) get_db()->query(sql, path);
}

void set_comments_invisible(string path)
// Hide the comments for path "path"
{
  path = prefix(path);
  TRACE("Setting comments invisble for path '%s'\n", path);
  string sql = "UPDATE comments SET visible = 'n' WHERE path = %s";
  if (path) get_db()->query(sql, path);
}

void set_comments_visible(string path)
// Set invisible comments for path "path" visible.
{
  path = prefix(path);
  TRACE("Setting comments visble for path '%s'\n", path);
  string sql = "UPDATE comments SET visible = 'y' WHERE path = %s";
  if (path) get_db()->query(sql, path);
}

string translate_glob(string in)
{
  string out = replace(in, ({ "%" }), ({ "\\%" }));
  return replace(out, ({ "*", "?" }), ({ "%", "_" }));
}

string get_publish_date(RequestID id)
// Get the publish date for the current page.
// This takes "visibility" settings in consideration
{
  object sbobj = id->misc->sbobj;
  if (!sbobj) {
    cmt_error("Couldn't get sbobj for %O", id);
    return 0;
  }

  mapping md = sbobj->metadata(0, 1, -1)->md;
  if (!md) {
    cmt_error("Found no metadata for %O", id);
    return 0;
  }

  VCLogEntry vlog;
  //| Happens on new pages that are unpublished
  if (catch { vlog = get_log(sbobj)[-1]; })
    return 0;

  return md->external_use &&
         sizeof(md->external_use) &&
         md->external_use[0] &&
         replace(Calendar.ISO.Second(md->external_use[0])->iso_name(),"T"," ")
         || vlog->date;
}

array(VCLogEntry) get_log(object/*SBObj*/obj)
{
  array(VCLogEntry) logs;
  if (catch { logs = obj->log(0, 0, 0, 1, 1, 0, 0)->get(0); } )
    return 0;

  return logs;
}

mapping(string:int|AC.Identity) get_perm(RequestID id, string|void _path,
                                         string|void _handle)
{
  int ppid;
  string path = _path || "";
  if (has_prefix(path, "/")) path = path[1..];
  if (has_suffix(path, "/")) path = path[..sizeof(path)-2];
  ppid = id->misc->sb->ac_find_file_pp(path);

  object mac = id->misc->wa && id->misc->wa->mac;
  if (!mac)
    RXML.run_error("Sitebuilder \"comment\" tags used without a site");

  AC.AC_DB db = id->misc->sb && id->misc->sb->get_ac_module() &&
                id->misc->sb->get_ac_module()->online_acdb;

  if (!db) RXML.run_error("No AC connection");

  string handle = _handle || mac->id_get_handle(id);
  RequestID auth_id = (handle != mac->id_get_handle(id)) &&
                      (handle != mac->id_get_id(id)) && id;

  int priv;
  if (mac->id_is_privileged(id))
    priv = 1;

  int everyone;
  if (mac->id_is_everyone(id))
    everyone = 1;

  AC.Identity identity;
  AC.AC_DB.lock lock = db->lock();
  if (!handle) {
    if (priv)
      identity = db->identities->privileged();
    else if (everyone)
      identity = db->identities->everyone();
  }
  else if (sizeof(handle) &&
           !(identity = db->identities->find_by_handle(handle, auth_id)))
  {
    int idid = (int)handle;
    if (idid) identity = db->identities->get(idid, 0);
  }

  lock = 0;
  if (!identity) {
    TRACE("Unknown identity '%s'.\n", handle);
    RXML.run_error("Unknown identity '%s'.\n", handle);
  }

  int perm = mac->id_get_perm(identity->id(), ppid);

  return ([ "identity" : identity, "permission" : perm ]);
}

void send_mail(int id, string path, mapping user, string email,
               void|int(0..1) notify, void|string subject,
               void|string template,
               void|string owner_email,
               void|string owner_template)
{
  SqlResult r = q("SELECT t1.id AS id, t1.path AS path, "
                  " t1.username AS username, t1.email AS email, "
                  " t1.has_new AS has_new, t1.hash AS hash, "
                  " t2.author AS author "
                  "FROM comments_mail t1 "
                  "LEFT JOIN comments t2 "
                  " ON t2.username = t1.username "
                  "WHERE t1.path = %s AND t2.visible = 'y' "
                  " AND t1.notify = '1' "
                  "GROUP BY t1.email", path);

  int(0..1) insert = 1;
  array(string) owners = ({});
  email = lower_case(email);

  if (owner_email && sizeof(owner_email)) {
    owners = map(owner_email/",",
                 lambda (string s) {
                   return String.trim_all_whites(lower_case(s));
                 }) - ({ "" });

    TRACE("Comments page owners: %O\n", owners);
  }

  if (r && sizeof(r)) {
    array receivers = ({});
    string tmpl = template||mail_template;
    string subj = subject||mail_subject;

    foreach (r, mapping m) {
      if (has_value(owners, lower_case(m->email)))
        continue;

      if (lower_case(m->email) == email) {
        TRACE(" >>> User already in DB\n");
        insert = 0;
        if (m->has_new == "1") {
          q("UPDATE comments_mail SET has_new = '0' "
            "WHERE path = %s AND email = %s", path, email);
        }
        continue;
      }

      if (m->has_new == "0") {
        array from = ({ "[url]","[id]","[receiver]","[commenter]","[hash]" });
        array to   = ({ path, (string)id, m->author,
                        (user && user->name)||anon_user, m->hash||"" });
        string t;
        if (mixed e = catch(t = replace(template, from, to))) {
          cmt_error("Error when trying to create mail template: %O",
                    describe_error(e));
        }
        else
          low_send_mail(subj, m->email, t);

        q("UPDATE comments_mail SET has_new = '1' WHERE id = %s", m->id);
      }
    }
  }

  int(0..1) leave_early = 0;

  if (email) {
    if (has_value(owners, lower_case(email)))
      leave_early = 1;

    owners -= ({ lower_case(email) });
  }

  if (sizeof(owners) && owner_template && sizeof(owner_template)) {
    TRACE("Send mail to owners...\n");

    array from  = ({ "[url]","[id]","[commenter]" });
    array to    = ({ path, (string)id, (user && user->name)||anon_user });
    string subj = subject || mail_subject;
    string text = replace(owner_template, from, to);
    TRACE("Message to send: %s\n", text);
    low_send_mail(subj, owners*",", text);
  }

  if (leave_early) {
    TRACE("Commenter same as page owner (%s). Skip adding to DB\n", email);
    return;
  }

  if (insert && notify && (email && sizeof(email))) {
    string hash = path + email;
    hash = MD5(hash);
    q("INSERT INTO comments_mail (path, username, email, hash) "
      "VALUES (%s, %s, %s, %s)", path, user && user->handle, email, hash);
  }
}

void low_send_mail(string subject, string to, string message)
{
#if constant(Protocols.SMTP.Client)
  Protocols.SMTP.Client cli;
#else
  Protocols.SMTP.client cli;
#endif

  if (mixed e = catch {
#if constant(Protocols.SMTP.Client)
    cli = Protocols.SMTP.Client(mail_server);
#else
    cli = Protocols.SMTP.client(mail_server);
#endif
    }
  ) {
    cmt_error("%s", describe_error(e));
    return;
  }

  if (mixed e = catch(cli->simple_mail(to, subject, mail_from, message)))
    cmt_error("Couldn't send mail: %s", describe_backtrace(e));
}

void update_mail_status(string path, int(0..1)|string st, string user,
                        void|int email)
{
  path = prefix(path);
  st = (int)st == 1;

  if (email) {
    q("UPDATE comments_mail SET has_new=%s WHERE path=%s AND email=%s",
      (string)st, path, email);
  }
  else if (user && user != "Everyone") {
    q("UPDATE comments_mail SET has_new=%s "
      "WHERE path=%s AND username=%s", (string)st, path, user);
  }
}



class TagEmitCommentsPlugin
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "comments";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "invisible" : RXML.t_text(RXML.PXml),
    "path"      : RXML.t_text(RXML.PXml),
    "username"  : RXML.t_text(RXML.PXml),
    "sort"      : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    if (!args->path)
      args->path = id->misc->localpath;

    mapping perm = get_perm(id, args->path);
    string handle = perm && perm->identity->handle();

    args->path = prefix(args->path);

    if (handle) update_mail_status(args->path, 0, handle);

    object wa = id->misc->wa;
    object sbobj = id->misc->sbobj;

    function quotefn = get_db()->quote;
    array paths = args->path/",";
    paths = map(map(map(paths, String.trim_all_whites), quotefn),
                translate_glob);

    array w = ({});

    if (args->username)
      w = ({ "`username` = '" + quotefn(args->username) + "'" });
    else {
      foreach (paths, string path) {
        string n = search(path, "%") > -1 ? "LIKE" : "=";
        w += ({ "`path` " + n + " '" + path + "'" });
      }
    }

    string sql = "SELECT * FROM `comments` WHERE " + (w * " OR ");

    if (!args->invisible)
      sql += " AND `visible` = 'y'";

    if (args->username)
      sql += " GROUP BY `path`";

    if (args->sort) {
      if (args->sort[0] == '-')
        sql += " ORDER BY " + quotefn(args->sort[1..]) + " DESC";
      else
        sql += " ORDER BY " + quotefn(args->sort[1..]);
    }
    else
      sql += " ORDER BY `id`";

    if (args["max-rows"] && args->skip) {
      sql += sprintf(" LIMIT %s,%s ", quotefn(args->skip),
                     quotefn(args["max-rows"]));
    }
    else if ( args["max-rows"] )
      sql += " LIMIT " + quotefn(args["max-rows"]);

    YTRACE("%s\n", sql);

    SqlResult res = q(sql);

    //YTRACE("%O\n", res);

    //| Should be enough!
    int limit = 100000 || (int)args->maxrows;
    mapping sb_cache = ([]);
    mapping skip = ([]);
    string|mapping titles;
    mapping(string:string) title;
    mapping(string:string) lang;

    array(mapping(string:string)) comments = ({});

    foreach (res, mapping m) {
      if (has_index(skip, m->path))
        continue;

      if (!sb_cache[m->path])
        sb_cache[m->path] = wa->sbobj_va(m->path, id);

      sbobj = sb_cache[m->path];

      if (!sbobj) {
        YTRACE("Missing file ignored: %O\n", m->path);
        skip[m->path] = 1;
        continue;
      }

      if (!sbobj->exists(id)) {
        YTRACE("Deleted file ignored: %O\n", m->path);
        skip[m->path] = 1;
        continue;
      }

      // Hidden by workflow?
      if(!sbobj->is_valid_op(id, "metadata", 0, 0)) {
        YTRACE("Can not get metadata for %O\n", m->path);
        skip[m->path] = 1;
        continue;
      }

      mapping|object md = sbobj->metadata(id, 0);

      if (mappingp(md)) {
        cmt_error("Unexpected error from metadata(): %s\n",
                  Sitebuilder.error_msg(md));
      }

      md = md->md;

      if(!get_current_visibility(sbobj, md->external_use)) {
        YTRACE("Time published file ignored %O\n", m->path);
        skip[m->path] = 1;
        continue;
      }

      titles = md->title;

      if (mappingp(titles)) {
        array(string) langs = indices(titles);
        lang = ([ "languages" : langs * "," ]);
        string pref_lang = ((id->misc->sb_lang & langs) + ({ "" }) )[0];
        title = ([ "page-title" : (titles[pref_lang] ||
                                  titles[md["original-language"]]) ]);
      }
      else if (stringp(titles))
        title = ([ "page-title" : titles ]);

      if (title) m += title;
      if (lang) m+= lang;

      title = 0;
      lang = 0;
      m_delete(m, "titles");

      comments += ({ m });

      if (sizeof(comments) >= limit)
        break;
    }

    return comments;
  }
}

class TagCommentAdd
{
  inherit RXML.Tag;
  constant name = "comment-add";

  mapping(string:RXML.Type) req_arg_types = ([]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "path"          : RXML.t_text(RXML.PXml),
    "url"           : RXML.t_text(RXML.PXml),
    "author"        : RXML.t_text(RXML.PXml),
    "email"         : RXML.t_text(RXML.PXml),
    "identity"      : RXML.t_text(RXML.PXml),
    "guest"         : RXML.t_text(RXML.PXml),
    "insert-id"     : RXML.t_text(RXML.PXml),
    "notify"        : RXML.t_text(RXML.PXml),
    "mail-template" : RXML.t_text(RXML.PXml),
    "mail-subject"  : RXML.t_text(RXML.PXml),
    "owner-email"   : RXML.t_text(RXML.PXml),
    "owner-mail-template" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      string body = String.trim_all_whites(content) || "";
      body = Roxen.html_decode_string(body);

      int notify = args->notify && sizeof(args->notify) > 0;

      args->path = args->path ? prefix(args->path) :
                                prefix(id->misc->localpath);

      string handle;
      if (args->identity)
        handle = args->identity;

      VCLogEntry log = get_log(id->misc->sbobj)[-1];
      mapping mperm = get_perm(id, args->path, handle);
      int uid = mperm->identity->id() || 0;
      handle = (string)mperm->identity->handle();

      if (handle && sizeof(banned_users)) {
        if (has_value(banned_users, lower_case(handle))) {
          _ok = 0;
          return 0;
        }
      }

      string owner = (uid == log->userid) ? "y" : "n";

      if (!args->author || (args->author && !strlen(args->author))) {
        //! Everyone
        if (uid == 1)
          args->author = args->guest || anon_user;
        else
          args->author = mperm->identity->name();
      }

      if (args->url && sizeof(args->url)) {
        if (!has_prefix(args->url, "http"))
          args->url = "http://" + args->url;
      }

      string sql = #"
      INSERT INTO comments(
        path, date, body, author, email, url, owner, userid, username
      ) VALUES ( %s, NOW(), %s, %s, %s, %s, %s, %d, %s )";

      int insert_id = 0;
      Sql.Sql db = get_db();
      mixed e = catch {
        db->query(sql, args->path, body, args->author, args->email,
                  args->url || "", owner, uid, handle);

        insert_id = db->master_sql->insert_id();
      };

      _ok = 1;

      if (e) {
        cmt_error("Error adding comment: %s", describe_error(e));
        TRACE("mperms(%O),\nhandle(%O)\n", mperm, handle);
        _ok = 0;
      }

      if (query("do_email") != 0) {
        mapping user = ([ "name" : args->author, "handle" : handle ]);
        send_mail(insert_id, args->path, user, args->email, notify,
                  args["mail-subject"], args["mail-template"],
                  args["owner-email"], args["owner-mail-template"]);
      }

      RXML.user_set_var(args["insert-id"]||"var.insert-id", (string)insert_id);
      result = "";
      return 0;
    }
  }
}

class TagIfCommentFormExpiredPlugin
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "comment-form-expired";

  mapping(string:RXML.Type) opt_arg_types = ([
    "days" : RXML.t_text(RXML.PXml)
  ]);

  int eval(string a, RequestID id, mapping args)
  {
    int exp = (int)args->days || form_expires;
    if (exp == 0) return 0;

    string|Calendar.TimeRange pub = get_publish_date(id);
    if (!pub) return 0;

    pub = Calendar.parse("%Y-%M-%D%c%h:%m:%s", pub)->day();
    Calendar.TimeRange now = Calendar.Second(time(1))->day();

    int diff;
    mixed e = catch {
      diff = pub->distance(now)->number_of_days();
    };

    if (e)
      report_error("Error: %s", describe_backtrace(e));

    if (!diff) return 0;

    return diff >= exp ? 1 : 0;
  }
}

class TagIfCommentAdminPermission
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "comment-admin-permission";

  mapping(string:RXML.Type) opt_arg_types = ([
    "identity" : RXML.t_text(RXML.PXml),
    "id"       : RXML.t_text(RXML.PXml)
  ]);

  int eval(string a, RequestID id, mapping args)
  {
    int admin = 0;
    string path = a || 0;
    string handle = args->identity || 0;
    mapping mperm = get_perm(id, path, handle);

    if (args->id) args->id = (int)args->id;
    if (mperm->permission == 2) admin = 1;
    if (args->id && !admin && mperm->identity->id() != 1) {
      mapping c = get_db()->query("SELECT userid FROM comments "
                                  "WHERE id = %d LIMIT 1", args->id)[0];
      if ((int)c->userid == mperm->identity->id())
        admin = 1;
    }

    return admin;
  }
}

class TagIfCommentBannedUser
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "comment-banned-user";

  int eval(string a, RequestID id, mapping args)
  {
    if (!sizeof(banned_users))
      return 0;

    return has_value(banned_users, lower_case(a));
  }
}

class TagEmitCommentBannedUsers
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "comment-banned-users";

  array get_dataset(mapping args, RequestID id)
  {
    return map(banned_users, lambda (string s) {
      return ([ "value" : s ])  ;
    });
  }
}

class TagCommentFormExpires
{
  inherit RXML.Tag;
  constant name = "comment-form-expires";

  mapping(string:RXML.Type) opt_arg_types = ([
    "days" : RXML.t_text(RXML.PXml),
    "type" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      int exp = (int)args->days || form_expires;

      if (exp == 0) {
        result = RXML.nil;
        return 0;
      }

      if (!args->type) {
        result = (string)exp;
        return 0;
      }

      string|Calendar.TimeRange pub = get_publish_date(id);
      if (pub)
        pub = Calendar.parse("%Y-%M-%D%c%h:%m:%s", pub)->day()->add(exp);
      else
        pub = Calendar.Second(time(1))->day()->add(exp);

      switch (args->type) {
        case "days":
          if (pub < 0) {
            result = "0";
            return 0;
          }

          Calendar.TimeRange now = Calendar.Second(time(1))->day();
          Calendar.TimeRange diff = now->distance(pub);
          result = (string)diff->number_of_days();
          break;

        case "date":
          result = pub->format_ext_ymd();
          break;
      }
      return 0;
    }
  }
}

class TagCommentDelete
{
  inherit RXML.Tag;
  constant name = "comment-delete";

  mapping(string:RXML.Type) req_arg_types = ([
    "id" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      SqlResult r = q("SELECT * FROM comments WHERE id = %d", (int)args->id);

      if (q("DELETE FROM comments WHERE id = %d", (int)args->id) != SqlError)
        _ok = 1;
      else
        _ok = 0;

      if (r && arrayp(r) && sizeof(r)) {
        SqlRecord m = r[0];
        q("DELETE FROM comments_mail WHERE path = %s AND email = %s",
          m->path, m->email);
      }

      return 0;
    }
  }
}

class TagCommentsCount
{
  inherit RXML.Tag;
  constant name = "comments-count";

  mapping(string:RXML.Type) req_arg_types = ([
    "path" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      string sql = "SELECT COUNT(id) AS num FROM comments "
                   "WHERE path = %s AND visible = 'y'";
      array(mapping) res;
      mixed err = catch { res = get_db()->query(sql, args->path); };
      result = err ? "0" : res[0]->num;
      return 0;
    }
  }
}

class TagCommentsUnsubscribe
{
  inherit RXML.Tag;
  constant name = "comments-unsubscribe";

  mapping(string:RXML.Type) req_arg_types = ([
    "hash" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      if (mixed e = catch(get_db()->query("DELETE FROM comments_mail "
                                          "WHERE hash = %s", args->hash)))
      {
        report_error("Couldn't delete subscription for %s:\n%s",
                     args->hash, describe_backtrace(e));
        _ok = 0;
        return 0;
      }

      _ok = 1;
      return 0;
    }
  }
}

class TagEmitCommentPlugin
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "comment";

  mapping(string:RXML.Type) req_arg_types = ([
    "id" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string sql = "SELECT * FROM comments WHERE id = %d LIMIT 1";
    array(mapping(string:string)) res;
    res = get_db()->query(sql, (int)args->id);
    if (!res || sizeof(res) == 0)
      RXML.run_error("The requested comment doesn't exist");

    return res;
  }
}

class TagCommentUpdate
{
  inherit RXML.Tag;
  constant name = "comment-update";

  mapping(string:RXML.Type) req_arg_types = ([
    "id" : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "author" : RXML.t_text(RXML.PXml),
    "email"  : RXML.t_text(RXML.PXml),
    "url"    : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      string body = String.trim_all_whites(content) || "";

      mapping in_args = ([]);
      array in_values = ({});

      in_args += ([ "body" : Roxen.html_decode_string(body) ]);

      if (args->author)
        in_args += ([ "author" : args->author ]);

      if (args->email)
        in_args += ([ "email" : args->email ]);

      if (args->url) {
        if (!has_prefix(args->url, "http"))
          args->url = "http://" + args->url;

        in_args += ([ "url" : args->url ]);
      }

      string sql = "UPDATE comments SET ";

      foreach (indices(in_args), string key) {
        sql += sprintf("%s = %%s,", key);
        in_values += ({ (string)in_args[key] });
      }

      sql = sql[0..strlen(sql)-2] + " WHERE id = %d";

      in_values += ({ (int)args->id });

      TRACE("UPDATE SQL: %s\n", sprintf(sql, @in_values));

      if (q(sql, @in_values) != SqlError)
        _ok = 1;
      else
        _ok = 0;

      return 0;
    }
  }
}

class TagCommentSetMailStatus
{
  inherit RXML.Tag;
  constant name = "comment-set-mailstatus";

  mapping(string:RXML.Type) req_arg_types = ([
    "path" : RXML.t_text(RXML.PXml),
    "status" : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "handle" : RXML.t_text(RXML.PXml),
    "email" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      if (args->email && sizeof(String.trim_all_whites(args->email)))
        update_mail_status(args->path, args->status, 0, args->email);
      else {
        mapping perm = get_perm(id, args->path);
        string handle = args->handle || (perm && perm->identity->handle());
        update_mail_status(args->path, args->status, handle);
      }
      return 0;
    }
  }
}

// Like tags

class TagEmitLikesPlugin
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "likes";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "path"      : RXML.t_text(RXML.PXml),
    "count"     : RXML.t_text(RXML.PXml),
    "count-ext" : RXML.t_text(RXML.PXml),
    "comments"  : RXML.t_text(RXML.PXml),
    "json"      : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    if (!args->path) args->path = id->misc->localpath;

    array(string) paths = map(args->path/",", String.trim_all_whites);

    if (args->count) {
      array(mapping) ret = ({});

      foreach (paths, string path) {
        path = prefix(path);

        SqlResult r = q("SELECT COUNT(id) AS likes FROM `likes` WHERE path=%s",
                        path);

        mapping out = ([ "path" : path,
                         "likes" : r && sizeof(r) && (int)r[0]->likes ]);

        if (args->comments) {
          string sql = "SELECT COUNT(id) AS num FROM comments "
                       "WHERE path=%s AND visible = 'y'";
          r = q(sql, path);

          out->comments = r && sizeof(r) && (int)r[0]->num;
        }

        ret += ({ out });
      }

      return ret;
    }
    else {
      mapping perm = get_perm(id, args->path);
      string handle = perm && perm->identity->handle();

      if (sizeof(paths) > 1 || args["count-ext"]) {
        array(mapping) ret = ({});

        foreach (paths, string path) {
          mapping out = ([ "path" : path ]);

          SqlResult res = q("SELECT username, fullname FROM `likes` "
                            "WHERE path=%s", prefix(path));
          if (res) {
            array(string) users = res->username || ({});

            out->likes = ([
              "likes" : sizeof(res),
              "user-has-liked" : has_value(users, handle),
              "users" : res
            ]);

          }

          if (args->comments) {
            string sql = "SELECT COUNT(id) AS num FROM comments "
                         "WHERE path=%s AND visible = 'y'";
            res = q(sql, prefix(path));
            out->comments = res && sizeof(res) && (int) res[0]->num;
          }

          ret += ({ out });
        }

        if (args->json) {
          ret = ({ ([ "json" : Standards.JSON.encode(ret) ]) });
        }

        //TRACE("%O\n", ret);

        return ret;
      }
      else if (sizeof(paths) == 1) {
        SqlResult res = q("SELECT username, fullname FROM `likes` "
                          "WHERE path=%s", prefix(paths[0]));
        if (res) {
          array(string) users = res->username || ({});
          int(0..1) has_liked = has_value(users, handle);
          SqlRecord liked_user;

          if (has_liked) {
            SqlResult r = map(res, lambda(SqlRecord row) {
              if (row->username == handle) {
                liked_user = row;
                return 0;
              }

              return row;
            }) - ({ 0 });

            res = r;
          }

          mapping out = ([
            "likes" : sizeof(res),
            "user-has-liked" : has_liked,
            "current-user" : liked_user,
            "users" : res
          ]);

          if (args->json)
            out = ([ "json" : Standards.JSON.encode(out) ]);

          return ({ out });
        }
      }
    }

    return ({});
  }
}

class TagLike
{
  inherit RXML.Tag;
  constant name = "like";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "path" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      if (!args->path) args->path = id->misc->localpath;
      args->path = prefix(args->path);

      mapping perm = get_perm(id, args->path);
      string handle = perm && perm->identity->handle();
      string name = perm && perm->identity->name();

      SqlResult res = q("SELECT id FROM likes WHERE username = %s "
                        "AND path = %s", handle, args->path);

      if (!sizeof(res)) {
        q("INSERT INTO likes (path, username, fullname) VALUES (%s, %s, %s)",
          args->path, handle, name);
      }
      else {
        q("DELETE FROM likes WHERE path=%s AND username=%s",
          args->path, handle);
      }

      _ok = 1;

      return 0;
    }
  }
}

//| {{{ TAGDOCUMENTATION
//|
//| ============================================================================
TAGDOCUMENTATION;
#ifdef manual

//| Shared entites for emit#comments and emit#comment
constant CMT_ENT = ([
  "&_.id;" :
  "<desc type='entity'><p>Comment id</p></desc>",

  "&_.date;" :
  "<desc type='entity'><p>ISO date when the comment was added</p></desc>",

  "&_.author;" :
  "<desc type='entity'><p>The autor of the comment</p></desc>",

  "&_.email;" :
  "<desc type='entity'><p>The comment authors email</p></desc>",

  "&_.url;" :
  "<desc type='entity'><p>The comment authors website</p></desc>",

  "&_.path;" :
  "<desc type='entity'>"
  "  <p>The path to the page to which the comment belong</p>"
  "</desc>",

  "&_.ip;" :
  "<desc type='entity'><p>The IP address of the comment author</p></desc>",

  "&_.visible;" :
  "<desc type='entity'><p>Is the comment visible or not (y or n)</p></desc>",

  "&_.body;" :
  "<desc type='entity'><p>The actual comment</p></desc>",

  "&_.username;" :
  "<desc type='entity'>"
  "  <p>The comment authors internal username if authenticated</p>"
  "</desc>",

  "&_.userid;" :
  "<desc type='entity'>"
  "  <p>The comment authors internal user id if authenticated</p>"
  "</desc>",

  "&_.owner;" :
  "<desc type='entity'>"
  "  <p>Is the comment by the page author (y or n)</p>"
  "</desc>"
]);

constant tagdoc = ([

"emit#comments" : ({ #"
<desc type='plugin'><p><short>
  Emit that list comments.
</short></p></desc>

<attr name='path' value='path' optional=''>
<p>
  List comments to path <em>path</em>. Can cointain globs to list
  comments for all pages below a given directory structure and can be
  a list of comma separated paths. If no path is given the current path
  is used.
</p>

<ex-box><h2>Latest comments</h2>
<ul>
  <emit source='comments' path='/articles/*,/blog/*' sort='-date' maxrows='10'>
    <li>
      <a href='&_.path;#comment-&_.id;'>
        <strong>&_.author;</strong>
        <date type='iso' iso-time='&_.date;' date='' /><br/>
        <small>To: &_.page-title;</small>
      </a>
    </li>
  </emit>
</ul></ex-box>
</attr>

<attr name='invisible' value='invisible' optional=''>
  <p>Include comments that is set to invisble</p>
</attr>
", CMT_ENT + ([
"&_.page-title;" :
  "<desc type='entity'>"
  "  <p>The title of the page the comment belongs to</p>"
  "</desc>"
])
}),

// =============================================================================

"emit#comment" : ({ #"
<desc type='plugin'><p><short>
  Emit a given comment. Useful when grabbing a specific comment for editing.
</short></p></desc>

<attr name='id' value='int' required=''>
  <p>The ID of the comment to emit</p>
</attr>", CMT_ENT
}),

// =============================================================================

"comment-add" : ({ #"
<desc type='cont'><p><short>
  Add a comment. The content should be the actual comment
</short></p>
<ex-box>
<comment-add
  path='&page.path;' author='&form.author;' email='&form.email;'
  url='&form.website;'
>&form.comment;</comment-add>
</ex-box>
</desc>

<attr name='path' value='path' optional=''>
  <p>The path of the CMS page to add the comment to. If not given
  the current path will be used.</p>
</attr>

<attr name='author' value='author name' optional=''>
  <p>The name of the comment author</p>
</attr>

<attr name='email' value='author email' optional=''>
  <p>The email of the comment author</p>
</attr>

<attr name='url' value='author website' optional=''>
  <p>The website URL of the comment author</p>
</attr>

<attr name='identity' value='number|handle' optional=''>
  <p>Add the comment as this user. The value should be either a user id
  or a users handle (username). If omitted, the currently logged on user is
  used.</p>
</attr>

<attr name='guest' value='string' default='Guest' optional=''>
  <p>If no authentication is required to add a comment and no author name
  is required either, i.e anonymous comments are allowed, this value will be
  added to the \"author\" column in the database table.</p>
  <p>The default value of this can be set under \"settings\" in the module
  tab</p>
</attr>
"}),

// =============================================================================

"comment-update" : ({ #"
<desc type='cont'><p><short>
  Update a comment. The content should be the actual comment
</short></p>
<ex-box>
<comment-update
  id='&form.id;' author='&form.author;' email='&form.email;'
  url='&form.website;'
>&form.comment;</comment-add>
</ex-box>
</desc>

<attr name='id' value='comment id' required=''>
  <p>The id of the comment to update</p>
</attr>

<attr name='author' value='author name' optional=''>
  <p>The name of the comment author</p>
</attr>

<attr name='email' value='author email' optional=''>
  <p>The email of the comment author</p>
</attr>

<attr name='url' value='author website' optional=''>
  <p>The website URL of the comment author</p>
</attr>"
}),

// =============================================================================

"comment-delete" : ({ #"
<desc type='tag'><p><short>Delete a comment</short></p></desc>
<attr name='id' value='comment id' required=''>
  <p>The ID of the comment to delete</p>
</attr>
"
}),

// =============================================================================

"comments-count" : ({ #"
<desc type='tag'><p><short>Count comment for a given page</short></p></desc>
<attr name='path' value='path' required=''>
  <p>The path of the page to count the comments for.</p>
  <ex-box>There is <comments-count path='&page.path;' /> comments</ex-box>
</attr>
"
}),

// =============================================================================

"if#comment-form-expired" : ({ #"
<desc type='plugin'><p><short>
  Check if the possibility to add comments has expired or not
</short></p>
<p>The number of days commenting is allowed is set in the module settings</p>
<ex-box><if comment-form-expired='' not=''>
  <vform>
    ...
  </vform>
</if><else>
  <p>Commenting has been disabled</p>
</else></ex-box>
</desc>

<attr name='days' value='int' optional=''>
  <p>Override the expiration value in the module settings.</p>
</attr>
"
}),

// =============================================================================

"if#comment-admin-permission" : ({ #"
<desc type='plugin'>
  <p><short>Check if a user has the rights to edit comments.</short></p>
  <p>Per default a user who has write permission to the page also has
  admin permissions to all comments beloning to that page</p>
</desc>

<attr name='comment-admin-permission' value='path|void'>
  <p>The protection point to test. If there is no protection point on the
  given path, the path is searched towards the root for the controlling
  protection point.</p>
</attr>

<attr name='identity' value='handle|id' optional=''>
  <p>The identity to check the permission for. If omitted, the currently
  logged on user is used.</p>
</attr>

<attr name='id' value='int' optional=''>
  <p>A comment ID to check against. This can be useful in environments where
  only authenticated users exist which can give the user the ability to edit
  its own comments</p>
<ex-box>
<ol>
  <emit source='comments' path='&page.path;'>
    <div class='comment-header'>
      <strong>&_.author; wrote on <date date='' iso-time='&_.date;' /></strong>
    </div>
    <autoformat p=''>&_.body;</autoformat>
    <if comment-admin-permission='&page.path;' id='&_.id;'>
      <div class='comment-action'>
        <a href='&page.self;?edit=&_.id;'>Edit</a> |
        <a href='&page.self;?delete=&_.id;'>Delete</a>
      </div>
    </if>
  </emit>
</ol>
</ex-box>
</attr>
"
}),

// =============================================================================

"comment-form-expires" : ({ #"
<desc type='tag'><p><short>
  Returns the default number of days the comment form should live.
</short></p></desc>

<attr name='type' value='days|date' optional=''>
<p><ul>
  <li><em>'days'</em> returns how many days there is left before the
  form expires</li>
  <li><em>'date'</em> returns the date when the form expires</li>
</ul></p>
<ex-box>
The form expires in <comment-form-expires type='days' /> days
The form expires <comment-form-expires type='date' />
</ex-box>
</attr>

<attr name='days' value='int' optional=''>
  <p>Modifier for how many days the form is supposed to live. This overrides
  the setting in the module settings</p>
</attr>
"
})
]);
#endif
