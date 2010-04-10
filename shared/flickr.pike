/* -*- Mode: Pike; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
//! @b{[PROG-NAME]@}
//!
//! Copyright © 2010, Pontus Östlund - @url{http://www.poppa.se@}
//!
//! @pre{@b{License GNU GPL version 3@}
//!
//! [PROG-NAME].pike is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! [PROG-NAME].pike is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with [PROG-NAME].pike. If not, see <@url{http://www.gnu.org/licenses/@}>.
//! @}

#include <config.h>
#include <module.h>
inherit "module";
import Social.Flickr;

#define FLICKR_DEBUG

#define _ok RXML_CONTEXT->misc[" _ok"]
#define FLICKR id->misc->flickr
#define GET_COOKIE() \
  id->cookies[cookie_name] && decode_value( id->cookies[cookie_name] )
#define SET_COOKIE(V) \
  Roxen.set_cookie(id, cookie_name, encode_value((V)), -1)

#ifdef FLICKR_DEBUG
# define TRACE(X...) report_debug("Flickr:%d: %s", __LINE__, sprintf(X))
#else
# define TRACE(X...)
#endif

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Flickr";
constant module_doc  = "Flickr tags";

Configuration conf;

void create(Configuration _conf)
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");
  conf = _conf;

  defvar("api_key", Variable.String(
    "", 0, "API key",
    "Default API key"
  ));

  defvar("api_secret", Variable.String(
    "", 0, "API secret",
    "Default API secret"
  ));

  //72157608097764855-ad8204bd8c4eee43
}

void start(int when, Configuration _conf)
{
}

#define FILTER_ARGS(allowed) do                                                \
  {                                                                            \
    foreach (indices(args), string k)                                          \
      if (!has_value(allowed, k) || !sizeof( args[k] ))                        \
	m_delete(args, k);                                                     \
  } while (0)

#define CACHE_KEY Social.md5(name + (indices(args)*"") + (values(args)*"") +   \
                             FLICKR->get_identifer())

#define REDIRECT(TO) do                                                        \
  {                                                                            \
    mapping r = Roxen.http_redirect((TO), id);                                 \
    if (r->error) RXML_CONTEXT->set_misc (" _error", r->error);                \
    if (r->extra_heads) RXML_CONTEXT->extend_scope ("header", r->extra_heads); \
  } while (0)
/* REDIRECT */

class FlickrCache
{
  string key;
  string xml;
  int ttl;
  int created;

  void create(string _key, string _xml, int _ttl)
  {
    key = _key;
    xml = _xml;
    created = time();
    ttl = created + _ttl;
  }

  int(0..1) expired()
  {
    return time() > ttl;
  }
}

mapping(string:FlickrCache) query_cache = ([]);

FlickrCache get_cache(string key)
{
  FlickrCache c = query_cache[key];
  if (!c) return 0;
  if (c->expired()) {
    m_delete(query_cache, key);
    return 0;
  }
  
  return c;
}

void add_cache(string key, string xml, int ttl)
{
  query_cache[key] = FlickrCache(key, xml, ttl);
}

class TagFlickr
{
  inherit RXML.Tag;

  constant name = "flickr";
  constant cookie_name = "RoxenFlickr";

  mapping(string:RXML.Type) opt_arg_types = ([
    "api-key"    : RXML.t_text(RXML.PEnt),
    "api-secret" : RXML.t_text(RXML.PEnt),
    "token"      : RXML.t_text(RXML.PEnt),
    "require-authentication" : RXML.t_text(RXML.PEnt),
  ]);

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagFlickr", ({
      TagFlickrMethod(),
      TagFlickrLogout(),
      TagFlickrClearCache()
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
      if (id->misc->flickr)
	RXML.parse_error("<%s></%[0]s> can not be nested!\n", name);

      vars = ([
	"is-authenticated"  : 0,
	"is-login-callback" : 0,
	"token"             : 0,
	"username"          : 0,
	"fullname"          : 0,
	"user-id"           : 0,
	"login-url"         : 0
      ]);

      mapping cookie = GET_COOKIE()||([]);

      if (cookie)
      	vars += cookie;

      string ak = args["api-key"]    || query("api_key");
      string as = args["api-secret"] || query("api_secret");
      string tk = args["token"]      || cookie->token;

      FLICKR = RoxenFlickr(ak, as, tk);

      if ( args["require-authentication"] ) {
	if (tk) {
	  TRACE("Token exists...perhaps check for validity...\n");
	  vars["is-authenticated"] = 1;
	}
	else {
	  if (id->variables->frob) {
	    mixed e = catch {
	      FLICKR->request_token(id->variables->frob);
	      tk = FLICKR->get_token();
	      mapping user = (mapping)FLICKR->get_user();
	      user->token = tk;

	      if (!user->fullname || !sizeof(user->fullname))
	      	user->fullname = user->username;

	      SET_COOKIE(user);
	      REDIRECT("/" + id->misc->localpath);
	    };

	    if (e) {
	      RXML.parse_error("Authentication failed: %s\n",
	                       describe_error(e));
	    }
	  }
	  else {
	    string perm = sizeof( args["require-authentication"] ) &&
	                  args["require-authentication"];
	    vars["login-url"] = FLICKR->get_auth_url(perm);
	  }
	}
      }
      return 0;
    }

    array do_return(RequestID id)
    {
      m_delete(id->misc, "flickr");
      result = content;
      vars = ([]);
      return 0;
    }
  }

  class TagFlickrLogout // {{{
  {
    inherit RXML.Tag;
    constant name = "flickr-logout";
  
    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([]);
  
    class Frame
    {
      inherit RXML.Frame;
  
      array do_return(RequestID id)
      {
	Roxen.remove_cookie(id, cookie_name, "");
	return 0;
      }
    }
  } // }}}
  
  class TagFlickrClearCache // {{{
  {
    inherit RXML.Tag;
    constant name = "flickr-clear-cache";
  
    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([]);
  
    class Frame
    {
      inherit RXML.Frame;
  
      array do_return(RequestID id)
      {
	query_cache = ([]);
	return 0;
      }
    }
  } // }}}
  
  class TagFlickrMethod
  {
    inherit RXML.Tag;
    constant name = "flickr-method";

    mapping(string:RXML.Type) req_arg_types = ([
      "name" : RXML.t_text(RXML.PEnt)
    ]);
    
    mapping(string:RXML.Type) opt_arg_types = ([
      "variable" : RXML.t_text(RXML.PEnt),
      "throw-error" : RXML.t_text(RXML.PEnt),
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
      	string method = args->name;
      	string var = args->variable;
      	string terr = args["throw-error"];
	m_delete(args, "name");
	m_delete(args, "variable");
	m_delete(args, "throw-error");

	int(0..1) throw_error = !terr || terr == "1" || terr == "true";
	string ck = CACHE_KEY;

	FlickrCache c = get_cache(ck);
	string xml = c && c->xml;
	if (!xml) {
	  int(0..1) no_cache = 0;
	  if (mixed e = catch(xml = FLICKR->call_xml(method, args, !throw_error))) {
	    if (throw_error)
	      RXML.parse_error("Flickr error: %s\n", describe_error(e));
	    no_cache = 1;
	  }

	  Response rsp = Response(xml);
	  if (rsp && ((mapping)rsp)->stat != "ok")
	    no_cache = 1;

	  // Don't cache errors
	  if (!no_cache) {
	    string nxml;
	    catch (nxml = utf8_to_string(xml));
	    xml = nxml||xml;
	    add_cache(ck, xml, (int)(args->cache||600));
	  }
	}

	if (var)
	  RXML.user_set_var(var, xml);
	else
	  result = xml;

	_ok = 1;

	return 0;
      }
    }
  }

  void filter_args(mapping given, mapping unwanted)
  {
    unwanted->source = "1";
    foreach (indices(unwanted), string k)
      m_delete(given, k);
  }
}

class RoxenFlickr
{
  inherit Social.Flickr.Api;
  
}
