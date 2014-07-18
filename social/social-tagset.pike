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

//#define SOCIAL_DEBUG

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

  defvar("access_token",
         Variable.String("", 0, "Access token", "Generic access token to use "
                                                "if the service supports "
                                                "persistent authentications"));
  defvar("redirect_uri",
         Variable.String("", 0, "Redirect URI", "Where should the user return "
                                                "to after authorization"));

  defvar("default_scopes",
         Variable.String("", 0, "Default scopes", "Default app permissions"));

  conf = _conf;
}

constant plugin_name = "social";
protected constant cookie_name = "socialsess";
protected constant Klass = Social.Api;

protected Social.Api api_instance(RequestID id)
{
  return id->misc[plugin_name];
}

protected Social.Api.Authorization auth_instance(RequestID id)
{
  return id->misc[plugin_name] && id->misc[plugin_name]->authorization;
}

protected Social.Api register_instance(Social.Api api, RequestID id)
{
  TRACE("Register API: %O : %O\n", api, plugin_name);
  id->misc[plugin_name] = api;
  return api;
}

protected void set_cookie(mixed v, RequestID id)
{
  Roxen.set_cookie(id, cookie_name, encode_cookie(encode_value(v)),-1,0,"/");
}

protected void remove_cookie(RequestID id)
{
  Roxen.remove_cookie(id, cookie_name, "", 0, "/");
}

void start(int when, Configuration _conf){}

class TagSocial
{
  inherit RXML.Tag;
  constant name = "social";

  mapping(string:RXML.Type) opt_arg_types = ([
    "api-key"      : RXML.t_text(RXML.PEnt),
    "api-secret"   : RXML.t_text(RXML.PEnt),
    "access-token" : RXML.t_text(RXML.PEnt),
    "redirect-to"  : RXML.t_text(RXML.PEnt),
    "permissions"  : RXML.t_text(RXML.PEnt),
    "cookie-name"  : RXML.t_text(RXML.PEnt)
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

      vars = ([
        "is-authenticated"  : "0",
        "is-login-callback" : "0",
        "is-error"          : "0",
        "is-expired"        : "1",
        "is-renewable"      : "0",
        "uid"               : "0",
        "expires"           : "0"
      ]);

      string ak   = args["api-key"]     || query("api_key");
      string as   = args["api-secret"]  || query("api_secret");
      string re   = args["redirect-to"] || query("redirect_uri");
      string acct = args["access-token"];
      string accs = args["access-secret"];

      args["api-key"] = "[*SECRET*]";
      args["api-secret"] = "[*SECRET*]";
      args["access-token"] = "[*SECRET*]";
      args["access-secret"] = "[*SECRET*]";

      Social.Api api = api_instance(id);
      Social.Api.Authorization auth;

      if (api)
        RXML.parse_error("<%s></%s> can not be nested!\n", name, name);

      api = register_instance(Klass(ak, as, re, args->permissions), id);
      auth = auth_instance(id);

      if (acct)
        auth->access_token = acct;

      if (acct && accs && auth->set_authentication) {
        auth->set_authentication(acct, accs);
        vars["is-authenticated"] = "1";
      }

      string local_cookie_name = args["cookie-name"] || cookie_name;

      mixed cookie;
      if (!acct && (cookie = id->cookies[local_cookie_name]) && sizeof(cookie))
      {
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

      // code is for OAuth2 oauth_token for OAuth1
      if (id->variables->code || id->variables->oauth_token)
        vars["is-login-callback"] = "1";

      if (id->variables->error) {
        vars["is-error"] = "1";
        vars["error"] = id->variables->error;
        vars["error-message"] = id->variables->error_description;
      }
      else if (id->variables->denied) {
        vars["is-error"] = "1";
        vars["error"] = "access_denied";
        vars["error-message"] = "Access was denied by the user";
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

      string v,
      code = id->variables->code||id->variables->oauth_verifier;

      // OAuth 1
      if (id->variables->oauth_verifier && id->variables->oauth_token) {
        auth->set_authentication(id->variables->oauth_token, 0);
      }

      if (mixed e = catch(v = auth->request_access_token(code))) {
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
      "select" : RXML.t_text(RXML.PEnt),
      "query" : RXML.t_text(RXML.PEnt)
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

      if (!cookie) {
        Social.Api.Authorization auth = auth_instance(id);
        TRACE("## %O\n", auth);

        if (!auth)
          return 0;

        cookie = ([ "access_token" : auth->access_token ]);

        if (!cookie->access_token)
          return 0;
      }

      return make_cache_key(name+plugin_name,
                            args + ([ "__" : cookie->access_token ]));
    }

    array do_request(mapping args, RequestID id)
    {
      return ({});
    }

    array get_dataset(mapping args, RequestID id)
    {
      return do_request(args, id);
    }
  }
}

//! Emit weather forecast
class TagEmitSubscope // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "subscope";

  mapping(string:RXML.Type) req_arg_types = ([
    "variable" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    mixed var = RXML.user_get_var(args->variable);

    if (arrayp(var))
      return var;

    return var && ({ var }) || ({});
  }
} // }}}

class TagTimeToDuration
{
  inherit RXML.Tag;
  constant name = "time-to-duration";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "timestamp" : RXML.t_text(RXML.PEnt),
    "iso-time" : RXML.t_text(RXML.PEnt),
    "hours" : RXML.t_text(RXML.PEnt),
    "timezone" : RXML.t_text(RXML.PEnt)
  ]);


  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      int ts = 0;
      Calendar.Second s;

      mixed err = catch {
        if (args["iso-time"]) {
          s = Calendar.dwim_time(args["iso-time"]);
        }
        else if (args->timestamp) {

        }
        else {
          RXML.parse_error("Missing required argument \"timestamp\" or "
                           "\"iso-time\"");
        }

        if (args->timezone) {
          mixed e = catch {
            s->set_timezone(args->timezone);
          };

          if (e) werror("Timezone error: %s\n", describe_backtrace(e));
        }

        if (args->hours && s) {
          s = s + (s->hour() * args->hours);
        }

        if (s) ts = s->unix_time();

        result = time_elapsed(ts);
      };

      if (err) {
        werror("time-to-duration: %s\n", describe_error(err));
        result = args["iso-time"] || args["timestamp"];
      }

      return 0;
    }
  }
}

//! Human readable representation of @[timestamp].
//!
//! Examples are:
//!       0..30 seconds: Just now
//!      0..120 seconds: Just recently
//!   121..3600 seconds: x minutes ago
//!   ... and so on
//!
//! @param timestamp
protected string time_elapsed(int timestamp)
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
      return sprintf("%d timm%s sedan", t, t > 1 ? "ar" : "e");

    case  86401 .. 604800:
      t = (int)(((diff/60.0)/60.0)/24);
      return sprintf("%d dag%s sedan", t, t > 1 ? "ar" : "");

    case 604801 .. 31449600:
      t = (int)((((diff/60.0)/60.0)/24)/7);
      return sprintf("%d veck%s sedan", t, t > 1 ? "or" : "a");
  }

  return "Länge sedan";
}

protected mixed get_selection(mapping data, string sel)
{
  array p = sel/".";
  int s = sizeof(p);
  if (s > 0)
    data = data[p[0]]||data;

  return data;
}

protected string encode_cookie(string v)
{
  return v && sizeof(v) && MIME.encode_base64(v);
}

protected string decode_cookie(string v)
{
  return v && sizeof(v) && MIME.decode_base64(v);
}

protected mapping get_cookie(RequestID id)
{
  if (string v = decode_cookie(id->cookies[cookie_name])) {
    TRACE("### THE COOKIE: %s\n", v);
    return decode_value(v);
  }

  return 0;
}

protected string make_cache_key(string name, mapping args)
{
  string keys = map(indices(args), lambda (mixed s) {
                                     return (string)s;
                                   })*"";
  string vals = map(values(args), lambda (mixed s) {
                                     return (string)s;
                                   })*"";
  return Social.md5(keys + vals);
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
