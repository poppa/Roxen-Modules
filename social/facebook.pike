/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  Tags for communicating with the Facebook Socail Graph API.
*/

#charset utf-8

#include <config.h>
#include <module.h>
inherit "module";

#define FB_DEBUG

#ifdef FB_DEBUG
# define TRACE(X...) report_debug("FB Roxen (%3d): %s", __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]
/* The Facebook Authorization object */
#define FB  id->misc->facebook
#define FB_AUTH  id->misc->facebook->authorization

#define SET_COOKIE(V) Roxen.set_cookie(id, cookie_name, \
                                       encode_cookie(encode_value(V)), -1, 0, "/")
#define REMOVE_COOKIE() Roxen.remove_cookie(id, cookie_name, "", 0, "/")

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Facebook";
constant module_doc  = "Tagset for Facebook autentication and communication.";

Configuration conf;

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");

  defvar("api_key",
         Variable.String("", 0, "API key", "Default API key"));

  defvar("api_secret",
         Variable.String("", 0, "API secret", "Default API secret"));

  defvar("redirect_uri",
         Variable.String("", 0, "Redirect URI", "Where Facebook should return "
                                                "to after authorization"));

  conf = _conf;
}

constant cookie_name = "fbsession";

void start(int when, Configuration _conf){}

class TagFacebook
{
  inherit RXML.Tag;

  constant name = "facebook";

  mapping(string:RXML.Type) opt_arg_types = ([
    "api-key"     : RXML.t_text(RXML.PEnt),
    "api-secret"  : RXML.t_text(RXML.PEnt),
    "redirect-to" : RXML.t_text(RXML.PEnt),
    "permissions" : RXML.t_text(RXML.PEnt),
  ]);

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagFacebook", ({
      TagFacebookLoginUrl(),
      TagFacebookLogin(),
      TagFacebookLogout(),
      TagFacebookEmitRequest()
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

      if (id->misc->facebook)
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

      FB = RoxenFacebook(ak, as, re, args->permissions);

      mixed cookie;
      if ((cookie = id->cookies[cookie_name]) && sizeof(cookie)) {
        TRACE("::::::::::: %s\n", cookie);
        FB_AUTH->set_from_cookie(decode_cookie(cookie));

        if (FB_AUTH->is_renewable())
          vars["is-renewable"] = "1";

        if (!FB_AUTH->is_expired())
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

      TRACE("%O\n", vars);

      return 0;
    }

    array do_return(RequestID id)
    {
      m_delete(id->misc, "facebook");
      result = content;
      vars = ([]);
      return 0;
    }
  }

  // Login URL
  class TagFacebookLoginUrl
  {
    inherit RXML.Tag;
    constant name = "fb-login-url";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([
      "variable"   : RXML.t_text(RXML.PEnt),
      "cancel" : RXML.t_text(RXML.PEnt)
    ]);

    multiset(string) noargs = (< "variable" >);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
        if (!args->cancel)
          args->cancel = FB_AUTH->get_redirect_uri();

        mapping a = ([]);

        foreach (args; string k; string v)
          if ( !noargs[k] )
            a[k] = v;

        string t = FB_AUTH->get_auth_uri(a);

        TRACE("URL: %s\n", t);

        if (args->variable)
          RXML.user_set_var(args->variable, t);
        else
          result = t;

        _ok = 1;

        return 0;
      }
    }
  }

  class TagFacebookLogin
  {
    inherit RXML.Tag;
    constant name = "fb-login";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
        TRACE("Login code: %O\n", id->variables->code);

        string v;
        if (mixed e = catch(v=FB_AUTH->request_access_token(id->variables->code))) {
          report_error("request_access_token(): %s\n", describe_backtrace(e));
          _ok = 0;
          return 0;
        }

        mapping raw_token = decode_value(v);

        FB_AUTH->set_from_cookie(v);

        mixed e = catch {
          mixed data = FB->get("me");
          TRACE("Login: %O\n", data);
          raw_token += ([
            "uid"       : data->id,
            "firstname" : data->first_name,
            "lastname"  : data->last_name,
            "name"      : data->name,
            "gender"    : data->gender,
            "link"      : data->link,
            "locale"    : data->locale
          ]);
        };

        if (e) {
          report_error("get(\"me\"): %s\n", describe_error(e));
          _ok = 0;
          return 0;
        }

        SET_COOKIE(raw_token);
        TRACE("Data: %O\n", raw_token);

        _ok = 1;

        return 0;
      }
    }
  }

  class TagFacebookLogout
  {
    inherit RXML.Tag;
    constant name = "fb-logout";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
        TRACE("Logout...\n");
        REMOVE_COOKIE();
        _ok = 1;
        return 0;
      }
    }
  }

  //! Emit user info
  class TagFacebookEmitRequest // {{{
  {
    inherit RXML.Tag;
    constant name = "emit";
    constant plugin_name = "fb-request";

    mapping(string:RXML.Type) req_arg_types = ([
      "method" : RXML.t_text(RXML.PEnt),
    ]);

    mapping(string:RXML.Type) opt_arg_types = ([
      "http-method" : RXML.t_text(RXML.PEnt),
      "no-cache" : RXML.t_text(RXML.PEnt),
      "cache" : RXML.t_text(RXML.PEnt),
      "select" : RXML.t_text(RXML.PEnt)
    ]);

    array get_dataset(mapping args, RequestID id)
    {
      mixed out = ({});

      mapping params = ([]);
      array(string) keys = indices(req_arg_types) + indices(opt_arg_types);
      foreach (args; string k; mixed v)
        if (!has_value(keys, k) && k != "source")
          params[k] = v;

      mapping cookie = get_cookie(id);
      if (!cookie) return out;

      string ck = make_cache_key(name+plugin_name,
                                 args + ([ "__" : cookie->uid ]));

      if (!args["no-cache"] && (out = FB->cache->get(ck))) {
        if (args->select && mappingp(out))
          out = get_selection(out, args->select);

        if (!arrayp(out))
          out = ({ out });

        return out;
      }

      mixed res;

      if (mixed e = catch(res = FB->get(args->method, params)))
      {
        report_error("Error: %s\n", describe_backtrace(e));
        return ({});
      }

      TRACE("Result: %O\n", res);

      if (res && sizeof(res))
        FB->cache->set(ck, res, (int)args->cache||600);
      else {
        werror("OOPS! %O\n", FB);
        return ({});
      }

      if (args->select && mappingp(res))
        res = get_selection(res, args->select);

      if (!arrayp(res))
        res = ({ res });

      return res;
    }

    private mixed get_selection(mapping data, string sel)
    {
      array p = sel/".";
      int s = sizeof(p);
      if (s > 0)
        data = data[p[0]]||data;

      return data;
    }
  } // }}}
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
  if (string v = decode_cookie( id->cookies[cookie_name] )) {
    TRACE("### THE COOKIE: %s\n", v);
    return decode_value(v);
  }

  return 0;
}

string make_cache_key(string name, mapping args)
{
  return Social.md5(name + indices(args)*"" + values(args)*"");
}

private mapping(string:object) twcache = ([]);

class RoxenFacebook
{
  inherit Social.Facebook;

  DataCache cache;

  void create(string client_id, string client_secret, void|string redirect_uri,
              void|string|array(string)|multiset(string) scope)
  {
    ::create(client_id, client_secret, redirect_uri, scope);
    cache = DataCache();
  }

  class DataCache
  {
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
}

TAGDOCUMENTATION;
#ifdef manual
#define WURL "http://wiki.developers.facebook.com/index.php/"
#define FBW(S, TITLE) sprintf("<a href='%s%s'>%s</a>",WURL, (S), (TITLE))

constant tagdoc = ([
"facebook" : ({ #"
 <desc type='cont'><p><short>
  For more information of how the Facebook API works check out the " +
  FBW("Main_Page", "Facebook Developer Wiki") + #"
 </short></p>",

 ([ "&_.is-authenticated;" : #"<desc type='entity'><p>
    Is the current user authenticated or not</p></desc>",

    "&_.is-login-callback;" : #"<desc type='entity'><p>
    If the visitor is returning from a Facebook login page this variable has
    the value <tt>1</tt></p></desc>",

    "&_.session_key;" : #"<desc type='entity'><p>
    The value of the current Facebook session.</p></desc>",

    "&_.secret;" : #"<desc type='entity'><p>
    The secret of the current Facebook session.</p></desc>",

    "&_.uid;" : #"<desc type='entity'><p>
    The user ID of the currently Facebook connected user</p></desc>",

    "&_.expires;" : #"<desc type='entity'><p>
    Timestamp of when the current session expires</p></desc>",

    // Login
    "fb-login-url" : ({ #"
    <desc type='tag'><p><short>
     Generates a Facebook login URL</short></p>
     <p><strong>Note:</strong> All parameters that can be given to the
     authorization URL can be given to this tag and they will be appended to
     the generated login URL</p>
     <p>Read more about " +
     FBW("Authorizing_Applications", "Facebook authorization") + #"</p>
    </desc>

    <attr name='next' value='string' optional=''><p>
     URL that the login page at Facebook should redirect to upon a successful
     authentication. If not given the redirection will be to the default URL
     of the Facebook application</p>
    </attr>

    <attr name='canvas' value='0|1' optional=''><p>
     If <tt>1</tt> the authenticated Facebook application will be put in an
     <tt>IFRAME</tt> within Facebook</p>
    </attr>

    <attr name='permissions' value='string' optional=''><p>
     Comma separated list of extended permissions the Facebook application
     should have.See also the "+
     FBW("Extended_permissions", "Facebook developer wiki")+#"</a>
     </p>
    </attr>

    <attr name='variable' value='string' optional=''><p>
     If set this tag will put the result in this RXML-variable</p>
    </attr>"}),

    // Logout
    "fb-logut" : ({ #"
    <desc type='tag'><p><short>
     Destroys the Facebook session</short></p>
     <p>" + FBW("Auth.expireSession", "Auth.expireSession documentation") +
     #"</p>
    </desc>" }),

    // Get logged in user
    "fb-get-logged-in-user" : ({ #"
    <desc type='tag'><p><short>
     Returns the user ID of the currently logged in user</short></p>
     <p>" + FBW("Users.getLoggedInUser", "Users.getLoggedInUser documentation") +
     #"</p>
    </desc>

    <attr name='variable' value='string' optional=''><p>
     If set this tag will put the result in this RXML-variable</p>
    </attr>" }),

    // Set status
    "fb-set-status" : ({ #"
    <desc type='cont'><p><short>
     Sets the user status. Max 255 characters. Longer strings will be
     truncated.</short></p>
     <p>" + FBW("Users.setStatus", "Users.setStatus documentation") +
     #"</p>
    </desc>

    <attr name='text' value='string' optional=''><p>
     Status text (if not set as tag content)</p>
    </attr>

    <attr name='clear' value='string' optional=''><p>
     Clears the user status</p>
    </attr>

    <attr name='uid' value='int' optional=''><p>
     Set status for user with this userID instead of the currently logged in
     user</p>
    </attr>

    <attr name='includes-verb' value='0|1' optional=''><p>
      If set to <tt>1</tt>, the word <b>is</b> will <i>not</i> be prepended to
      the status message</p>
    </attr>" }),

    // Get session
    "fb-get-session" : ({ #"
    <desc type='tag'><p><short>
     Creates a Facebook session</short></p>
     <p>This tag behaves differently depending on the parameters sent to the
     Facebook login page, but the result is always the same.</p>
     <p>" + FBW("Auth.getSession", "Auth.getSession documentation") +
     #", " + FBW("Auth.createToken", "Auth.createToken documentation") + #"</p>
    </desc>

    <attr name='generate-session-secret' value='0|1' optional=''><p>
     Generates a session secret. Only applicable if <tt>fbconnect</tt> and
     <tt>return_session</tt> was not used in the parameters to the Facebook
     login page</p>
    </attr>" }),

    // Emit user info
    "emit#fb-user-info" : ({ #"
    <desc type='plugin'><p><short>
     Lists information about one or more Facebook users</short></p>
     <p>" + FBW("Users.getInfo", "Users.getInfo documentation") + #"</p>
    </desc>

    <attr name='uids' value='uid[,uid,...]' optional=''><p>
     Comma separated list of users to fetch info about. If not given the current
     user's info will be fetched.</p>
    </attr>

    <attr name='fields' value='string[,string,...]' optional=''><p>
     List of info fields to fetch</p>
    </attr>" }),
 ])
})
]);
#endif /* ifdef manual */