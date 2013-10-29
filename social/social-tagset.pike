/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  Base tags set for social networking APIs
*/

#charset utf-8

#include <config.h>
#include <module.h>
inherit "module";

#define _ok RXML_CONTEXT->misc[" _ok"]

#if 0
/* The Facebook Authorization object */
#define FB  id->misc->facebook
#define FB_AUTH  id->misc->facebook->authorization
#define SET_COOKIE(V) Roxen.set_cookie(id, cookie_name, \
                                       encode_cookie(encode_value(V)),-1,0,"/")
#define REMOVE_COOKIE() Roxen.remove_cookie(id, cookie_name, "", 0, "/")
#endif

#define SOCIAL_DEBUG

#ifdef SOCIAL_DEBUG
# define TRACE(X...) werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Social";
constant module_doc  = "Base tagset for autentication and communication with "
                       "social APIs.";

Configuration conf;

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");

  defvar("api_key",
         Variable.String("", 0, "API key", "Default API key"));

  defvar("api_secret",
         Variable.String("", 0, "API secret", "Default API secret"));

  defvar("redirect_uri",
         Variable.String("", 0, "Redirect URI", "Where should the user return "
                                                "to after authorization"));

  defvar("default_scopes",
         Variable.String("", 0, "Default scopes", "Default app permissions"));

  conf = _conf;
}

constant plugin_name = "social";
constant cookie_name = "socialsess";
constant Klass = Social.Api;

Social.Api api_instance(RequestID id)
{
  return id->misc[plugin_name];
}

Social.Api.Authorization auth_instance(RequestID id)
{
  return id->misc[plugin_name] && id->misc[plugin_name]->authorization;
}

Social.Api register_instance(Social.Api api, RequestID id)
{
  TRACE ("Register API: %O\n", api);
  id->misc[plugin_name] = api;
  return api;
}

void set_cookie(mixed v, RequestID id)
{
  Roxen.set_cookie(id, cookie_name, encode_cookie(encode_value(v)),-1,0,"/");
}

void remove_cookie(RequestID id)
{
  Roxen.remove_cookie(id, cookie_name, "", 0, "/");
}

void start(int when, Configuration _conf){}

class TagSocial
{
  inherit RXML.Tag;
  constant name = "social";

  mapping(string:RXML.Type) opt_arg_types = ([
    "api-key"     : RXML.t_text(RXML.PEnt),
    "api-secret"  : RXML.t_text(RXML.PEnt),
    "redirect-to" : RXML.t_text(RXML.PEnt),
    "permissions" : RXML.t_text(RXML.PEnt),
  ]);

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagSocial", ({
      TagSocialLoginUrl(),
      TagSocialLogin(),
      TagSocialLogout(),
      TagEmitSocialRequest()
    })
  );

  // Main Frame
  class Frame
  {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    mapping(string:mixed) vars = ([]);

    array do_enter(RequestID id)
    {
      CACHE(0);

      Social.Api api = api_instance(id);
      Social.Api.Authorization auth;

      if (api)
        RXML.parse_error("<%s></%s> can not be nested!\n", name, name);

      vars = ([
        "is-authenticated"  : "0",
        "is-login-callback" : "0",
        "is-error"          : "0",
        "is-expired"        : "1",
        "is-renewable"      : "0",
        "uid"               : "0",
        "expires"           : "0"
      ]);

      string ak = args["api-key"]     || query("api_key");
      string as = args["api-secret"]  || query("api_secret");
      string re = args["redirect-to"] || query("redirect_uri");

      api = register_instance(Klass(ak, as, re, args->permissions), id);
      auth = auth_instance(id);

      mixed cookie;
      if ((cookie = id->cookies[cookie_name]) && sizeof(cookie)) {
        TRACE("::::::::::: %s\n", cookie);
        auth->set_from_cookie(decode_cookie(cookie));

        if (auth->is_renewable())
          vars["is-renewable"] = "1";

        if (!auth->is_expired())
          vars["is-expired"] = "0";

        vars["is-authenticated"] = "1";

        mixed e = catch {
          if (mapping v = get_cookie(id))
            vars += v;
        };

        if (e)
          report_error("Facebook decoding error: %s\n", describe_backtrace(e));
      }

      if (id->variables->code)
        vars["is-login-callback"] = "1";

      if (id->variables->error) {
        vars["is-error"] = "1";
        vars["error"] = id->variables->error;
        vars["error-message"] = id->variables->error_description;
      }

      TRACE("%O\n", api);
      TRACE("%O\n", vars);

      return 0;
    }

    array do_return(RequestID id)
    {

      m_delete(id->misc, plugin_name);
      result = content;
      vars = ([]);
      return 0;
    }
  }

  // Login URL
  class TagSocialLoginUrl
  {
    inherit RXML.Tag;
    constant name = "social-login-url";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([
      "variable"   : RXML.t_text(RXML.PEnt),
      "cancel" : RXML.t_text(RXML.PEnt)
    ]);

    multiset(string) noargs = (< "variable" >);

    string do_login_url(mapping args, RequestID id)
    {
      Social.Api.Authorization auth = auth_instance(id);

      if (!args->cancel)
        args->cancel = auth->get_redirect_uri();

      mapping a = ([]);

      foreach (args; string k; string v)
        if (!noargs[k])
          a[k] = v;

      return auth->get_auth_uri(a);
    }

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
        string t = do_login_url(args, id);

        if (!t) {
          _ok = 0;
          return 0;
        }

        if (args->variable)
          RXML.user_set_var(args->variable, t);
        else
          result = t;

        _ok = 1;

        return 0;
      }
    }
  }

  class TagSocialLogin
  {
    inherit RXML.Tag;
    constant name = "social-login";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([]);

    array do_login(mapping args, RequestID id)
    {
      TRACE("Login code: %O\n", id->variables->code);
      Social.Api.Authorization auth = auth_instance(id);

      string v;
      if (mixed e = catch(v=auth->request_access_token(id->variables->code))) {
        report_error("request_access_token(): %s\n", describe_backtrace(e));
        _ok = 0;
        return 0;
      }

      mapping raw_token = decode_value(v);
      auth->set_from_cookie(v);

      set_cookie(raw_token, id);
      TRACE("Data: %O\n", raw_token);
      _ok = 1;

      return ({ raw_token });
    }

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
        do_login(args, id);
        return 0;
      }
    }
  }

  class TagSocialLogout
  {
    inherit RXML.Tag;
    constant name = "social-logout";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
        TRACE("Logout...\n");
        remove_cookie(id);
        _ok = 1;
        return 0;
      }
    }
  }

  class TagEmitSocialRequest // {{{
  {
    inherit RXML.Tag;
    constant name = "emit";
    constant plugin_name = "social-request";

    mapping(string:RXML.Type) req_arg_types = ([
      "method" : RXML.t_text(RXML.PEnt),
    ]);

    mapping(string:RXML.Type) opt_arg_types = ([
      "http-method" : RXML.t_text(RXML.PEnt),
      "no-cache" : RXML.t_text(RXML.PEnt),
      "cache" : RXML.t_text(RXML.PEnt),
      "select" : RXML.t_text(RXML.PEnt)
    ]);

    mapping do_get_params(mapping args, RequestID id)
    {
      mapping params = ([]);
      array(string) keys = indices(req_arg_types) + indices(opt_arg_types);

      foreach (args; string k; mixed v)
        if (!has_value(keys, k) && k != "source")
          params[k] = v;

      return params;
    }

    string do_get_cache_key(mapping args, RequestID id)
    {
      mapping cookie = get_cookie(id);
      if (!cookie) return 0;
      return make_cache_key(name+plugin_name,
                            args + ([ "__" : cookie->access_token ]));
    }

    array do_request(mapping args, RequestID id)
    {
      return ({});
    }

    array get_dataset(mapping args, RequestID id)
    {
      TRACE ("Am I here?\n");
      return do_request(args, id);
    }
  }
}

protected mixed get_selection(mapping data, string sel)
{
  array p = sel/".";
  int s = sizeof(p);
  if (s > 0)
    data = data[p[0]]||data;

  return data;
}

string encode_cookie(string v)
{
  return v && sizeof(v) && MIME.encode_base64(v);
}

string decode_cookie(string v)
{
  return v && sizeof(v) && MIME.decode_base64(v);
}

mapping get_cookie(RequestID id)
{
  if (string v = decode_cookie(id->cookies[cookie_name])) {
    TRACE("### THE COOKIE: %s\n", v);
    return decode_value(v);
  }

  return 0;
}

string make_cache_key(string name, mapping args)
{
  return Social.md5(name + indices(args)*"" + values(args)*"");
}

class DataCache
{
  protected mapping(string:object) twcache = ([]);

  mixed get(string key)
  {
    if (Item i = twcache[key]) {
      if (!i->expired())
        return i->data;

      delete(key);
      return 0;
    }
    return 0;
  }

  void set(string key, mixed value, void|int maxlife)
  {
    twcache[key] = Item(value, maxlife);
  }

  void delete(string key)
  {
    m_delete(twcache, key);
  }

  class Item
  {
    mixed data;
    int   created = 0;
    int   expires = 0;

    void create(mixed _data, void|int _expires)
    {
      data    = _data;
      created = time();
      if (_expires)
        expires = created + _expires;
    }

    int(0..1) expired()
    {
      return expires && time() > expires;
    }

    string _sprintf(int t)
    {
      return t == 'O' && sprintf("DataCache.Item(%O, %d, %d)",
                                 data, created, expires);
    }
  }
}
