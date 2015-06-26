/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  Instagram tags
*/

#charset utf-8

#include <config.h>
#include <module.h>
inherit "module";

inherit "roxen-module://social-tagset" : tagset;

#define _ok RXML_CONTEXT->misc[" _ok"]

//#define SOCIAL_DEBUG_INSTA

#ifdef SOCIAL_DEBUG_INSTA
# define TRACE(X...) werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Instagram";
constant module_doc  = "Instagram tagset";

Configuration conf;

constant plugin_name = "instagram";
constant cookie_name = "instasess";
constant Klass = RoxenInstagram;
constant SOCIAL_MAIN_MODULE = 0;

private DataCache dcache = DataCache();

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");
  conf = _conf;
  tagset::create(conf);

  //dcache = DataCache();
}

void start(int when, Configuration _conf){}

multiset(string) query_provides() { return 0; }

class TagInstagram
{
  inherit tagset::TagSocial;

  constant name = "instagram";

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagInstagram", ({
      TagInstagramLoginUrl(),
      TagInstagramLogin(),
      TagInstagramLogout(),
      TagEmitInstagramRequest(),
      TagEmitInstagramTags(),
      TagEmitInstagramFeed()
    })
  );

  // Login URL
  class TagInstagramLoginUrl
  {
    inherit TagSocialLoginUrl;
    constant name = "instagram-login-url";

    string do_login_url(mapping args, RequestID id)
    {
      TRACE("Login URL in Instagram!\n");
      return ::do_login_url(args, id);
    }
  }

  class TagInstagramLogin
  {
    inherit TagSocialLogin;
    constant name = "instagram-login";

    array do_login(mapping args, RequestID id)
    {
      array data = ::do_login(args, id);
      TRACE("do_login in instagram: %O\n\n", data);

      if (data && sizeof(data) && args->variable)
        RXML.user_set_var(args->variable, data[0]);
    }
  }

  class TagInstagramLogout
  {
    inherit TagSocialLogout;
    constant name = "instagram-logout";
  }

  class TagEmitInstagramRequest
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "instagram-request";

    array do_request(mapping args, RequestID id)
    {
      array ret = ({});
      string ck;
      if (!args["no-cache"]) {
        TRACE("No no-cache, try get cache\n");
        ck = do_get_cache_key(args, id);

        if (ret = dcache->get(ck)) {
          TRACE("Got cached result:%O!\n", sizeof(ret));
          return ret;
        }
      }

      mapping p = do_get_params(args, id);
      RoxenInstagram api = api_instance(id);
      string uid = 0;

      if (p->user && sizeof(p->user)) {
        uid = p->user;
        m_delete(p, "user");
      }

      function f = api[args->method][args->query];

      TRACE("Func: %O(%O, %O)\n", f, uid, p);

      if (f) {
        mapping res = f(uid, p);

        if (args->select) {
          mixed r = get_selection(res, args->select);
          if (r && !arrayp(r))
            ret = ({ r });
          else
            ret = r;
        }
        else ret = ({ res });

        if (!args["no-cache"]) {
          int len = (args->cache && (int)args->cache) || 600;
          dcache->set(ck, ret, len);
        }

        return ret;

      }

      return ({});
    }
  }

  class TagEmitInstagramTags
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "instagram-tags";

    mapping(string:RXML.Type) req_arg_types = ([
      "tag" : RXML.t_text(RXML.PEnt),
    ]);

    mapping(string:RXML.Type) opt_arg_types = ([
      "no-cache" : RXML.t_text(RXML.PEnt),
      "cache" : RXML.t_text(RXML.PEnt),
      "select" : RXML.t_text(RXML.PEnt),
      "order-by" : RXML.t_text(RXML.PEnt)
    ]);

#define ORDER_BY() do {                                   \
  if (args["order-by"] && sizeof(args["order-by"])) {     \
    if (args["order-by"] == "random") {                   \
      Array.shuffle(ret);                                 \
    }                                                     \
  }                                                       \
} while (0)

    protected array query_hash_tag(string tag, mapping _args, RequestID id)
    {
      array ret = ({});

      tag = Roxen.http_encode_url(tag);

      TRACE("Args: %O\n", _args);

      mapping args = copy_value(_args);
      args->tag = tag;

      string ck;
      if (!args["no-cache"]) {
        TRACE("No no-cache, try get cache\n");
        ck = do_get_cache_key(args, id);

        if (ret = dcache->get(ck)) {
          TRACE("Got cached result:%O!", sizeof(ret));
          ORDER_BY();
          return ret;
        }
      }

      mapping p = do_get_params(args, id);
      RoxenInstagram api = api_instance(id);

      TRACE("Instagram API: %O, params: %O\n", api, p);

      mapping res = api->tags->recent(args->tag, p);

      TRACE("Fetch res: %O : %O\n", args->tag, res && sizeof(res));

      if (!res) {
        report_notice("No result from emit#instagram-tags: %O\n", p);
        return ret;
      }

      if (args->select) {
        mixed r = get_selection(res, args->select);
        if (r && !arrayp(r))
          ret = ({ r });
        else
          ret = r || ({});
      }
      else ret = ({ res });

      if (!args["no-cache"]) {
        int len = (args->cache && (int)args->cache) || 600;
        dcache->set(ck, ret, len);
      }

      ORDER_BY();

      return ret;
    }

    array get_dataset(mapping args, RequestID id)
    {
      array ret = ({});

      foreach (args->tag/",", string tag) {
        TRACE("Query hash tag: %s\n", tag);
        ret += query_hash_tag(String.trim_all_whites(tag), args, id) || ({});
      }

      TRACE("Result: %O\n", (ret));

      if (search(args->tag, ",") > -1) {
        mapping used  = ([]);
        array new_ret = ({});

        foreach (ret, mapping m) {
          if (used[m->id])
            continue;
          used[m->id] = 1;
          new_ret += ({ m });
        }

        ret = new_ret;

        TRACE("Result after uniq: %O\n", sizeof(ret));
      }

      if (!args["order-by"] && search(args->tag, ",") > -1) {
        ret = Array.sort_array(ret, lambda(mapping a, mapping b) {
                                      return a->created_time < b->created_time;
                                    });
      }

      return ret;
    }
  }

  class TagEmitInstagramFeed
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "instagram-feed";

    mapping(string:RXML.Type) req_arg_types = ([
    ]);

    mapping(string:RXML.Type) opt_arg_types = ([
      "no-cache" : RXML.t_text(RXML.PEnt),
      "cache" : RXML.t_text(RXML.PEnt),
      "select" : RXML.t_text(RXML.PEnt),
      "user" : RXML.t_text(RXML.PEnt)
    ]);

    array get_dataset(mapping args, RequestID id)
    {
      array ret = ({});

      string ck;
      if (!args["no-cache"]) {
        TRACE("No no-cache, try get cache\n");
        ck = do_get_cache_key(args, id);

        if (ret = dcache->get(ck)) {
          TRACE("Got cached result:%O!", ret);
          return ret;
        }
      }

      mapping p = do_get_params(args, id);
      RoxenInstagram api = api_instance(id);

      TRACE("Instagram API: %O\n", api);

      mapping res = api->users->feed(p);

      if (args->select) {
        mixed r = get_selection(res, args->select);
        if (r && !arrayp(r))
          ret = ({ r });
        else
          ret = r;
      }
      else ret = ({ res });

      if (!args["no-cache"]) {
        int len = (args->cache && (int)args->cache) || 600;
        dcache->set(ck, ret, len);
      }

      return ret;
    }
  }
}

//protected mapping(string:object) twcache = ([]);

class RoxenInstagram
{
  inherit Social.Instagram;
}

private class TagSocialBanAdd {}
private class TagSocialBanRemove {}
private class TagEmitBans {}
private class TagEmitSubscope {}
private class TagTimeToDuration {}