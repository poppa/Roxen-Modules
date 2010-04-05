/* -*- Mode: Pike; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
//! @b{Twitter Roxen Tags@}
//!
//! NOTE: The file relies on Twitter.pike and OAuth.pmod which can be found in 
//! Social.pmod at @url{http://github.com/poppa/Pike-Modules/tree/master@}.
//!
//! Copyright © 2009, Pontus Östlund - @url{www.poppa.se@}
//!
//! @pre{@b{License GNU GPL version 3@}
//!
//! twitter.pike is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! twitter.pike is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with twitter.pike. If not, see <@url{http://www.gnu.org/licenses/@}>.
//! @}

#include <config.h>
#include <module.h>
inherit "module";

//#define TWITTER_DEBUG

#define _ok RXML_CONTEXT->misc[" _ok"]

#ifdef TWITTER_DEBUG
# define TRACE(X...) report_debug(X)
#else
# define TRACE(X...)
#endif

#define TWITTER                   id->misc->twitter
#define SET_CACHE(KEY,VAL,EXP...) TWITTER->set_cache((KEY),(VAL),EXP)
#define GET_CACHE(KEY)            TWITTER->get_cache((KEY))
#define DEL_CACHE(KEY)            TWITTER->delete_cache((KEY))

#define SET_COOKIE() Roxen.set_cookie(id, "RoxenTwitter", encode_value(cookie))
#define DEL_COOKIE() { cookie = ([]); Roxen.set_cookie(id, "RoxenTwitter", ""); }
#define GET_COOKIE() id->cookies["RoxenTwitter"] && \
                     decode_value( id->cookies["RoxenTwitter"] )

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Twitter";
constant module_doc  = "Tagset for communicating with Twitter";

// Name of the cookie where we store the access token
constant auth_cookie = "twitter_auth";
constant sess_cookie = "twitter_sess";
Configuration conf;

void create(Configuration _conf)
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");

  defvar("consumer_key",
         Variable.String("", 0, "Consumer key", "Default cosumer key"));

  defvar("consumer_secret",
         Variable.String("", 0, "Consumer secret", "Default cosumer secret"));

  conf = _conf;
}

void start(int when, Configuration _conf){}

class TagTwitter
{
  inherit RXML.Tag;

  constant name = "twitter";
  mapping cookie = ([]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "cosumer-key"     : RXML.t_text(RXML.PEnt),
    "consumer-secret" : RXML.t_text(RXML.PEnt),
    "token-key"       : RXML.t_text(RXML.PEnt),
    "token-secret"    : RXML.t_text(RXML.PEnt)
  ]);

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagTwitter", ({
      TagTwitterGetAccessToken(),
      TagTwitterGetAuthURL(),
      TagEmitTwitterVerifyCredentials(),
      TagTwitterLogout()
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
      if (id->misc->twitter)
	RXML.parse_error("<%s></%s> can not be nested!\n", name, name);

      vars["is-authenticated"] = 0;

      Security.OAuth.Consumer consumer;
      Security.OAuth.Token token;

      string ck = args["consumer-key"]    || query("consumer_key");
      string cs = args["consumer-secret"] || query("consumer_secret");

      consumer = Security.OAuth.Consumer(ck, cs);
      token = Security.OAuth.Token(0, 0);
      TWITTER = RoxenTwitter(consumer, token);
      cookie = GET_COOKIE()||([]);

      if (cookie->request_key && !cookie->access_key) {
      	token = Security.OAuth.Token(cookie->request_key, cookie->request_secret);
      	TWITTER->set_token(token);
      	vars["request-token-key"]    = token->key;
	vars["request-token-secret"] = token->secret;
      }
      else if (cookie->request_key && cookie->access_key) {
      	token = Security.OAuth.Token(cookie->access_key, cookie->access_secret);
      	TWITTER->set_token(token);
      	TWITTER->set_is_authenticated(1);
      	vars["access-token-key"] = token->key;
      	vars["access-token-secret"] = token->secret;
      	vars["is-authenticated"] = 1;
      }

      return 0;
    }

    array do_return(RequestID id)
    {
      SET_COOKIE();
      m_delete(id->misc, "twitter");
      result = content;
      vars = ([]);
      return 0;
    }
  }

  class TagTwitterGetAuthURL
  {
    inherit RXML.Tag;
    constant name = "twitter-get-auth-url";

    mapping(string:RXML.Type) req_arg_types = ([
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
	TRACE("Request auth url\n");
	DEL_COOKIE();

	string t;
	if (mixed e = catch(t = TWITTER->get_auth_url())) {
	  report_error("Request error: %s\n", describe_error(e));
	  _ok = 0;
	}
	else {
	  Security.OAuth.Token tok = TWITTER->get_token();
	  cookie->request_key = tok->key;
	  cookie->request_secret = tok->secret;
	  SET_COOKIE();
	  _ok    = 1;
	  result = t;
	}
	return 0;
      }
    }
  }

  class TagTwitterGetAccessToken
  {
    inherit RXML.Tag;
    constant name = "twitter-get-access-token";

    mapping(string:RXML.Type) req_arg_types = ([
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
	TRACE("Get access token\n");
	Security.OAuth.Token t;
	cookie = GET_COOKIE();
	
	if (!cookie)
	  RXML.parse_error("No cookie! Serious error man!\n");
	
	if (mixed e = catch(t = TWITTER->get_access_token())) {
	  TRACE("Request error: %s\n", describe_backtrace(e));
	  _ok = 0;
	}
	else {
	  Security.OAuth.Token tok = TWITTER->get_token();
	  cookie->access_key = tok->key;
	  cookie->access_secret = tok->secret;
	  _ok = 1;
	}

	return 0;
      }
    }
  }
  
  class TagTwitterLogout
  {
    inherit RXML.Tag;
    constant name = "twitter-logout";

    mapping(string:RXML.Type) req_arg_types = ([
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
	TRACE("Logout\n");
	DEL_COOKIE();
	return 0;
      }
    }
  }

  class TagEmitTwitterVerifyCredentials
  {
    inherit RXML.Tag;
    constant name = "emit";
    constant plugin_name = "twitter-verify-credentials";

    mapping(string:RXML.Type) req_arg_types = ([]);
    mapping(string:RXML.Type) opt_arg_types = ([]);

    array get_dataset(mapping args, RequestID id)
    {
      Social.Twitter.User u;
      if (mixed e = catch(u = TWITTER->verify_credentials())) {
      	RXML.parse_error("Error: %s\n", describe_error(e));
      }

      return ({ (mapping)u });
    }
  }
}

private mapping(string:object) twcache = ([]);

class RoxenTwitter
{
  inherit Social.Twitter.Api;

  DataCache cache;

  void create(Security.OAuth.Consumer consumer, Security.OAuth.Token token)
  {
    ::create(consumer, token);
    cache = DataCache();
  }

  mixed get_cache(string key)
  {
    return cache->get(key);
  }
  
  void set_cache(string key, mixed val, int|void expires)
  {
    cache->set(key, val, expires);
  }
  
  void delete_cache(string key)
  {
    cache->delete(key);
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
