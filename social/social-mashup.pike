#charset utf-8

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y) _DEF_LOCALE("sitebuilder",X,Y)

//#define TVAB_DEBUG

#ifdef TVAB_DEBUG
# define TRACE(X...) werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...) 0
#endif

#include <config.h>
#include <module.h>
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Social Mashup";
constant module_doc  = "";

#define _ok RXML_CONTEXT->misc[" _ok"]

Configuration conf;

class TagEmitSocialMashup // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "social-mashup";

  mapping(string:RXML.Type) req_arg_types = ([
    "url" : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "delimiter" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array(mapping) ret = ({});

    array(string) urls = map(args->url/(args->delimiter||","),
                             lambda (string s) {
                               return String.trim_all_whites(s);
                             });

    array(Web.Feed.AbstractItem) items = ({});
    foreach (urls, string url) {
      string code = sprintf("<insert cached-href='%s' "
                            "fetch-interval='10min' />", url);

      string res = Roxen.parse_rxml(code, id);
      res = Roxen.html_decode_string(res);
      mixed e = catch {
        object o = Web.Feed.parse(res);
        items += o->get_items();
      };

      if (e) {
        werror("%s:%d: Error parsing feed (%s): %s\n",
               basename(__FILE__), __LINE__, url, describe_error(e));
      }
    }

    foreach (items, object item) {
      mapping data = item->get_data();
      if (objectp(data->date))
        data->date = data->date->format_time();

      data->title = safe_utf8_decode(data->title);

      ret += ({ data });
    }

    ret = Array.sort_array(ret,
      lambda (mapping a, mapping b) {
        return a->date < b->date;
      }
    );

    if (args->maxrows && sizeof(ret) > (int)args->maxrows)
      ret = ret[0..((int)args->maxrows)-1];

    return ret;
  }
} // }}}

class TagEmitSocialHashtag // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "social-hashtag";

  mapping(string:RXML.Type) req_arg_types = ([
    "tag" : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "fb-query" : RXML.t_text(RXML.PXml),
    "insta-query" : RXML.t_text(RXML.PXml),
    "application" : RXML.t_text(RXML.PXml),
    "get-banned" : RXML.t_text(RXML.PXml),
    "fetch-interval" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array(mapping) ret = ({});
    array(string) bans;
    int(0..1) show_bans = !!args["get-banned"];

    if (args["application"]) {
      RoxenModule soc = conf->get_provider("social");
      bans = soc->get_bans(args->application)->objectid;
    }

    string code, res;
    mixed e;

    string fiv = args["fetch-interval"] && sizeof(args["fetch-interval"]) ||
                 "10m";

    if (args["insta-query"] && sizeof(args["insta-query"])) {
      string url = args["insta-query"];
      url = replace(url, "{$tag}", Roxen.http_encode_url(args->tag[1..]));
      TRACE("Insta query: %s\n", url);

      code = sprintf("<insert cached-href='%s' "
                     "pure-db='' fetch-interval='%s' />",
                     url, fiv);

      res = Roxen.parse_rxml(code, id);
      res = Roxen.html_decode_string(res);

      e = catch {
        if (res && sizeof(res)) {
          mixed instares = Standards.JSON.decode(res);
          string min_created = "1408374280";

          foreach (instares->data, mapping row) {
            if (row->created_time < min_created) {
              TRACE("Breaking old posts!\n");
              break;
            }

            mapping d = ([
              "source" : "instagram",
              "user" : ([
                "name" : row->user->full_name || row->user->username,
                "avatar" : row->user->profile_picture,
                "url" : "https://instagram.com/" + row->user->username,
                "id" : row->user->id
              ]),
              "image" : ([
                "url" : replace(row->images->standard_resolution->url,
                                "http:", "https:")
              ]),
              "text" : row->caption->text,
              "created" : (int) row->created_time,
              "elapsed" : time_elapsed((int) row->created_time),
              "id" : row->id,
              "url" : row->link,
              "type" : row->type
            ]);

            ret += ({ d });
          }
        }
      };

      if (e) {
        werror("Error parsing Instafeed: %s\n", describe_backtrace(e));
      }
    }

    if (args["fb-query"] && sizeof(args["fb-query"])) {
      code = sprintf("<insert cached-href='%s' "
                     "pure-db='' fetch-interval='%s' />",
                     args["fb-query"], fiv);

      res = Roxen.parse_rxml(code, id);
      res = Roxen.html_decode_string(res);

      e = catch {
        if (res && sizeof(res)) {
          mixed fbres = Standards.JSON.decode(res);
          //TRACE("FB res: %O\n", fbres||"(null)");

          foreach (fbres->data, mapping row) {

            if (row->type == "photo" &&
                (row->message && search(row->message, args->tag) > -1))
            {
              Calendar.Second created = Calendar.parse("%Y-%M-%DT%h:%m:%s%z",
                                                       row->created_time);

              string photo_url = sprintf("https://graph.facebook.com/%s/picture",
                                         row->object_id);
              mapping d = ([
                "source" : "facebook",
                "user" : ([
                  "name" : row->from->name,
                  "url" : "https://www.facebook.com/" + row->from->id,
                  "avatar" : sprintf("https://graph.facebook.com/%s/picture",
                                     row->from->id),
                  "id" : row->from->id
                ]),
                "image" : ([
                  "url" : photo_url
                ]),
                "text" : row->message,
                "created" : created->unix_time(),
                "elapsed" : time_elapsed(created->unix_time()),
                "id" : row->object_id,
                "url" : row->link,
                "type" : row->type
              ]);

              ret += ({ d });
            }
          }
        }
      };

      if (e) {
        werror("Error parsing FB-feed: %s\n", describe_backtrace(e));
      }

    }

    if (bans && ret) {
      ret = filter(ret, lambda (mapping m) {
        if (has_value(bans, m->id) || has_value(bans, m->user->id)) {
          if (!show_bans)
            return 0;

          m->banned = 1;
          m["ban-type"] = has_value(bans, m->user->id) ? "user" : "post";
        }

        return m;
      }) - ({ 0 });
    }

    ret = ret || ({});

    return Array.sort_array(ret, lambda (mapping a, mapping b) {
                                   return a->created < b->created;
                                 });
  }
} // }}}

class TagEmitInstaTagMash // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "insta-tag-mash";

  mapping(string:RXML.Type) req_arg_types = ([
    //"query" : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "application"    : RXML.t_text(RXML.PXml),
    "get-banned"     : RXML.t_text(RXML.PXml),
    "fetch-interval" : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array(mapping) ret = ({});
    array(string) bans;
    int(0..1) show_bans = !!args["get-banned"];
    string fetch_interval = args["fetch-interval"] || "10min";

    if (args["application"]) {
      RoxenModule soc = conf->get_provider("social");
      bans = soc->get_bans(args->application)->objectid;
    }

    mapping tags = ([]);

    foreach (indices(args), string arg) {
      if (sscanf (arg, "query-%s", string tag) > 0) {
        tags[tag] = ([ "url" : args[arg] ]);
      }
    }

    string template = "<insert cached-href='%s' "
                      "pure-db='' fetch-interval='%s' />";

    foreach (tags; string tag; mapping m) {
      string url = sprintf(template, m->url, fetch_interval);
      string res = Roxen.parse_rxml(url, id);
      if (res && sizeof(res)) {
        tags[tag]->data = Roxen.html_decode_string(res);
      }
    }

    foreach (tags; string tag; mapping m) {
      if (!m->data || !sizeof(m->data))
        continue;

      mixed e = catch  {
        mixed ires = Standards.JSON.decode(m->data);
        foreach (ires->data, mapping row) {
          mapping d = ([
            "source" : "instagram",
            "tag" : tag,
            "user" : ([
              "name" : row->user->full_name || row->user->username,
              "username" : row->user->username||"",
              "avatar" : row->user->profile_picture,
              "url" : "https://instagram.com/" + row->user->username,
              "id" : row->user->id
            ]),
            "image" : ([
              "url" : replace(row->images->standard_resolution->url,
                              "http:", "https:")
            ]),
            "tags" : row->tags,
            "likes" : row->likes,
            "comments" : row->comments,
            "text" : row->caption->text,
            "created" : (int) row->created_time,
            "elapsed" : time_elapsed((int) row->created_time),
            "id" : row->id,
            "url" : row->link,
            "type" : row->type
          ]);

          ret += ({ d });
        }
      };

      if (e) {
        report_error("JSON decode errror: %s\n", describe_backtrace(e));
      }
    }

    ret = Array.sort_array(ret, lambda (mapping a, mapping b) {
                                  return a->created < b->created;
                                });

    return ret;

#if 0

    string res = Roxen.parse_rxml(code, id);
    res = Roxen.html_decode_string(res);

    mixed e = catch {
      if (res && sizeof(res)) {
        mixed instares = Standards.JSON.decode(res);
        string min_created = "1408374280";

        foreach (instares->data, mapping row) {
          if (row->created_time < min_created) {
            TRACE("Breaking old posts!\n");
            break;
          }

          mapping d = ([
            "source" : "instagram",
            "user" : ([
              "name" : row->user->full_name || row->user->username,
              "avatar" : row->user->profile_picture,
              "url" : "https://instagram.com/" + row->user->username,
              "id" : row->user->id
            ]),
            "image" : ([
              "url" : replace(row->images->standard_resolution->url,
                              "http:", "https:")
            ]),
            "text" : row->caption->text,
            "created" : (int) row->created_time,
            "elapsed" : time_elapsed((int) row->created_time),
            "id" : row->id,
            "url" : row->link,
            "type" : row->type
          ]);

          ret += ({ d });
        }
      }
    };

    if (e) {
      werror("Error parsing Instafeed: %s\n", describe_backtrace(e));
    }

    code = sprintf("<insert cached-href='%s' "
                   "pure-db='' fetch-interval='10min' />",
                   args["fb-query"]);

    res = Roxen.parse_rxml(code, id);
    res = Roxen.html_decode_string(res);

    e = catch {
      if (res && sizeof(res)) {
        mixed fbres = Standards.JSON.decode(res);
        //TRACE("FB res: %O\n", fbres||"(null)");

        foreach (fbres->data, mapping row) {

          if (row->type == "photo" &&
              (row->message && search(row->message, args->tag) > -1))
          {
            Calendar.Second created = Calendar.parse("%Y-%M-%DT%h:%m:%s%z",
                                                     row->created_time);

            string photo_url = sprintf("https://graph.facebook.com/%s/picture",
                                       row->object_id);
            mapping d = ([
              "source" : "facebook",
              "user" : ([
                "name" : row->from->name,
                "url" : "https://www.facebook.com/" + row->from->id,
                "avatar" : sprintf("https://graph.facebook.com/%s/picture",
                                   row->from->id),
                "id" : row->from->id
              ]),
              "image" : ([
                "url" : photo_url
              ]),
              "text" : row->message,
              "created" : created->unix_time(),
              "elapsed" : time_elapsed(created->unix_time()),
              "id" : row->object_id,
              "url" : row->link,
              "type" : row->type
            ]);

            ret += ({ d });
          }
        }
      }
    };

    if (e) {
      werror("Error parsing FB-feed: %s\n", describe_backtrace(e));
    }

    if (bans) {
      ret = filter(ret, lambda (mapping m) {
        if (has_value(bans, m->id) || has_value(bans, m->user->id)) {
          if (!show_bans)
            return 0;

          m->banned = 1;
          m["ban-type"] = has_value(bans, m->user->id) ? "user" : "post";
        }

        return m;
      }) - ({ 0 });
    }

    return Array.sort_array(ret, lambda (mapping a, mapping b) {
                                   return a->created < b->created;
                                 });
#endif
  }
} // }}}


string time_elapsed(int timestamp)
{
  int diff = (int) time(timestamp);
  int t;

  switch (diff)
  {
    case      0 .. 30: return "Just nu";
    case     31 .. 120: return "Nyligen";
    case    121 .. 3600: return sprintf("%d minuter sedan",(int)(diff/60.0));
    case   3601 .. 86400:
      t = (int)((diff/60.0)/60.0);
      return sprintf("%d %s sedan", t, t > 1 ? "timmar" : "timme");

    case  86401 .. 604800:
      t = (int)(((diff/60.0)/60.0)/24);
      return sprintf("%d dag%s sedan", t, t > 1 ? "ar" : "");

    case 604801 .. 31449600:
      t = (int)((((diff/60.0)/60.0)/24)/7);
      return sprintf("%d %s sedan", t, t > 1 ? "veckor" : "vecka");
  }

  return "Länge länge sedan";
}

protected string safe_utf8_decode(string s) // {{{
{
  catch (s = utf8_to_string(s));
  return s;
} // }}}

void create(Configuration _conf) // {{{
{
  conf = _conf;
  set_module_creator("Pontus Östlund <pontus.ostlund@tekniskaverken.se>");
} // }}}

void start(int when, Configuration _conf) // {{{
{
} //}}}
