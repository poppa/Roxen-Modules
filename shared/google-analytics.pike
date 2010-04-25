/* -*- Mode: Pike; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
//! @b{Google Analytics@}
//!
//! Copyright © 2010, Pontus Östlund - @url{www.poppa.se@}
//!
//! @pre{@b{License GNU GPL version 3@}
//!
//! google-analytics.pike is free software: you can redistribute it and/or 
//! modify it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! google-analytics.pike is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with google-analytics.pike. If not, see 
//! <@url{http://www.gnu.org/licenses/@}>.
//! @}

#include <module.h>
inherit "module";

constant thread_safe   = 1;
constant module_unique = 1;
constant module_type   = MODULE_TAG;
constant module_name   = "TVAB Tags: Google Analytics";
constant module_doc    = "This module provides tags for fetching data from "
                         "Google Analytcs";

import WS.Google.Analytics;

//#define GC_DEBUG

#ifdef GC_DEBUG
# define TRACE(X...) report_debug("%s:%d: %s", basename(__FILE__), __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define TRIM(X) String.trim_all_whites((X))
#define CACHE_KEY()                                    \
  WS.Google.md5(args->table                +           \
               (args->metrics       || "") +           \
               (args->dimensions    || "") +           \
               (args->filters       || "") +           \
               (args->sort          || "") +           \
               (args["start-date"]  || "") +           \
               (args["end-date"]    || "") +           \
               (args["max-results"] || ""))

string db_name;
mapping data_cache = ([]);
typedef mapping(string:string) SqlRow;
typedef array(SqlRow)          SqlRes;
Configuration                  conf;

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");

  defvar("db_name",
    Variable.DatabaseChoice(
      "google_" + (_conf ? Roxen.short_name(_conf->name):""), 0,
      "Googledatabas",
      "Databas f�r att lagra Google-relaterad data"
    )->set_configuration_pointer(my_configuration)
  );
} // }}}

void start(int when, Configuration _conf) // {{{ 
{
  conf = _conf;
  db_name = query("db_name");
  if (db_name && db_name != " none")
    init_db();
} // }}}

void init_db() // {{{
{
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      report_error("No permission to read database: %s\n", db_name);
      return;
    }

    report_notice("No Google database present. Creating \"%s\".\n", 
                  db_name);

    if(!DBManager.get_group("tvab")) {
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
			   "Used by Google modules to store its "
			   "data.");
    if (!get_db()) {
      report_error("Unable to create Google database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
} // }}}

void setup_tables() // {{{
{
  if (get_db()) {
    q(#"CREATE TABLE IF NOT EXISTS analytics (
       `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
       `key`  VARCHAR(32) NOT NULL,
       `date` DATETIME NOT NULL,
       `data` LONGBLOB NOT NULL)");
  }
} // }}}

SqlRes q(mixed ... args) // {{{
{
  return get_db()->query(@args);
} // }}}

Sql.Sql get_db() // {{{
{
  return DBManager.get(db_name, conf);
} //}}}

string get_data_cache(string key, void|Calendar.Day day) // {{{
{
  SqlRes r = q("SELECT `id`,`data`,`date` FROM analytics WHERE `key`=%s", key);
  if (r && sizeof(r)) {
    if (day) {
      Calendar.Fraction old_date = Calendar.parse("%Y-%M-%D", r[0]->date);
      if (day > old_date) {
	werror("### Day is larger than Old date\n");
	q("DELETE FROM analytics WHERE id=%s", r[0]->id);
	return 0;
      }
    }

    return Gz.inflate()->inflate(r[0]->data);
  }

  return 0;
} // }}}

void save_data_cache(string key, string val) // {{{
{
  if (get_data_cache(key))
    q("DELETE FROM analytics WHERE `key`=%s", key);

  val = Gz.deflate(6)->deflate(val, Gz.FINISH);

  q("INSERT INTO analytics (`key`, `date`, `data`) VALUES (%s, NOW(), %s)",
    key, val);
} // }}}

class TagEmitGoogleAnalytics // {{{
{
  inherit RXML.Tag;

  constant name        = "emit";
  constant plugin_name = "google-analytics";
  constant CLIENT_NAME = "tekniskaverken-analytics-0.1";

  mapping(string:RXML.Type) req_arg_types = ([
    "username" : RXML.t_text(RXML.PEnt),
    "password" : RXML.t_text(RXML.PEnt),
    "table"    : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "metrics"        : RXML.t_text(RXML.PEnt),
    "dimensions"     : RXML.t_text(RXML.PEnt),
    "sort"           : RXML.t_text(RXML.PEnt),
    "start-date"     : RXML.t_text(RXML.PEnt),
    "end-date"       : RXML.t_text(RXML.PEnt),
    "filters"        : RXML.t_text(RXML.PEnt),
    "start-date-var" : RXML.t_text(RXML.PEnt),
    "end-date-var"   : RXML.t_text(RXML.PEnt),
    "daily"          : RXML.t_text(RXML.PEnt),
    "aggregates-var" : RXML.t_text(RXML.PEnt),
    "unique-paths"   : RXML.t_text(RXML.PEnt)
  ]);

  multiset(string) keep = (< "metrics", "dimensions", "sort", "filters",
                             "start-date", "end-date", "max-results" >);

  array get_dataset(mapping args, RequestID id)
  {
    array ret = ({});

    DesktopApi api = DesktopApi();

    string cache_key = CACHE_KEY();
    string xml_data;
    Calendar.Day day;
    if (args->daily)
      day = Calendar.now()->day();

    if (!(xml_data = get_data_cache(cache_key, day))) {
      mapping params = ([]);
      foreach (args; string k; string v)
	if (keep[k] && sizeof(String.trim_all_whites(v)))
	  params[k] = v;

      if (!api->authenticate(args->username, args->password, CLIENT_NAME))
	RXML.run_error("Unable to login to Analytics!\n");

      mixed e = catch {
	xml_data = api->get_data(args->table, params);
	if (xml_data)
	  save_data_cache(cache_key, xml_data);
	else
	  return ret;
      };

      if (e) {
      	RXML.run_error("Error when fetching data!\n", describe_error(e));
      	return ({});
      }
    }
    else TRACE("Found data in cache!\n");

    DataParser d = DataParser();
    d->parse(xml_data);

    if ( string s = args["start-date-var"] )
      RXML.user_set_var(s, d->start_date->format_ymd());

    if ( string s = args["end-date-var"] )
      RXML.user_set_var(s, d->end_date->format_ymd());

    if ( args["aggregates-var"] )
      RXML.user_set_var(args["aggregates-var"], d->aggregates);

    if ( args["unique-paths"] ) {
      array(mapping) rows = ({});
      mapping mp = ([]);

      foreach (d->rows, mapping row) {
	if (has_suffix(row->pagepath, "index.xml"))
	  row->pagepath -= "index.xml";

	string idx = row->pagepath + row->hostname;
      	if ( mp[idx] ) {
      	  mp[idx]->pageviews += row->pageviews;
      	  mp[idx]->uniquepageviews += row->uniquepageviews;
      	  if (row->pagetitle != "(not set)")
      	    mp[idx]->pagetitle = row->pagetitle;
      	}
      	else
      	  mp[idx] = row;
      }

      d->rows = reverse(Array.sort_array(values(mp), 
	lambda(mapping a, mapping b) {
	  return a->pageviews > b->pageviews;
	}
      ));
    }

    return d->rows;
  }
} // }}}
