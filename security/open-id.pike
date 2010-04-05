/* -*- Mode: Pike; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
//! @b{open-id.pike@}
//!
//! Copyright © 2010, Pontus Östlund - @url{http://www.poppa.se@}
//!
//! @pre{@b{License GNU GPL version 3@}
//!
//! open-id.pike is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! open-id.pike is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with open-id.pike. If not, see <@url{http://www.gnu.org/licenses/@}>.
//! @}

#include <module.h>
inherit "module";
inherit "roxenlib";

import Security.OpenID;

#define OPENID_DEBUG

#define _ok RXML_CONTEXT->misc[" _ok"]

#ifdef OPENID_DEBUG
# define TRACE(X...) \
  report_debug("%s:%d: %s", basename(__FILE__), __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Open ID";
constant module_doc  = "To be provided";

Configuration conf;

string auth_cookie_name = "RoxenOpenID";

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");
  conf = _conf;
} // }}}

void start(int when, Configuration _conf) // {{{
{
  TRACE("Starting...\n");
} // }}}

class TagEmitOpenIdProviders // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "openid-providers";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([]);

  array get_dataset(mapping args, RequestID id)
  {
    mapping(string:Provider) p = get_providers();
    array(mapping) out = ({});
    
    foreach (p; string op; Provider prov) {
      out += ({([
	"operator" : op,
	"name"     : prov->get_name(),
	"url"      : prov->get_url(),
	"alias"    : prov->get_alias()
      ])});
    }

    return out;
  }
} // }}}

#define REDIRECT(TO) do                                                        \
  {                                                                            \
    mapping r = Roxen.http_redirect((TO), id);                                 \
    if (r->error) RXML_CONTEXT->set_misc (" _error", r->error);                \
    if (r->extra_heads) RXML_CONTEXT->extend_scope ("header", r->extra_heads); \
  } while (0)
/* REDIRECT */

#define SET_COOKIE(VALUE) \
  Roxen.set_cookie(id, auth_cookie_name, encode_value((VALUE)))

#define GET_COOKIE() \
  id->cookies[auth_cookie_name] && decode_value( id->cookies[auth_cookie_name] )

class TagOpenIdLoginUrl // {{{
{
  inherit RXML.Tag;
  constant name = "openid-login-url";

  mapping(string:RXML.Type) req_arg_types = ([
    "operator" : RXML.t_text(RXML.PXml)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "return-to" : RXML.t_text(RXML.PXml),
    "var" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      [string uri, string realm] = self_and_realm(args, id);

      mixed e = catch {
	Manager manager = Manager();
	manager->set_return_to(uri);
	manager->set_realm(realm);

	mapping cookie = ([]);

	string op = cookie->op = args->operator;
	Endpoint ep = manager->get_endpoint(op);
	Association as = manager->get_association(ep);

	if (string op_url = manager->get_login_url(ep, as)) {
	  _ok = 1;
	  cookie->association = as->encode_cookie();
	  SET_COOKIE(cookie);
	  REDIRECT(op_url);
	}
	else
	  _ok = 0;
      };

      if (e) {
      	_ok = 0;
      	TRACE("Error: %s\n", describe_backtrace(e));
      	RXML.user_set_var("var.openid-error", describe_error(e));
      }

      return 0;
    }
  }
} // }}}

class TagOpenIdVerifyResponse // {{{
{
  inherit RXML.Tag;
  constant name = "openid-verify-response";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "return-to" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      mapping cookie = GET_COOKIE();
      if (!cookie || !cookie->op || !cookie->association) {
      	_ok = 0;
      	return 0;
      }

      [string uri, string realm] = self_and_realm(args, id);

      mixed e = catch {
	Manager manager = Manager();
	manager->set_return_to(uri);
	manager->set_realm(realm);

	Endpoint ep = manager->get_endpoint(cookie->op);
	Association assoc = Association()->decode_cookie(cookie->association);
	Authentication auth = manager->parse_auth_response(id->variables, assoc);
	cookie->authentication = auth->encode_cookie();
	SET_COOKIE(cookie);
	_ok = 1;
      };

      if (e) {
      	_ok = 0;
      	TRACE("Error: %s\n", describe_backtrace(e));
      	RXML.user_set_var("var.opeind-error", describe_error(e));
      }

      return 0;
    }
  }
} // }}}

class TagOpenIdLogOut // {{{
{
  inherit RXML.Tag;
  constant name = "openid-logout";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      Roxen.remove_cookie(id, auth_cookie_name, "");
      return 0;
    }
  }
} // }}}

class TagEmitOpenId // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "openid";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([]);

  array get_dataset(mapping args, RequestID id)
  {
    mapping cookie = GET_COOKIE();
    if (!cookie || !cookie->authentication)
      return ({});

    return ({ 
      (mapping)Authentication()->decode_cookie(cookie->authentication) 
    });
  }
} // }}}

class TagIfOpenId // {{{
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "openid";

  mapping(string:RXML.Type) opt_arg_types = ([
    "authenticated" : RXML.t_text(RXML.PXml),
    "op-callback"   : RXML.t_text(RXML.PXml),
  ]);

  int eval(string a, RequestID id, mapping args)
  {
    if (args->authenticated)
      return !!(GET_COOKIE() && GET_COOKIE()->authentication);

    if ( args["op-callback"] )
      return !!id->variables["openid.response_nonce"];

    return 1;
  }
} // }}}

array self_and_realm(mapping args, RequestID id)
{
  string self = sprintf("%s://%s:%d/%s",
			id->port_obj->prot_name,
			id->misc->host,
			id->misc->port,
			id->misc->localpath);

  if ( args["return-to"] )
    self = args["return-to"];

  Standards.URI uri = Standards.URI(self);
  string realm;
  if (args->realm)
    realm = args->realm;
  else {
    realm = sprintf("%s://%s", uri->scheme, uri->host);
    if ( !(< 80,443 >)[uri->port] )
      realm += ":" + uri->port;
  }

  return ({ (string)uri, realm });
}

