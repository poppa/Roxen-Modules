/* -*- Mode: Pike; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
//! @b{Facebook Roxen Tags@}
//!
//! NOTE: This module relies on Facebook.pmod which can be found in
//! Social.pmod at @url{http://github.com/poppa/Pike-Modules@}.
//!
//! Copyright © 2009, Pontus Östlund - @url{http://www.poppa.se@}
//!
//! @pre{@b{License GNU GPL version 3@}
//!
//! facebook.pike is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! facebook.pike is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with facebook.pike. If not, see <@url{http://www.gnu.org/licenses/@}>.
//! @}

#include <config.h>
#include <module.h>
inherit "module";

import Social.Facebook;

#define FB_DEBUG

#ifdef FB_DEBUG
# define TRACE(X...) report_debug("FB Roxen (%3d): %s", __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]
/* The Facebook object */
#define FB  id->misc->facebook

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Facebook";
constant module_doc  = "Tagset for Facebook autentication and communication.";

Configuration conf;

void create(Configuration _conf)
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");

  defvar("api_key",
         Variable.String("", 0, "API key", "Default API key"));

  defvar("api_secret",
         Variable.String("", 0, "API secret", "Default API secret"));

  conf = _conf;
}

void start(int when, Configuration _conf){}

class TagFacebook
{
  inherit RXML.Tag;

  constant name = "facebook";
  constant cookie_name = "fbsession";

  mapping(string:RXML.Type) opt_arg_types = ([
    "api-key"    : RXML.t_text(RXML.PEnt),
    "api-secret" : RXML.t_text(RXML.PEnt)
  ]);

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagFacebook", ({
      TagFacebookLoginUrl(),
      TagFacebookGetSession(),
      TagFacebookLogout(),
      TagFacebookEmitUserInfo(),
      TagFacebookSetStatus(),
      TagFacebookGetLoggedInUser()
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
      if (id->misc->facebook)
	RXML.parse_error("<%s></%s> can not be nested!\n", name, name);

      vars = ([
	"is-authenticated"  : 0,
	"is-login-callback" : 0,
	"session_key"       : 0,
	"uid"               : 0,
	"expires"           : 0,
	"secret"            : 0
      ]);

      string ak = args["api-key"]    || query("api_key");
      string as = args["api-secret"] || query("api_secret");

      FB = RoxenFacebook(ak, as);

      mixed cookie;
      if ( cookie = id->cookies[cookie_name] ) {
	mapping v = decode_cookie( id->cookies[cookie_name] );
	FB->set_session_values(v);

	if (!v->uid || v->uid == "0") {
	  Response r = FB->get_logged_in_user();
	  string uid = r && (string)r;

	  if (uid != "0") {
	    v->uid = uid;
	    FB->set_uid(uid);
	    Roxen.set_cookie(id, cookie_name, encode_cookie(v));
	  }
	}

	vars["is-authenticated"] = 1;
	vars += v;
      }

      if (id->variables["auth_token"] || id->variables->session)
	vars["is-login-callback"] = 1;

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
      "next"        : RXML.t_text(RXML.PEnt),
      "canvas"      : RXML.t_text(RXML.PEnt),
      "variable"    : RXML.t_text(RXML.PEnt),
      "permissions" : RXML.t_text(RXML.PEnt)
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
      	Params ep = Params();
      	ep += Param("return_session", "true");

      	if ( args["next"] )
      	  ep += Param("next", args["next"] );

      	if (args->canvas)
      	  ep += Param("canvas", 1);

      	if (args->permissions)
      	  ep += Param("req_perms", args->permissions);

      	foreach (indices(args), string ak) {
      	  if ( opt_arg_types[ak] )
      	    continue;
      	  ep += Param( ak, args[ak] );
      	}

	string t = FB->get_login_url(ep);

	if (args->variable)
	  RXML.user_set_var(args->variable, t);
	else
	  result = t;

	_ok = 1;

	return 0;
      }
    }
  }

  // Logout, expire session
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
	if (mixed e = catch(FB->expire_session()))
	  report_error("Error in expire_session(): %s", describe_error(e));

	Roxen.remove_cookie(id, cookie_name, id->cookies[cookie_name]||"" );
	return 0;
      }
    }
  }

  // Logged in user
  class TagFacebookGetLoggedInUser
  {
    inherit RXML.Tag;
    constant name = "fb-get-logged-in-user";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([
      "variable" : RXML.t_text(RXML.PEnt),
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
      	Response r;
	if (mixed e = catch(r = FB->get_logged_in_user())) {
	  TRACE("Error in expire_session(): %s", describe_error(e));
	  _ok = 0;
	  return 0;
	}

	if (args->variable)
	  RXML.user_set_var(args->variable, (string)r);
	else
	  result = (string)r;

	_ok = 1;

	return 0;
      }
    }
  }

  // Set Facebook status
  class TagFacebookSetStatus
  {
    inherit RXML.Tag;
    constant name = "fb-set-status";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([
      "text"          : RXML.t_text(RXML.PEnt),
      "clear"         : RXML.t_text(RXML.PEnt),
      "uid"           : RXML.t_text(RXML.PEnt),
      "includes-verb" : RXML.t_text(RXML.PEnt)
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
	string msg = args->text || content;
	if ((!msg || !sizeof(msg)) && !args->clear) {
	  _ok = 0;
	  return 0;
	}

	if (args->clear) msg = 0;

	_ok = 1;

	Social.Facebook.Response r;
	if (mixed e = catch(r = FB->set_status(msg, args["includes-verb"],
	                                       args->uid)))
	{
	  TRACE("Failed setting status: %s\n", describe_backtrace(e));
	  _ok = 0;
	  return 0;
	}

	mapping resp = response_to_mapping(r, ([]));

	if (resp->error_code) {
	  _ok = 0;
	  RXML.user_set_var("var.fb-error", resp->error_msg);
	}

	return 0;
      }
    }
  }

  // Generate a session
  class TagFacebookGetSession
  {
    inherit RXML.Tag;
    constant name = "fb-get-session";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([
      "generate-session-secret" : RXML.t_text(RXML.PEnt)
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
      	TRACE("%O\n", id->variables);

	if (!id->variables->auth_token && !id->variables->session)
	  RXML.parse_error("Missing \"auth_token\" query variable!");

	mapping m = ([]);
	if (id->variables->session) {
	  m = FB->simple_parse_json(id->variables->session);
	  if (m && m->session_key) {
	    FB->set_session_values(m);
	    _ok = 1;
	  }
	}
	else {
	  string tok = id->variables->auth_token;
	  string sec = args["generate-session-secret"];
	  Social.Facebook.Response t;
	  if (mixed e = catch(t = FB->auth_get_session(tok, sec))) {
	    TRACE("Request error: %s\n", describe_error(e));
	    _ok = 0;
	  }
	  else {
	    _ok = 1;
	    response_to_mapping(t, m);
	  }
	}

	if (sizeof(m))
	  Roxen.set_cookie(id, cookie_name, encode_cookie(m));

	return 0;
      }
    }
  }

  //! Emit user info
  class TagFacebookEmitUserInfo // {{{
  {
    inherit RXML.Tag;
    constant name = "emit";
    constant plugin_name = "fb-user-info";

    mapping(string:RXML.Type) req_arg_types = ([]);

    mapping(string:RXML.Type) opt_arg_types = ([
      "uids" : RXML.t_text(RXML.PEnt),
      "fields" : RXML.t_text(RXML.PEnt)
    ]);

    array get_dataset(mapping args, RequestID id)
    {
      string ck = make_cache_key(name, args + ([ "__" : FB->get_uid() ]));
      array out = ({});

      if (array _a = FB->cache->get(ck))
	return _a;

      Social.Facebook.Response r;
      if (mixed e = catch(r = FB->get_user_info(args->uids, args->fields))) {
	TRACE("Error getting user info: %s\n", describe_backtrace(e));
	return ({});
      }

      array|object users = r && r->user || ({});
      if (arrayp(users)) {
	foreach (users, Social.Facebook.Response user) {
	  mapping m = ([]);
	  response_to_mapping(user, m);
	  out += ({ m });
	}
      }
      else {
	mapping m = ([]);
	response_to_mapping(users, m);
	out = ({ m });
      }

      if (out && sizeof(out))
	FB->cache->set(ck, out, 600);

      return out;
    }
  } // }}}
}

string encode_cookie(mapping v)
{
  return MIME.encode_base64(encode_value(v));
}

mapping decode_cookie(string v)
{
  return decode_value(MIME.decode_base64(v));
}

mapping response_to_mapping(Social.Facebook.Response o, mapping m)
{
  foreach ((array)o, Social.Facebook.Response child) {
    string n = child->get_name();
    if (sizeof(child)) {
      if ( m[n] )  {
      	if (!arrayp( m[n] ))
      	  m[n] = ({ m[n] });

      	m[n] += ({ response_to_mapping(child, ([])) });
      }
      else {
	m[n] = ([]);
	response_to_mapping(child, m[n]);
      }
    }
    else {
      m[n] = child->get_value();
    }
  }
  
  return m;
}

string make_cache_key(string name, mapping args)
{
  return Social.md5(name + indices(args)*"" + values(args)*"");
}

private mapping(string:object) twcache = ([]);

class RoxenFacebook
{
  inherit Social.Facebook.Api;

  DataCache cache;

  void create(string api_key, string api_secret)
  {
    ::create(api_key, api_secret);
    cache = DataCache();
  }

  class DataCache
  {
    mixed get(string key)
    {
      if ( Item i = twcache[key] ) {
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
