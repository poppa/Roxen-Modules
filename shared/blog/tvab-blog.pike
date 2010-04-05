//| tvab-blog.pike
//|
//| @author Pontus Östlund <pontus.ostlund@tekniskaverken.se>
//| @version 0.1
//| @todo
//|
//| Tab width 8
//| Indent width 2

//#define BLOG_DEBUG
#define TRIM(s) String.trim_all_whites(s)

#ifdef BLOG_DEBUG
# define TRACE(X...) report_debug("Blog: " + sprintf(X))
#else
# define TRACE(X...) 0
#endif

#include <module.h>
#include <config.h>
inherit "module";

import Sitebuilder;
import Sitebuilder.FS;
import Parser.XML.Tree;

inherit SBConnect;

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y) _DEF_LOCALE("sitebuilder",X,Y)

constant thread_safe = 1;
constant module_type = MODULE_TAG;
string module_name = "TVAB Blog: main module";
LocaleString module_doc = DLOCALE(0, #"
<p>This module listens on the SiteBuilder event hook and should always
be connected to a SiteBuilder module.</p>

<p>Tekniska Verken's blog module</p>");

Configuration conf;
string db_name;
object hook;

string xsl_config_filename;
string blog_component_name = "tvab-blog-entry-component";
array(string) blog_roots;
array(string) valid_blog_location_files;
array(string) valid_content_types = ({ "sitebuilder/xml-page-editor",
                                       "text/xml" });

typedef mapping(string:string) SqlRow;
typedef array(SqlRow) SqlRes;

void blog_error(mixed ... args) // {{{
{
  if (args[0][-1] != '\n') args[0] += "\n";
  report_error("Blog: " + args[0], @args[1..]);
} // }}}

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus Östlund <pontus.ostlund@tekniskaverken.se>");

  defvar("allow_blog_component_paths",
    ({ "*" }), "Allowed blog component paths",
    TYPE_STRING_LIST,
    "Paths (in glob pattern form) where TVAB Blog components can reside."
  );

  defvar("blog_roots",
    ({ }), "Blog roots",
    TYPE_STRING_LIST,
    "Directories that contains one or more blogs"
  );

  defvar("config_file_name", 
    Variable.String(
      "blog.config.xsl", 0,
      "Blog config file",
      "The name of each blog's configuration file"
    )
  );

  defvar("db_name",
    Variable.DatabaseChoice(
      "blog_" + (_conf ? Roxen.short_name(_conf->name):""), 0,
      "BLOG module database",
      "The database where we store blog related info"
    )->set_configuration_pointer(my_configuration)
  );

  defvar("sitebuilder",
    ChooseSiteVariable(
      conf, VAR_INITIAL,
      DLOCALE(842,"SiteBuilder"),
      DLOCALE(843,"The SiteBuilder to connect to.")
    )
  );

  visible_chooser = CHOOSE_SITE;
} // }}}

void start(int when, Configuration _conf) // {{{
{
  ::start(when, _conf);

  conf = _conf;
  db_name = query("db_name");

  init_db();

  module_dependencies(conf, ({ "sitebuilder" }));

  connect_hook();

  xsl_config_filename = query("config_file_name");
  valid_blog_location_files = ({});
  foreach(query("allow_blog_component_paths"), string path) {
    if(glob("/*", path))
      valid_blog_location_files += ({ path[1..] });
    else
      valid_blog_location_files += ({ path });
  }

  blog_roots = ({});
  foreach (query("blog_roots")||({}), string br) {
    if (has_prefix(br, "/"))
      br = br[1..];
    if (!has_suffix(br, "*")) {
      if (!has_suffix(br, "/"))
	br += "/";
      br += "*";
    }

    blog_roots += ({ br });
  }
} // }}}

void connect_hook() // {{{
{
  Site s = site();

  if(!s) {
    report_warning(module_name + ": Not connected to CMS Main Module.\n");
    hook = 0;
    return;
  }

  hook = s->set_event_hooks(module_name, 0, sb_after_hook, 0);
} // }}}

int reindex_iterations = 0;
int(0..1) is_reindexing = 0;

void reindex() // {{{
{
  is_reindexing = 1;
  call_out(low_reindex, 0);
} // }}}

void low_reindex() // {{{
{
  clear();

  Site s;
  if (!(s = site())) {
    blog_error("Not connected!\n");
    return;
  }

  TRACE("Reindex");

  Workarea wa = s->wa_lookup("");

  if (!wa) {
    blog_error("Unable to lookup workarea");
    return ;
  }

  Sql.Sql db = get_db();

  if (!db) {
    blog_error("Not connected to database");
    return;
  }

  mixed err = catch {
    mapping tmp = ([]);
    mapping tmp2 = ([]);
    foreach (({ wa->sbobj_va("", 0) }), Sitebuilder.FS.SBObject sbdir) {
      sb_get_paths(0, sbdir, tmp,
                   ({ "sitebuilder/xml-page-editor", "text/xml" }),
		   valid_blog_location_files);

      sb_get_xsl_paths(0, sbdir, tmp2, ({ "sitebuilder/xsl-template" }),
                          blog_roots);
    }

    roxen.InternalRequestID fake_id = roxen.InternalRequestID();
    fake_id->conf = conf;
    
    foreach (indices(tmp), string path) {
      SBObject obj = wa->sbobj_va(path, 0);
      fake_id->not_query = "/" + obj->real_abspath();

      if (mixed handle_err = catch(handle_document(obj, path, fake_id)))
	blog_error("Reindexing of a page failed\n" +
                   describe_backtrace(handle_err) + "\n");
    }

    destruct(fake_id);
  };

  if (err)
    blog_error("Reindexing failed\n" + describe_backtrace(err) + "\n");
  else
    report_notice("Blog database reindexed.\n");

  is_reindexing = 0;
} // }}}

void sb_get_paths(RequestID id, Sitebuilder.FS.SBObject sbobject, mapping  tmp,
                  array content_types, array allowed_paths) // {{{
{
  if (sbobject->isdir) {
    mapping|array(object) list =
      sbobject->list(id, 0, !id)->is_user_op(id, "metadata", 0, !id) - ({0});

    foreach (list, Sitebuilder.FS.SBObject child)
      sb_get_paths(id, child, tmp, content_types, allowed_paths);
  }
  else {
    if (sb_file_viewable(id, sbobject) &&
        search( content_types, sbobject->md["http-content-type"] ) > -1)
    {
      string path = sbobject->abspath(id,0,!id);
      if (is_valid_location_path(path, allowed_paths))
	tmp[path] = 1;
    }
  }
} // }}}

void sb_get_xsl_paths(RequestID id, Sitebuilder.FS.SBObject sbobj, mapping tmp,
                      array content_types, array allowed_paths) // {{{
{
  if (sbobj->isdir) {
    mapping|array(object) list =
      sbobj->list(id, 0, !id)->is_user_op(id, "metadata", 0, !id) - ({ 0 });
    foreach (list, Sitebuilder.FS.SBObject child)
      sb_get_xsl_paths(id, child, tmp, content_types, allowed_paths);
  }
  else {
    if (search( content_types, sbobj->md["http-content-type"] ) > -1) {
      string path = sbobj->abspath(id, 0, !id);
      if (is_valid_location_path(path, allowed_paths)) {
	if (basename(path) == xsl_config_filename) {
	  mapping md = sbobj->md["xsl-params"];
	  if (md && md["blog-root"] && sizeof( md["blog-root"][2] ))
	    index_xsl_params( BlogIndex(path), sbobj->md["xsl-params"] );
	}
      }
    }
  }
} // }}}

int(0..1) index_xsl_params(BlogIndex blog_index, mapping xsl_params) // {{{
{
  if (blog_index->id && xsl_params) {
    string bid = (string)blog_index->id;
    if ( xsl_params["blog-root"] && sizeof( xsl_params["blog-root"][2] )) {
      foreach (indices(xsl_params), string key) 
	BlogConfig(key, (string)xsl_params[key][2], bid)->save();
      return 1;
    }
    else
      TRACE("Skipping non-configured blog\n");
  }

  return 0;
} // }}}

class AbstractBlog // {{{
{
  int id;

  object set_id(string|int _id)
  {
    id = (int)_id;
  }
} // }}}

class BlogKeyValue // {{{
{
  inherit AbstractBlog;

  string key;
  string value;

  protected string table_name;
  protected string parent_column;
  protected string parent_value;

  void create(string _key, string _value, string _parent)
  {
    key = _key;
    value = _value;
    parent_value = _parent;
  }

  object load_from_id(string|int id)
  {
    string sql = sprintf("SELECT * FROM %s WHERE id=%%s", table_name);
    array res = q(sql, id);
    if (res && sizeof(res)) {
      set_id(id);
      key = res[0]->key;
      value = res[0]->value;
    }

    return this_object();
  }

  object load_from_key()
  {
    if (!key) return this_object();
    string sql = sprintf("SELECT * FROM %s WHERE `key`=%%s AND %s=%%s",
                         table_name, parent_column);
    foreach (q(sql, key, parent_value)||({}), mapping row) {
      key = row->key;
      value = row->value;
      set_id(row->id);
    }
    
    return this_object();
  }

  mapping exists(void|string _key)
  {
    _key = _key || key;
    if (!_key) return 0;
    string sql = sprintf("SELECT * FROM %s WHERE %s=%s AND `key`=%%s",
                         table_name, parent_column, parent_value);
    array res = q(sql, key);
    return res && sizeof(res) && res[0];
  }

  object set(string _key, string _value)
  {
    key = _key;
    value = _value;
    save();
  }
  
  void save()
  {
    string sql;
    if (mapping vals = exists(key)) {
      TRACE("Config exists in DB\n");
      if (vals->value != value) {
	TRACE("Value changed...update\n");
	sql = sprintf("UPDATE %s SET `value`=%%s WHERE id=%%s", table_name);
	q(sql, value, vals->id);
	return;
      }
      else return;
    }

    TRACE("New blog config(%O, %O)\n", key, value);

    sql = sprintf("INSERT INTO %s (%s, `key`, `value`) VALUES (%%s, %%s, %%s)",
                  table_name, parent_column);
    q(sql, parent_value, key, value);
    set_id(get_db()->master_sql->insert_id());
  }
} // }}}

class BlogIndex // {{{
{
  inherit AbstractBlog;

  string path;
  array(BlogConfig) config = ({});

  void create(string _path)
  {
    path = _path;
    array res = q("SELECT * FROM blog_index WHERE path=%s", path);
    if (res && sizeof(res)) {
      set_id(res[0]->id);
      load_configs();
    }
    else {
      q("INSERT INTO blog_index (path) VALUES (%s)", _path);
      set_id(get_db()->master_sql->insert_id());
    }
  }

  void load_configs()
  {
    if (!id) return;
    
    SqlRes res = q("SELECT * FROM blog_config WHERE id_blog_index=%d", id);
    if (res && sizeof(res)) {
      foreach (res, SqlRow row) {
	BlogConfig bc = BlogConfig(0, 0, (string)id)->load_from_id(row->id);
      }
    }
  }

  string _sprintf(int t)
  {
    return t == 'O' && sprintf("BlogIndex(%d, %O)", id, path);
  }
} // }}}

array(BlogConfig) get_blog_config_for_path(string path) // {{{
{
  string sql = #"
    SELECT t1.id AS id_blog_index, t2.id AS id, t2.key AS `key`
           t2.`value` AS `value`
    FROM blog_index t1
    INNER JOIN blog_config t2
    ON t2.id_blog_index = t1.id
    WHERE t1.path = %s";

  array ret = ({});
  foreach (q(sql, path)||({}), mapping row)
    ret += ({ BlogConfig(row->key, row->value, row->id_blog_index) });
  
  return ret;
} // }}}

class BlogConfig // {{{
{
  inherit BlogKeyValue;

  protected string table_name = "blog_config";
  protected string parent_column = "id_blog_index";

  void create(string key, string value, string parent)
  {
    ::create(key, value, parent);
  }
} // }}}

int(0..1) is_valid_location_path(string path, array valid_locations) // {{{
{
  foreach (valid_locations, string valid_glob)
    if (glob(valid_glob, path))
      return 1;

  return 0;
} // }}}

int sb_file_viewable(RequestID id, Sitebuilder.FS.SBObject sbobj) // {{{
{
  string ct;
  object h;
  object site = sbobj->wa->site;
  return site->ct_data_for(ct = site->content_type_for(sbobj, id))->downloadp &&
                           (h = site->handler_for(ct, id)) && !h->noview;
} // }}}

mapping(string:function) query_action_buttons() // {{{
{
  Site s = site();
  /*
  if (!s || s->frontend_mode())
    return ([]);
  */
  return ([ LOCALE(0, "Reindex") : reindex ]);
} // }}}

void clear() // {{{
{
  Sql.Sql db = get_db();
  db->query("TRUNCATE TABLE blog");
  db->query("OPTIMIZE TABLE blog");
  db->query("TRUNCATE TABLE blog_index");
  db->query("OPTIMIZE TABLE blog_index");
  db->query("TRUNCATE TABLE blog_config");
  db->query("OPTIMIZE TABLE blog_config");
  db->query("TRUNCATE TABLE blog_metadata");
  db->query("OPTIMIZE TABLE blog_metadata");
  report_notice("Blog database was cleared!\n");
  return;
} // }}}

void sb_after_hook(string operation, string path, RequestID id,
                   void|mapping info, object sbobj) // {{{
{
  if (!path || !info)
    return;

  //TRACE(">>> sb_after_hook: %s: %O\n", operation, info);

  if (operation == "purge") {
    delete_path(path);
    return;
  }

  string content_type = sbobj->md && sbobj->md["http-content-type"];
//  if ( sbobj->md && sbobj->md["http-content-type"] )
//    content_type = sbobj->md["http-content-type"];

  if ((operation == "commit" || operation == "replicating") && content_type) {
    if (info->hidden_commit || info->internal_commit)
      return;

    if (search(valid_content_types, content_type) > -1 &&
        is_valid_location_path(path, valid_blog_location_files))
    {
      if ( (< "edit", "create", "undelete" >)[info->commit_type] )
	handle_document(sbobj, path, id);
      else if (info->commit_type == "delete") {
	TRACE("Delete entry...\n");
	delete_path(path);
      }
      return;
    }
    // Blog config file
    else if (content_type == "sitebuilder/xsl-template" &&
             is_valid_location_path(path, blog_roots) &&
             basename(path) == xsl_config_filename)
    {
      BlogIndex bi = BlogIndex(path);
      TRACE("%s is a valid config file: %O!\n", path, bi);
      if (bi->id && info && (info->commit_type == "edit" || 
                             info->commit_type == "create")) 
      {
	TRACE("Update XSL params");
	index_xsl_params( bi, sbobj->md["xsl-params"] );
      }
      else if (info && info->commit_type == "delete") {
	TRACE("Delete Blog config");
      }
    }
  }
} // }}}

void delete_path(string path) // {{{
{
  // This probably means an entire directory has been purged
  if (!has_suffix(path, ".xml"))
    path += "/index.xml";

  TRACE("Deleting blog entry \"/%s\"!\n", path);

  Sql.Sql db = get_db();
  SqlRes r = db->query("SELECT id FROM blog WHERE path = %s", path);

  if (r && sizeof(r))
    db->query("DELETE FROM blog_metadata WHERE blog_id = %s", r[0]->id);

  db->query("DELETE FROM blog WHERE path = %s", path);
} // }}}

void handle_document(object sbobj, string path, RequestID id) // {{{
{
  array file_data = get_file_data(sbobj);

  if (!sizeof(file_data))
    return;

  mapping data = get_components(file_data[0]->xml);

  if (!data)
    return;

  Sql.Sql db = get_db();
  SqlRes existing = db->query("SELECT id FROM blog WHERE path = %s", path);

  mapping fd = file_data[0]->metadata;
  string ftime;

  // Means visible from is set manually
  if (fd->external_use[0] != 0)
    ftime = fd["visible-from"]->format_mtime();
  else {
    RoxenModule sitenews = conf->get_provider("site_news_search");
    // Grab from sitenews db. fd["visible-from"] doesn't work correctly on
    // front-ends
    ftime = sitenews->get_first_publish_time(sbobj->real_abspath());
    ftime = ftime || fd["visible-from"]->format_mtime();
  }

  if (fd->hidden)
    ftime = "0000-00-00 00:00:00";

  array(string) cats = fd->category/"|";
  array(string) kwords = map(fd->keywords/",", String.trim_all_whites);

  cats   -= ({ "" });
  kwords -= ({ "" });

  string sql;
  string entry_id;

  if (sizeof(existing)) {
    TRACE("UPDATE ENTRY: %s\n", path);
    entry_id = existing[0]->id;

    sql = #"
    UPDATE `blog` SET
      path = %s,
      title = %s,
      visible_from = %s,
      last_action = NOW(),
      last_action_author = %s
    WHERE id = %s";

    if (mixed e = catch(db->query(sql, path, fd->title, ftime, fd->author,
                                  entry_id)))
    {
      blog_error("Error updating blog entry \"%s\"!\n%s",
                 entry_id, describe_backtrace(e));
      return;
    }

    // Clear metadata. Reset further down.
    db->query("DELETE FROM `blog_metadata` WHERE blog_id = %s", entry_id);
  }
  else {
    // Index new blog entry

    TRACE("INSERT NEW ENTRY: %s\n", path);

    sql = #"
    INSERT INTO `blog` (author, path, title, visible_from)
    VALUES (%s, %s, %s, %s)";

    if (mixed e = catch(db->query(sql, fd->author, path, fd->title, ftime))) {
      blog_error("Couldn't add \"%s\": %s", path, describe_backtrace(e));
      return;
    }

    entry_id = (string)db->master_sql->insert_id();
  }

  // Handle metadata
  array cols = ({ });
  foreach (cats, string cat) {
    sscanf(cat, "%*s!%s", cat);
    cols += ({ "(" + entry_id + ", 'category', '" + db->quote(cat) + "')" });
  }

  foreach (kwords, string kword)
    cols += ({ "(" + entry_id + ", 'keyword', '" + db->quote(kword) + "')" });

  sql = "INSERT INTO blog_metadata (`blog_id`, `key`, `value`) VALUES " +
	(cols*",");

  if (sizeof(cols)) {
    if (mixed e = catch(db->query(sql))) {
      blog_error("Couldn't insert metadata for \"%s\": %s", path,
		 describe_backtrace(e));
    }
  }
} // }}}

array tags_to_parse = ({});

private mapping(string:mixed) node_to_mapping(Node root) // {{{
{
  mapping component = ([]);
  array children = root->get_children();
  foreach(children, Node child) {
    if(child->get_node_type() == 2) {
      component[child->get_tag_name()] =
      	String.trim_all_whites(child->get_children()->html_of_node() * "");
    }
  }

  return component;
} // }}}

private mapping(string:mixed) get_components(string xml) // {{{
{
  mapping component;

  if(sizeof(xml)) {
    Node root = Parser.XML.Tree.parse_input(xml);
    root->walk_preorder(lambda(Node node) {
      if(node->get_node_type() == 2) {
	if(node->get_tag_name() == blog_component_name ||
	   /* Compat cludge for TVAB intranet */
	   node->get_tag_name() == "blog-entry-component") 
	{
	  component = node_to_mapping(node);
	  return STOP_WALK;
	}
      }
    } );
  }

  return component;
} // }}}

private array(mapping(string:string|mapping)) get_file_data(object sbobj) // {{{
{
  array(mapping(string:string)) file_content = ({});
  string xml;
  if (objectp(sbobj)) {
    if (sbobj->md && sbobj->md->language) {
      foreach (indices(sbobj->md->language), string lang) {
	SBFileData /*sbfd*/ sbfile = sbobj->view(0, 0, 1, 0, lang);
	if (xml = objectp(sbfile) && sbfile->read()) {}
	else
	  werror("ERROR couldn't load XML data from file object: %O\n", sbfile);

	sbfile->close();

	file_content += ({ ([
	  "xml"              : xml,
	  "language"         : lang,
	  "metadata"         : get_file_metadata(sbobj, lang),
	  "default_language" : sbobj->md["original-language"] ]) });
      }
    }
    else {
      SBFileData sbfile = sbobj->view(0, 0, 1); // sbobj->view(id, undelete, !id)
      if (xml = objectp(sbfile) && sbfile->read()) { }
      else
	werror("ERROR couldn't load XML from file object: %O\n", sbobj);

      sbfile->close();

      file_content = ({ ([
	"xml"              : xml,
	"metadata"         : get_file_metadata(sbobj),
	"language"         : 0,
	"default_language" : 0 ]) });
    }
  }

  return file_content || 0;
} // }}}

private mapping(string:mixed)
get_file_metadata(object sbobj, void|string language) // {{{
{
  mapping md = ([]);
  md += sbobj->md;
  if (sbobj->md && sbobj->md->language) {
    if (!language) {
      werror("ERROR couldn't extract metadata since the file has language "
             "defined and language argument is not supplied\n");
      return 0;
    }
    foreach (indices(sbobj->md), string idx) {
      if (search(({"title","keywords","categories","description"}), idx) > -1) {
	// Language dependent metadata, although these might be extended
	md += ([ idx : sbobj->md[idx][language] ]);
      }
      else {
	md += ([ idx : sbobj->md[idx] ]);
      }
    }
  }

  Calendar.Second visible_from;

  md->hidden = 0;

  // Always override default visibility with a manually set visible ts
  if( md->external_use && md->external_use[0] )
    visible_from = Calendar.parse("%S", (string)md->external_use[0]);
  else {
    string created = sbobj->log(0, 0, 0, 1, 1, 0, 0)->get(0)[-1]->date;
    visible_from = Calendar.parse("%Y-%M-%D %h:%m:%s", created);
  }

  // Never visible
  if ( md->external_use && !md->external_use[0] && !md->external_use[1] )
    md->hidden = 1;

  md["visible-from"] = visible_from;

  return md;
} // }}}

string status() // {{{
{
  if (Site s = site()) {
    return LOCALE(844,"Connected to") + ": <b>" +
	   Roxen.html_encode_string(search(sitebuilders(), s)->query_name()) +
           "</b>" + (is_reindexing ?
	   "<p><b>Reindexing database...</b></p>" : "");
  }
  else
    return "<b>" + LOCALE(845,"Not connected") + "</b>";
} // }}}

void init_db() // {{{
{
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      blog_error("No permission to read Blog database: %s\n", db_name);
      return;
    }

    report_notice("No Blog database present. Creating \"%s\".\n", db_name);

    if (!DBManager.get_group("tvab")) {
      DBManager.create_group("tvab",
	"TVAB databases",
	"Various databases used by TVAB modules",
	""
      );
    }

    DBManager.create_db(db_name, 0, 1, "tvab");
    DBManager.set_permission(db_name, conf, DBManager.WRITE);
    perms = DBManager.get_permission_map()[db_name];
    DBManager.is_module_db(0, db_name,
			   "Used by the TVAB Blog Module to "
			   "store its data.");

    if (!get_db()) {
      blog_error("Unable to create TVAB Blog database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
} // }}}

Sql.Sql get_db() // {{{
{
  return DBManager.get(db_name, conf);
} // }}}

mixed q(string sql, mixed ... args) // {{{
{
  array res;
  if (mixed e = catch(res = get_db()->query(sql, @args))) {
    report_error("SQL error in Blog: %s\n", describe_backtrace(e));
  }

  return res || ({});
} // }}}

void setup_tables() // {{{
{
  if (Sql.Sql db = get_db()) {
    db->query(#"
      CREATE TABLE IF NOT EXISTS `blog_index` (
	`id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
	`path` VARCHAR(255) NOT NULL,
	PRIMARY KEY (`id`),
	KEY (`path`)
      )"
    );

    db->query(#"
      CREATE TABLE IF NOT EXISTS `blog_config` (
	`id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
	`id_blog_index` INT(11) UNSIGNED NOT NULL,
	`key` VARCHAR(255) NOT NULL,
	`value` BLOB DEFAULT NULL,
	PRIMARY KEY (`id`),
	KEY (`key`)
      )"
    );

    db->query(#"
      CREATE TABLE IF NOT EXISTS `blog` (
	`id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
	`author` INT UNSIGNED,
	`path` VARCHAR(255) NOT NULL,
	`title` VARCHAR(255) NOT NULL,
	`visible_from` DATETIME DEFAULT NULL,
	`last_action` DATETIME DEFAULT NULL,
	`last_action_author` INT UNSIGNED DEFAULT 0,
	PRIMARY KEY  (`id`),
	KEY (`title`),
	KEY (`path`)
      )"
    );

    db->query(#"
      CREATE TABLE IF NOT EXISTS `blog_metadata` (
        `id` INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
	`blog_id` INT(11) UNSIGNED NOT NULL,
	`key` VARCHAR(255) NOT NULL,
	`value` VARCHAR(255) DEFAULT NULL,
	PRIMARY KEY (`id`),
	KEY (`key`),
	KEY (`value`)
      )"
    );

    DBManager.is_module_table(this_object(), db_name, "blog",          0);
    DBManager.is_module_table(this_object(), db_name, "blog_index",    0);
    DBManager.is_module_table(this_object(), db_name, "blog_config",   0);
    DBManager.is_module_table(this_object(), db_name, "blog_metadata", 0);
  }
  else blog_error("Couldn't get DB connection");
} // }}}

string prefix(string in) // {{{
//| Paths in the sb_after_hook has no beginning / so we check if it's there
//| and if not we add one
{
  return (has_prefix(in, "/") ? in : "/" + in);
} // }}}

string unprefix(string in) // {{{
{
  if (in[0] == '/')
    in = in[1..];

  return in;
} // }}}

string translate_glob(string in) // {{{
{
  string out = replace(in, ({ "%", "_" }), ({ "\\%", "\\_" }));
  return replace(out, ({ "*", "?" }), ({ "%", "_" }));
} // }}}

string get_publish_date(RequestID id) // {{{
//| Get the publish date for the current page.
//| This takes "visibility" settings in consideration
{
  object sbobj = id->misc->sbobj;
  if (!sbobj) {
    blog_error("Couldn't get sbobj for %O", id);
    return 0;
  }

  mapping md = sbobj->metadata(0, 1, -1)->md;
  if (!md) {
    blog_error("Found no metadata for %O", id);
    return 0;
  }

  VCLogEntry vlog;
  //| Happens on new pages that are unpublished
  if (catch { vlog = get_log(sbobj)[-1]; })
    return 0;

  return md->external_use &&
	 sizeof(md->external_use) &&
	 md->external_use[0] &&
	 replace(Calendar.ISO.Second( md->external_use[0] )->iso_name(),"T"," ")
	 || vlog->date;
} // }}}

array(VCLogEntry) get_log(object/*SBObj*/obj) // {{{
{
  array(VCLogEntry) logs;
  if (catch { logs = obj->log(0, 0, 0, 1, 1, 0, 0)->get(0); } )
    return 0;

  return logs;
} // }}}

mapping(string:int|AC.Identity)
get_perm(RequestID id, string|void _path, string|void _handle) // {{{
{
  int ppid;
  string path = _path || "";
  if (has_prefix(path, "/")) path = path[1..];
  if (path[sizeof(path)-1..] == "/") path = path[..sizeof(path)-2];
  ppid = id->misc->sb->ac_find_file_pp(path);

  object mac = id->misc->wa && id->misc->wa->mac;
  if (!mac)
    RXML.run_error("Sitebuilder \"TVAB Blog module\" used without a site");

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
} // }}}

array(string) get_paths(string path, function quote, void|string table) // {{{
{
  if (!path) return 0;

  array paths = path/",";
  paths = map(map(map(paths, String.trim_all_whites), quote), translate_glob);

  string col = (table ? table : "") + "path";
  array w = ({});

  foreach (paths, string path) {
    if (path[0] == '/') path = path[1..];
    w += ({ col + " LIKE '" + path + "'" });
  }

  return w;
} // }}}

void clean_sql_result(SqlRes res) // {{{
{
  map(res||({}), lambda(mapping m) {
    if (m->path) m->path = prefix(m->path);
    foreach (glob("*.*", indices(m)), string key)
      m_delete(m, key);
  });
} // }}}

class TagEmitTVABBlogPlugin // {{{
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "tvab-blog";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "path"     : RXML.t_text(RXML.PXml),
    "next"     : RXML.t_text(RXML.PXml),
    "previous" : RXML.t_text(RXML.PXml),
    "group-by" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    Sql.Sql db = get_db();

    if (!args->path) args->path = id->misc->localpath;

    args->path = prefix(args->path);

    object wa = id->misc->wa;
    object sbobj = id->misc->sbobj;

    array paths = get_paths(args->path, db->quote);

    string sql = "SELECT * FROM blog WHERE " + (paths * " OR ");
    sql += " AND visible_from != '0000-00-00 00:00:00' ";

    if ( args["group-by"] ) {
      if ( !(< "year", "month" >)[args["group-by"]] ) {
	RXML.parse_error("Bad value to \"group-by\" argument. Must be "
	                 "\"year\" or \"month\"");
	return 0;
      }

      switch ( args["group-by"] ) {
	case "year":
	  sql += "GROUP BY DATE_FORMAT(visible_from, '%Y') ";
	  break;

	case "month":
	  sql += " GROUP BY DATE_FORMAT(visible_from, '%Y-%m') ";
      }
    }

    sql += "ORDER BY visible_from DESC, id DESC ";

    //| Should be enough!
    int limit = 100000 || (int)args->maxrows;

    if (limit == 0)
      limit = 100000;

    int from = (int)args->start||0;

    sql += "LIMIT " + from + "," + limit;

    SqlRes res = db->query(sql);

    if (!res) return ({});

    clean_sql_result(res);

    mapping sb_cache = ([]);
    mapping skip = ([]);
    array(mapping(string:string)) pages = ({});

    foreach (res, mapping m) {
      if (has_index(skip, m->path))
	continue;

      if (!sb_cache[m->path])
	sb_cache[m->path] = wa->sbobj_va(m->path, id);

      sbobj = sb_cache[m->path];

      if (!sbobj) {
	TRACE("Missing file ignored: %O\n", m->path);
	skip[m->path] = 1;
	continue;
      }

      if (!sbobj->exists(id)) {
	TRACE("Deleted file ignored: %O\n", m->path);
	skip[m->path] = 1;
	continue;
      }

      // Hidden by workflow?
      if(!sbobj->is_valid_op(id, "metadata", 0, 0)) {
	TRACE("Can not get metadata for %O\n", m->path);
	skip[m->path] = 1;
	continue;
      }

      mapping|object md = sbobj->metadata(id, 0);

      if (mappingp(md))
	error("Unexpected error from metadata(): %s\n",
              Sitebuilder.error_msg(md));

      md = md->md;

      if (!get_current_visibility(sbobj, md->external_use)) {
	TRACE("Time published file ignored %O\n", m->path);
	skip[m->path] = 1;
	continue;
      }

      m->path = prefix(m->path);

      pages += ({ m });

      if (sizeof(pages) >= limit)
	break;
    }

    return pages;
  }
} // }}}

class TagEmitTVABBlogPrevNextPlugin // {{{
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "tvab-blog-prev-next";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "path" : RXML.t_text(RXML.PXml),
    "root" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    Sql.Sql db = get_db();

    if (!args->path) args->path = id->misc->localpath;

    args->path = unprefix(args->path);

    array roots = get_paths(args->root||"*", db->quote);
    args->root = replace(roots[0], "%", "%%");
    
    object wa = id->misc->wa;
    object sbobj = id->misc->sbobj;

    string sql = "SELECT * FROM blog WHERE path = %s";
    array|mapping r = db->query(sql, args->path);

    if (!r || !sizeof(r))
      return ({});

    r = r[0];

    if (r->visible_from == "0000-00-00 00:00:00")
      return ({});

    sql = #"
    (SELECT id, title, author, path, last_action, last_action_author,
            visible_from
     FROM blog
     WHERE visible_from < %s
       AND visible_from != '0000-00-00 00:00:00'
       AND path != %s
       AND " + args->root + #"
     ORDER BY visible_from DESC, id DESC
     LIMIT 1
    )
    UNION
    (SELECT id, title, author, path, last_action, last_action_author,
            visible_from
     FROM blog
     WHERE visible_from >= %s
       AND visible_from != '0000-00-00 00:00:00'
       AND path != %s
       AND " + args->root + #"
     ORDER BY visible_from ASC, id ASC
     LIMIT 1
    )";

    //TRACE(sql + "\n", r->visible_from, args->path, r->visible_from, args->path);

    SqlRes res = db->query(sql, r->visible_from, args->path,
                           r->visible_from, args->path);

    if (!res) return ({});

    clean_sql_result(res);

    foreach (res, mapping m) {
      m->path = prefix(m->path);
      if (m->visible_from < r->visible_from)
	m->order = "previous";
      else
	m->order = "next";
    }

    return res;
  }
} // }}}

class TagEmitTVABBlogTags // {{{
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "tvab-blog-tags";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "path"         : RXML.t_text(RXML.PXml),
    "not-path"     : RXML.t_text(RXML.PXml),
    "related"      : RXML.t_text(RXML.PXml),
    "cloud"        : RXML.t_text(RXML.PXml),
    "tag"          : RXML.t_text(RXML.PXml),
    "unique-paths" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    Sql.Sql db = get_db();

    if (!args->path) args->path = id->misc->localpath;

    array paths = get_paths(args->path, db->quote, "t2.");

    string sql = #"
    SELECT t1.value AS tag, t2.path AS path, t2.title AS title,
           t2.visible_from AS visible_from ";

    if (args->cloud)
      sql += ", COUNT(t1.id) AS number ";

    sql += #"
    FROM blog_metadata t1
    INNER JOIN blog t2
      ON t2.id = t1.blog_id
    WHERE (" + (paths*" OR ") + " ";
    
    if ( args["not-path"] ) {
      sql += "AND NOT(t2.path = '" + 
             db->quote(unprefix( args["not-path"] )) + "') ";
    }
    
    sql += #")
    AND t2.visible_from != '0000-00-00 00:00:00'
    AND t1.`key` = 'keyword' ";


    if (args->tag && sizeof(args->tag)) {
      array tags = ({});

      foreach (map(args->tag/",", String.trim_all_whites), string tag) 
	tags += ({ "t1.value = '" + db->quote(tag) + "'" });

      sql += "AND (" + (tags*" OR ") + ") "
             "GROUP BY t2.path "
             "ORDER BY t2.visible_from DESC, t2.id DESC ";
    }
    else {
      sql += "GROUP BY t1.value";

      if ( args["unique-paths"] )
	sql += ", t2.path";

      sql += " ORDER BY t1.value";
    }

    SqlRes res = db->query(sql);

    if (!res) return ({});

    clean_sql_result(res);

    return res;
  }
} // }}}

class TagEmitTVABBlogIndex // {{{
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "tvab-blog-index";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "path" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string path;
    if (args->path && sizeof(args->path)) {
      path = args->path;
      if (path[0] == '/')
	path = path[1..];

      if (!has_suffix(path, xsl_config_filename)) {
	if (!has_suffix(path, "/"))
	  path += "/";

	path += xsl_config_filename;
      }
    }

    Sql.Sql db = get_db();

    string sql = #"
      SELECT t1.id AS pid, t2.id AS id,
             t2.key AS `key`, t2.value AS `value`
      FROM blog_index t1
      INNER JOIN blog_config t2
      ON t2.id_blog_index = t1.id ";

    if (path)
      sql += "WHERE t1.path='" + db->quote(path) + "'";

    array out = ({});
    array res = q(sql);

    if (res && sizeof(res)) {
      int prev_id = 0;
      mapping m;
      foreach (res, mapping row) {
	int this_id = (int)row->pid;
	if (this_id != prev_id) {
	  if (m) out += ({ m });
	  m = ([]);
	}

	m[row->key] = row->value;
	prev_id = this_id;
      }

      if (m) out += ({ m });
    }

    return out;
  }
} // }}}

class TagTVABBlogNumPages // {{{
{
  inherit RXML.Tag;
  constant name = "tvab-blog-num-pages";

  mapping(string:RXML.Type) opt_arg_types = ([
    "path" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      Sql.Sql db = get_db();
      array paths = get_paths(args->path, db->quote);
      string sql = "SELECT COUNT(id) AS num FROM `blog` WHERE "+(paths*" OR ");
      SqlRes res = db->query(sql);
      result = res && sizeof(res) && res[0]->num || 0;
      return 0;
    }
  }
} // }}}

class TagEmitTVABBlogAuthor // {{{
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "tvab-blog-author";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "path" : RXML.t_text(RXML.PXml),
    "username" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string path;
    if (args->path && sizeof(args->path)) {
      path = args->path;
      if (path[0] == '/')
	path = path[1..];

      if (!has_suffix(path, xsl_config_filename)) {
	if (!has_suffix(path, "/"))
	  path += "/";

	path += xsl_config_filename;
      }
    }

    Sql.Sql db = get_db();

    string sql = #"
      SELECT t1.id AS blog_id, t2.id AS id, t2.key AS `key`,
             t2.value AS `value`
      FROM blog_index t1
      INNER JOIN blog_config t2
      ON t2.id_blog_index = t1.id
      WHERE t2.key = 'blog-authors'";

    if (path)
      sql += " AND t1.path='" + db->quote(path) + "'";

    array out = ({});
    array res = q(sql);

    if (res && sizeof(res)) {
      int prev_id = 0;
      foreach (res, mapping row) {
	foreach (row->value/","||({}), string part) {
	  array(string) pts = part/":";
	  string username = pts[0], email = "";
	  if (sizeof(pts) > 1)
	    email = pts[1];

	  if (!args->username || (args->username && username == args->username))
	    out += ({ ([ "username" : username,
	                 "email" : email,
	                 "blog-id" : row->blog_id ]) }); 
	}
      }
    }

    return out;
  }
} // }}}

class TagEmitBlogRelatedPages // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "blog-related-pages";

  mapping(string:RXML.Type) req_arg_types = ([
    "data"  : RXML.t_text(RXML.PXml),
    "split" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array ret = ({});
    mapping refs = ([]);
    string split = args->split||"\t";
    
    foreach (String.trim_all_whites(args->data)/"\n", string row) {
      // 0 = keyword
      // 1 = path
      // 2 = title
      // 3 = date
      array pts = row/split;

      if (sizeof(pts) < 2) {
	report_debug("Cont. due to short array: %O", pts);
	continue;
      }

      catch {
	if ( !refs[pts[1]] ) {
	  refs[pts[1]] = ([]);
	  mapping m = refs[pts[1]];
	  m->path  = pts[1];
	  m->title = pts[2];
	  m->date  = pts[3];
	  m->keywords = ({ pts[0] });
	}
	else
	  refs[pts[1]]->keywords += ({ pts[0] });
      };
    }

    foreach (values(refs), mapping m) {
      m->keywords = m->keywords*", ";
      ret += ({ m });
    }

    return ret;
  }
} // }}}

#if !constant(TagValidPathName)

class TagValidPathName // {{{
{
  inherit RXML.Tag;
  constant name = "valid-path-name";

  mapping(string:RXML.Type) req_arg_types = ([]);
  
  mapping(string:RXML.Type) opt_arg_types = ([
    "path" : RXML.t_text(RXML.PXml),
    "lengt" :  RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      int len = (args->length && (int)args->length)||25;
      result = Sitebuilder.mangle_to_valid_pathname(args->path||content,0,len);
      return 0;
    }
  }
} // }}}

#endif

#if !constant(TagGetUniqComponentID)

class TagGetUniqueComponentID // {{{
{
  inherit RXML.Tag;
  constant name = "get-unique-component-id";

  mapping(string:RXML.Type) req_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = Sitebuilder.Editor.get_unique_component_id();
      return 0;
    }
  }
} // }}}

class TagGetUniqComponentID // {{{
{
  inherit TagGetUniqueComponentID;
  constant name = "get-uniq-component-id";
} // }}}

#endif
