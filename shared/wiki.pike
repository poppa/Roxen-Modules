//#!/usr/bin/env pike
/* -*- Mode: Pike; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
//! @b{[PROG-NAME]@}
//!
//! Copyright © 2010, Pontus Östlund - @url{http://www.poppa.se@}
//!
//! @pre{@b{License GNU GPL version 3@}
//!
//! [PROG-NAME].pmod is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! [MODULE-NAME].pike is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with [PROG-NAME].pike. If not, see <@url{http://www.gnu.org/licenses/@}>.
//! @}

//TRACE("SillyCaps: %s\n", Sitebuilder.sillycaps_mangle("Some wiki-word"));

#include <config.h>
#include <module.h>
inherit "module";

#define WIKI_DEBUG

#ifdef WIKI_DEBUG
# define TRACE(X...) report_debug("Wiki (%3d): %s", __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]

constant thread_safe = 1;
constant module_type = MODULE_TAG|MODULE_PROVIDER;
constant module_name = "Poppa Tags: Wiki";
constant module_doc  = "Wiki tags";

Configuration conf;
private Web.Wiki.Parser wiki_parser;
private string db_name;
private typedef mapping(string:string) SqlRow;
private typedef array(SqlRow) SqlResult;

string query_provides()
{
  return "wiki";
}

void register_wiki_parser(Web.Wiki.Parser parser)
{
  string sql = "SELECT word FROM wiki WHERE path=%s";
  SqlResult r = q(sql, parser->get_wiki_root());
  if (r && sizeof(r)) {
    mapping words = ([]);
    foreach (r, SqlRow row) words[row->word] = 1;
    parser->add_wiki_word(words);
  }
  wiki_parser = parser;
}

void create(Configuration _conf)
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");
  conf = _conf;
  defvar("db_name",
    Variable.DatabaseChoice(
      "wiki_" + (conf ? Roxen.short_name(conf->name):""), VAR_INITIAL,
      "Wiki Database",
      "The database where Wiki data is stored."
    )->set_configuration_pointer(my_configuration)
  );
}

void start(int when, Configuration _conf)
{
  TRACE("Start module\n");
  db_name = query("db_name");

  if (db_name)
    init_db();
}

// init_db
void init_db() // {{{
{
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      report_error("No permission to read Wiki database: %s\n", db_name);
      return;
    }

    report_notice("No wiki database present. Creating \"%s\".\n", db_name);

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
			   "Used by the Wiki Module to store its data.");

    if (!get_db()) {
      report_error("Unable to create Wiki database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
} // }}}

// setup_tables
void setup_tables() // {{{
{
  if (Sql.Sql db = get_db()) {
    q(#"CREATE TABLE IF NOT EXISTS `wiki` (
      `id`            INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
      `parent`        INT(11) UNSIGNED DEFAULT NULL,
      `path`          VARCHAR(255) DEFAULT NULL,
      `word`          VARCHAR(255) DEFAULT NULL,
      `ambigous_word` VARCHAR(255) DEFAULT NULL,
      `date`          DATETIME DEFAULT NULL,
      `visible`       ENUM('y','n') DEFAULT 'y',
      `title`         VARCHAR(255) DEFAULT NULL,
      `body`          BLOB,
      `author`        VARCHAR(255) DEFAULT NULL,
      `username`      VARCHAR(50) DEFAULT NULL,
      `revision`      INT(10) NOT NULL DEFAULT 1,
      `ip`            VARCHAR(39) NOT NULL,
      `reason`        VARCHAR(255) DEFAULT NULL,
      `keyword`       VARCHAR(255) DEFAULT NULL,
      `head`          ENUM('y','n') DEFAULT 'y',
      PRIMARY KEY  (`id`))
      ENGINE = MyISAM");
      
    if (!sizeof(q("DESCRIBE wiki reason"))) {
      report_notice("No \"reason\" column in `wiki`! Adding...");
      q("ALTER TABLE wiki ADD reason VARCHAR(255) DEFAULT NULL");
    }

    DBManager.is_module_table(this_object(), db_name, "wiki", 0);
  }
  else report_error("Couldn't get DB connection");
} // }}}

Sql.Sql get_db() // {{{
{
  return DBManager.get(db_name, conf);
} // }}}

SqlResult q(mixed ... args) // {{{
{
  return get_db()->query(@args);
} // }}}

string clean_text(string text)
{
  return replace(text,
                 ({ "\u0092", "\u0096" }),
                 ({ "'", "-" }));
}

Wiki get_wiki(string word, void|int rev)
{
  string sql = "SELECT id FROM wiki WHERE word=%s AND path=%s ";
  if (rev)
    sql += "AND revision=" + rev;
  else
    sql += "AND head='y'";

  SqlResult r = q(sql, word, wiki_parser->get_wiki_root());

  if (r && sizeof(r))
    return Wiki((int)r[0]->id);

  return 0;
}

#define SQL DB.Sql

class Wiki // {{{
{
  SQL.Int    id            = SQL.Int("id");
  SQL.Int    parent        = SQL.Int("parent");
  SQL.String path          = SQL.String("path");
  SQL.String word          = SQL.String("word");
  SQL.String ambigous_word = SQL.String("ambigous_word");
  SQL.Date   date          = SQL.Date("date", 0 ,1);
  SQL.Enum   visible       = SQL.Enum("visible", (< "y", "n" >), "y");
  SQL.String title         = SQL.String("title");
  SQL.String body          = SQL.String("body");
  SQL.String author        = SQL.String("author");
  SQL.String username      = SQL.String("username");
  SQL.String ip            = SQL.String("ip");
  SQL.String reason        = SQL.String("reason");
  SQL.String keyword       = SQL.String("keyword");
  SQL.Int    revision      = SQL.Int("revision", 1);
  SQL.Enum   head          = SQL.Enum("head", (< "y", "n" >), "y");

  void create(void|int id)
  {
    if (id) {
      SqlResult r = q("SELECT * FROM wiki WHERE id=%d", id);
      if (r && sizeof(r))
	set_from_sql( r[0] );
    }
  }

  public object set_from_sql(SqlRow res)
  {
    foreach (indices(res), string key)
      if ( this[key] && object_variablep(this, key))
	this[key]->set( res[key] );
    return this;
  }

  public object save()
  {
    string sql;
    array(SQL.Field) flds = ({ parent, path, word, ambigous_word, date,
                               visible, title, body, author, username,
                               revision, head, ip, reason, keyword });
    // Create new
    if ((int)id == 0) {
      sql = sprintf("INSERT INTO wiki (%s) VALUES (%s)",
                    flds->get_quoted_name()*",",
                    flds->get_quoted()*",");
      q(sql);
      id->set(get_db()->master_sql->insert_id());
    }
    // Update
    else {
      sql = "INSERT INTO wiki (" + flds->get_quoted_name()*"," + ")" 
            " SELECT " + flds->get_quoted_name()*"," + 
            " FROM wiki WHERE id=%d";
      q(sql, (int)id);
      int new_id = get_db()->master_sql->insert_id();
      revision->set((int)revision+1);
      date->set("NOW()");
      flds[4]  = date;
      flds[10] = revision;
      sql = "UPDATE wiki SET " + (flds->get()*",") + " WHERE id=%d";
      q(sql, new_id);
      q("UPDATE wiki SET head='n' WHERE id=%d", (int)id);
      id->set(new_id);
    }

    return this;
  }
} // }}}

//! Init the wiki module
class TagWikiInit // {{{
{
  inherit RXML.Tag;
  constant name = "wiki-init";

  mapping(string:RXML.Type) req_arg_types = ([
    "root" : RXML.t_text(RXML.PEnt)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      wiki_parser = Web.Wiki.Parser(args->root);
      return 0;
    }
  }
} // }}}

#define NORMALIZE_KEYWORD(KW) (KW) && map((KW)/",", String.trim_all_whites)*","

//! Create a new wiki page
class TagWikiCreatePage // {{{
{
  inherit RXML.Tag;
  constant name = "wiki-create-page";

  mapping(string:RXML.Type) req_arg_types = ([
    "title" : RXML.t_text(RXML.PEnt),
    "word"  : RXML.t_text(RXML.PEnt)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "body"          : RXML.t_text(RXML.PEnt),
    "parent"        : RXML.t_text(RXML.PEnt),
    "ambigous-word" : RXML.t_text(RXML.PEnt),
    "body"          : RXML.t_text(RXML.PEnt),
    "author"        : RXML.t_text(RXML.PEnt),
    "username"      : RXML.t_text(RXML.PEnt),
    "keyword"       : RXML.t_text(RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (args->body) args->body = clean_text(args->body);

      mapping m = ([]);
      m->ip = RXML.user_get_var("client.ip");
      args->keyword = NORMALIZE_KEYWORD(args->keyword);

      foreach (args; string key; mixed val)
	m[replace(key, "-", "_")] = val;

      m->body -= "\r";
      m->path = wiki_parser->get_wiki_root();

      Wiki w = Wiki()->set_from_sql(m);
      w->save();

      _ok = 1;

      return 0;
    }
  }
} // }}}

//! Create a new wiki page
class TagWikiUpdate // {{{
{
  inherit RXML.Tag;
  constant name = "wiki-update-page";

  mapping(string:RXML.Type) req_arg_types = ([
    "id" : RXML.t_text(RXML.PEnt),
  ]);
  
  mapping(string:RXML.Type) opt_arg_types = ([
    "title"         : RXML.t_text(RXML.PEnt),
    "word"          : RXML.t_text(RXML.PEnt),
    "body"          : RXML.t_text(RXML.PEnt),
    "parent"        : RXML.t_text(RXML.PEnt),
    "ambigous-word" : RXML.t_text(RXML.PEnt),
    "body"          : RXML.t_text(RXML.PEnt),
    "author"        : RXML.t_text(RXML.PEnt),
    "username"      : RXML.t_text(RXML.PEnt),
    "keyword"       : RXML.t_text(RXML.PEnt),
    "reason"        : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (args->body) args->body = clean_text(args->body);

      mapping m = ([]);
      m->ip = RXML.user_get_var("client.ip");
      args->keyword = NORMALIZE_KEYWORD(args->keyword);

      foreach (args; string key; mixed val)
	m[replace(key, "-", "_")] = val;

      m->body -= "\r";

      if (Wiki w = Wiki((int)args->id)) {
      	w->set_from_sql(m);
	w->save();
	_ok = 1;
      }
      else _ok = 0;

      return 0;
    }
  }
} // }}}

//! Wiki text formatting
class TagWikiText // {{{
{
  inherit RXML.Tag;
  constant name = "wiki-text";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (!wiki_parser)
      	RXML.parse_error("No wiki parser. Call <wiki-init/> first!");

      string text = Roxen.html_decode_string(wiki_parser->parse(content||""));
      result = text;
      return 0;
    }
  }
} // }}}

class TagEmitWikiPage // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "wiki-page";

  mapping(string:RXML.Type) req_arg_types = ([
    "word" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "invisible" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string sql = "SELECT * FROM wiki WHERE `word`=%s AND head='y' AND "
                 "path=%s";
    if (!args->invisible)
      sql += " AND visible='y'";

    return q(sql, args->word, wiki_parser->get_wiki_root())||({});
  }
} // }}}

class TagEmitWikiHistory // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "wiki-history";

  mapping(string:RXML.Type) req_arg_types = ([
    "word" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "invisible" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string sql = "SELECT * FROM wiki WHERE `word`=%s AND "
                 "path=%s";
    if (!args->invisible)
      sql += " AND visible='y'";
    
    sql += " ORDER BY id DESC";

    return q(sql, args->word, wiki_parser->get_wiki_root())||({});
  }
} // }}}

class TagEmitWikiKeyword // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "wiki-keyword";

  mapping(string:RXML.Type) req_arg_types = ([
    "word" : RXML.t_text(RXML.PEnt),
    "keyword" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "invisible" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string sql = "SELECT word, title FROM wiki WHERE `path`=%s "
                 "AND word != %s AND head='y' "
                 "AND FIND_IN_SET(%s, CONCAT(keyword, ',')) "
                 "ORDER BY word, title";

    SqlResult r =  q(sql, wiki_parser->get_wiki_root(), args->word,
                          args->keyword);
    return r||({});
  }
} // }}}

class TagEmitWikiIndex // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "wiki-index";

  mapping(string:RXML.Type) req_arg_types = ([]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "invisible" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string sql = "SELECT word, title FROM wiki WHERE `path`=%s "
                 "AND word != '' AND head='y' "
                 "ORDER BY word, title";
    return q(sql, wiki_parser->get_wiki_root())||({});
  }
} // }}}

class TagEmitWikiDiff // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "wiki-diff";

  mapping(string:RXML.Type) req_arg_types = ([
    "word"    : RXML.t_text(RXML.PEnt),
    "rev"     : RXML.t_text(RXML.PEnt),
    "old-rev" : RXML.t_text(RXML.PEnt),
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "invisible" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    Wiki rev = get_wiki(args->word, (int)args->rev );
    Wiki old = get_wiki(args->word, (int)args["old-rev"] );

    if (!old && !rev)
      return ({});

    array(string) rev_body = ((string)rev->body)/"\n";
    array(string) old_body = ((string)old->body)/"\n";

    Variable.Diff diff = Variable.Diff(rev_body, old_body, 1);

    int added, removed;
    array out = ({});
    foreach (diff->get(), string ln) {
      mapping m = ([]);
      switch ( ln[0] )
      {
      	case 'L' : 
	  m->type = "line";
	  break;
	case '+':
	  m->type = "added";
	  added++;
	  break;
	case '-':
	  m->type = "removed";
	  removed++;
	  break;
	default:
	  m->type = "reference";
	  break;
      }

      m->line = ln;
      out += ({ m });
    }

    if (args->added)
      RXML.user_set_var(args->added, (string)added);
    if (args->removed)
      RXML.user_set_var(args->removed, (string)removed);

    return out;
  }
} // }}}
