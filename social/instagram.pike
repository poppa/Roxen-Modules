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

#define SOCIAL_DEBUG

#ifdef SOCIAL_DEBUG
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

private DataCache dcache = DataCache();

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");
  conf = _conf;
  tagset::create(conf);
  //dcache = DataCache();
}

void start(int when, Configuration _conf){}

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
      TagEmitInstagramTags()
    })
  );

  // Login URL
  class TagInstagramLoginUrl
  {
    inherit TagSocialLoginUrl;
    constant name = "instagram-login-url";

    string do_login_url(mapping args, RequestID id)
    {
      TRACE ("Login URL in Instagram!\n");
      return ::do_login_url(args, id);
    }
  }

  class TagInstagramLogin
  {
    inherit TagSocialLogin;
    constant name = "instagram-login";

    array do_login (mapping args, RequestID id)
    {
      array data = ::do_login (args, id);
      TRACE ("do_login in instagram: %O\n\n", data);
    }
  }

  class TagInstagramLogout
  {
    inherit TagSocialLogout;
    constant name = "instagram-logout";
  }

  class TagEmitInstagramRequest // {{{
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "instagram-request";

    array do_request(mapping args, RequestID id)
    {
      mapping p = do_get_params(args, id);
      RoxenInstagram api = api_instance(id);
      string uid = 0;

      if (p->user && sizeof(p->user)) {
        uid = p->user;
        m_delete(p, "user");
      }

      function f = api[args->method][args->query];
      if (f) {
        mapping res = f(uid, p);
        if (res) {
          return ({ res });
        }
      }

      return ({});
    }
  }

  class TagEmitInstagramTags // {{{
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "instagram-tags";

    mapping(string:RXML.Type) req_arg_types = ([
      "tag" : RXML.t_text(RXML.PEnt),
    ]);

    mapping(string:RXML.Type) opt_arg_types = ([
      "no-cache" : RXML.t_text(RXML.PEnt),
      "cache" : RXML.t_text(RXML.PEnt),
      "select" : RXML.t_text(RXML.PEnt)
    ]);

    array get_dataset(mapping args, RequestID id)
    {
      array ret = ({});

      string ck;
      if (!args["no-cache"]) {
        ck = do_get_cache_key(args, id);

        if (ret = dcache->get(ck)) {
          TRACE("Got cached result:%O!", ret);
          return ret;
        }
      }

      mapping p = do_get_params(args, id);
      RoxenInstagram api = api_instance(id);

      mapping res = api->tags->recent(args->tag, p);

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

protected mapping(string:object) twcache = ([]);

class RoxenInstagram
{
  inherit Social.Instagram;
}