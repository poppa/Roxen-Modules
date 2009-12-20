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
  set_module_creator("Pontus Östlund <pontus@poppa.se>");

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
      TagEmitTwitterCall(),
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

      Social.OAuth.Consumer consumer;
      Social.OAuth.Token token;

      string ck = args["consumer-key"]    || query("consumer_key");
      string cs = args["consumer-secret"] || query("consumer_secret");

      consumer = Social.OAuth.Consumer(ck, cs);

      mixed cookie;
      if ( cookie = id->cookies[auth_cookie] ) {
	[string k, string s] = cookie/"\0";
	token = Social.OAuth.Token(k, s);
	vars["access-token-key"] = k;
	vars["access-token-secret"] = s;
	vars["is-authenticated"] = 1;
      }

      id->misc->twitter = RoxenTwitter(consumer, token);

      string tkey, tsec;
      if (token) {
	TRACE("+++ Access token set\n");
	id->misc->twitter->set_token(token);
      }
      else if ((tkey = TWITTER->get_cache("request-token-key")) &&
	       (tsec = TWITTER->get_cache("request-token-secret")))
      {
	TRACE("+++ Request token set\n");
	vars["request-token-key"]    = tkey;
	vars["request-token-secret"] = tsec;
	TWITTER->set_token(tkey, tsec);
      }

      return 0;
    }

    array do_return(RequestID id)
    {
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

	DEL_CACHE("request-token-key");
	DEL_CACHE("request-token-secret");
	DEL_CACHE("access-token-key");
	DEL_CACHE("access-token-secret");

	Roxen.remove_cookie(id, auth_cookie, id->cookies[auth_cookie]||"" );

	string t;
	if (mixed e = catch(t = TWITTER->get_auth_url())) {
	  report_error("Request error: %s\n", describe_error(e));
	  _ok = 0;
	}
	else {
	  Social.OAuth.Token tok = TWITTER->get_token();
	  SET_CACHE("request-token-key",    tok->key);
	  SET_CACHE("request-token-secret", tok->secret);
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
	Social.OAuth.Token t;
	if (mixed e = catch(t = TWITTER->get_access_token())) {
	  TRACE("Request error: %s\n", describe_backtrace(e));
	  _ok = 0;
	}
	else {
	  Social.OAuth.Token tok = TWITTER->get_token();
	  SET_CACHE("access-token-key",     t->key);
	  SET_CACHE("access-token-secret",  t->secret);
	  Roxen.set_cookie(id, auth_cookie, t->key+"\0"+t->secret);
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
	DEL_CACHE("request-token-key");
	DEL_CACHE("request-token-secret");
	DEL_CACHE("access-token-key");
	DEL_CACHE("access-token-secret");
	Roxen.remove_cookie(id, auth_cookie, id->cookies[auth_cookie]||"" );
	return 0;
      }
    }
  }

  class TagEmitTwitterCall
  {
    inherit RXML.Tag;
    constant name = "emit";
    constant plugin_name = "twitter-call";

    mapping(string:RXML.Type) req_arg_types = ([
      "url" : RXML.t_text(RXML.PEnt)
    ]);

    mapping(string:RXML.Type) opt_arg_types = ([
      "method"  : RXML.t_text(RXML.PEnt),
      "nocache" : RXML.t_text(RXML.PEnt),
      "cache"   : RXML.t_text(RXML.PEnt),
      "debug"   : RXML.t_text(RXML.PEnt)
    ]);

    array get_dataset(mapping args, RequestID id)
    {
      array  ret   = ({});
      string method  = "GET";
      int    cache   = args->cache && (int)args->cache;

      if (args->nocache) cache = -1;

      if (args->method) {
	if ( !(< "GET", "POST" >)[upper_case(args->method)] ) {
	  RXML.parse_error("Bad value to \"method\". Must be \"GET\" or "
	                   "\"POST\"");
	}
	if (upper_case(args->method) == "POST")
	  method = "POST";
      }

      multiset skip = (< "source" >);
      skip += (multiset)(indices(req_arg_types)+indices(opt_arg_types));

      Social.OAuth.Params params = Social.OAuth.Params();

      foreach (args; string key; mixed o)
	if ( !skip[key] )
	  params += Social.OAuth.Param(key, (string)o);

      mixed res;
      if (mixed e = catch(res = TWITTER->call(args->url,params,method,cache)))
	RXML.parse_error("call() error: %s\n", describe_error(e));

      if (args->debug)
	report_debug("Result is: %O\n", res);

      if (res[0..4] == "<?xml") {
	Social.Twitter.Response resp = TWITTER->Response(res);
	string fk = indices(resp)[0];
	ret = ({ resp[fk] });
      }

      return ret;
    }
  }
}

private mapping(string:object) twcache = ([]);

class RoxenTwitter
{
  inherit Social.Twitter;

  void create(Social.OAuth.Consumer consumer, Social.OAuth.Token token)
  {
    ::create(consumer, token);
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
