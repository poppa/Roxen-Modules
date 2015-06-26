/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.
*/

#charset utf-8

#include <config.h>
#include <module.h>
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Tags for weather forecast from Forecast.IO";
constant module_doc  = #"Forecast tag, what's the weather like?";

Configuration conf;
private mapping aliases;
private string db_name;
private string api_key;
private string def_lang;
private string def_units;
private string def_exclude;
private int update_interval;

#define get_db() DBManager.get(db_name, conf)
#define q(X...) get_db()->query(X)

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");

  defvar("api_key",
    Variable.String(
      "", 0, "API key",
      "The API key for the forecast.io services"
    )
  );

  defvar("def_lang",
    Variable.String(
      "", 0, "Default language",
      "Default langugage to use for the responses"
    )
  );

  defvar("def_units",
    Variable.String(
      "", 0, "Default units",
      "Default units to use for the responses"
    )
  );

  defvar("def_exclude",
    Variable.String(
      "", 0, "Default exclusions",
      "Default blocks to exclude from the responses"
    )
  );

  defvar("location_alias",
    Variable.Mapping(
      ([]), 0, "Location aliases",
      "The key is the alias, the value is the location identifer"
    )
  );

  defvar("update_interval",
    Variable.Int(
      0, 0, "Update interval",
      "Number of minutes between background updates"
    )
  );

  defvar("db_name",
    Variable.DatabaseChoice(
      "forecast_" + (_conf ? Roxen.short_name(_conf->name) : ""), 0,
      "Forecast database",
      "The database where we store forecast info"
    )->set_configuration_pointer(my_configuration)
  );

  conf = _conf;
}

array update_co;

void start(int when, Configuration _conf)
{
  api_key = query("api_key");
  aliases = query("location_alias");
  db_name = query("db_name");
  def_lang = query("def_lang");
  def_units = query("def_units");
  def_exclude = query("def_exclude");
  update_interval = query("update_interval");

  init_db();

  if (update_interval > 0) {
    call_out(background_update, 0.2);
  }
}

void stop()
{
  if (update_co) {
    remove_call_out(update_co);
  }
}

private void background_update()
{
  werror("background_update\n");

  if (update_co) remove_call_out(update_co);
  array(mapping) items = q("SELECT * FROM forecast_io");

  Calendar.Second now = Calendar.now();

  now = now - (now->minute()*update_interval);

  werror("Now (then): %O\n", now);

  foreach (items||({}), mapping m) {
    Calendar.Second last_ud = Calendar.parse("%Y-%M-%D %h:%m:%s", m->date);
    werror("Last update: %O\n", last_ud);

    if (now > last_ud) {
      werror("Do update this\n");
      call_out(low_update, 0, m);
    }
  }

  update_co = call_out(background_update, update_interval*60);
}

private void low_update(mapping item)
{
  werror("low_update: %O\n", item->key);
  mapping p = Standards.JSON.decode(item->params);

  mixed e = catch {
    Weather.ForecastIO c;
    c = Weather.ForecastIO(p->apikey, p->units, p->lang, p->exclude);
    Weather.ForecastIO.Result r = c->forecast(p->lat, p->lng);
    mapping data = (mapping) r;
    string sdata = Standards.JSON.encode(data);

    q("UPDATE forecast_io SET json=:json,`date`=NOW() WHERE `key`=:key",
      ([ "json" : sdata, "key" : item->key ]));

    werror("Update OK for %s\n", item->key);
  };

  if (e) {
    report_error("Error updaing forecast.io: %s\n", describe_backtrace(e));
  }
}

private void init_db()
{
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      report_error("No permission to read forecast database: %s\n", db_name);
      return;
    }

    report_notice("No forecast database present. Creating \"%s\".\n", db_name);

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
                           "Used by the Foreacast module(s) to "
                           "store its data.");
    if (!get_db()) {
      report_error("Unable to create Forecast database.\n");
      return;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
}

private void setup_tables()
{
  if (Sql.Sql db = get_db()) {
    //db->query("DROP TABLE `forecast_io`");
    db->query(#"
      CREATE TABLE IF NOT EXISTS `forecast_io`  (
        `key`  VARCHAR(255) NOT NULL,
        `json` LONGTEXT NOT NULL,
        `params` LONGTEXT NOT NULL,
        `date` DATETIME NULL,
        PRIMARY KEY (`key`))
      ENGINE = MyISAM
    ");

    DBManager.is_module_table(0, db_name, "forecast_io", 0);
  }
}

#define EMPTY(X) (!X || !sizeof(X))

class TagEmitForecastIO
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "forecast-io";

  mapping(string:RXML.Type) req_arg_types = ([
    // "attribute" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "apikey"   : RXML.t_text(RXML.PEnt),
    "alias"    : RXML.t_text(RXML.PEnt),
    "units"    : RXML.t_text(RXML.PEnt),
    "language" : RXML.t_text(RXML.PEnt),
    "exclude"  : RXML.t_text(RXML.PEnt),
    "lat"      : RXML.t_text(RXML.PEnt),
    "lng"      : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string akey = EMPTY(args->apikey) ? api_key : args->apikey;

    if (EMPTY(akey)) {
      RXML.parse_error("No API KEY is set!");
    }

    float lng, lat;

    if (!EMPTY(args->alias)) {
      string s = aliases[args->alias];

      if (!s) {
        RXML.parse_error("Unknown alias \"%s\"!", args->alias);
      }

      array(string) p = map(s/",", String.trim_all_whites);

      if (sizeof(p) != 2) {
        RXML.parse_error("Misconfigures alias \"%s\". "
                         "Must be a comma separated string of "
                         "\"latitude,longitude\"!", args->alias);
      }

      lat = (float) p[0];
      lng = (float) p[1];
    }
    else {
      if (EMPTY(args->lat)) {
        RXML.parse_error("Missing required attribute \"lat\"!");
      }
      if (EMPTY(args->lng)) {
        RXML.parse_error("Missing required attribute \"lng\"!");
      }

      lat = (float) args->lat;
      lng = (float) args->lng;
    }

    string exclude = def_exclude;

    if (!EMPTY(args->exclude)) {
      exclude = map(args->exclude/",", String.trim_all_whites)*",";
    }

    string units = def_units || "auto";

    if (args->units) {
      units = args->units;
    }

    string lang = def_lang;

    if (!EMPTY(args->language)) {
      lang = args->language;
    }

    Weather.ForecastIO fio;

    mapping params = ([
      "apikey"  : akey,
      "lat"     : lat,
      "lng"     : lng,
      "units"   : units,
      "lang"    : lang,
      "exclude" : exclude
    ]);

    string pjson = Standards.JSON.encode(params);
    string key   = roxen.md5(map(sort(indices(params)),
                                 lambda (string k) {
                                   return k + params[k];
                                 })*"");
    mapping data;

    mixed e = catch {
      array(mapping) res = q("SELECT * FROM forecast_io WHERE `key`=%s", key);

      if (res && sizeof(res)) {
        werror("Found data in DB!\n");
        string t = utf8_to_string(res[0]->json);
        data = Standards.JSON.decode(t);
        data->last_update = res[0]->date;
      }
      else {
        werror("Querying Forecast.IO\n");
        fio = Weather.ForecastIO(akey, units, lang, exclude);
        Weather.ForecastIO.Result r = fio->forecast(lat, lng);
        data = (mapping) r;
        string sdata = Standards.JSON.encode(data);

        q("INSERT INTO forecast_io (`key`, `json`, `params`, `date`) "
          "VALUES (:key, :json, :params, NOW())",
          ([ "key" : key, "json" : sdata, "params" : pjson ]));

        data->last_update = Calendar.now()->format_time();
      }
    };

    if (e) {
      werror("An error occured: %s\n", describe_backtrace(e));
    }

    werror("Data: %O\n", data);

    return ({ data }) - ({ 0 });
  }
}
