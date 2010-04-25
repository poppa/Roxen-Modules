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

#define LOCALE(X,Y)    \
  ([string](mixed)Locale.translate("roxen_config",roxenp()->locale->get(),X,Y))

#define OPENID_DEBUG

#include <module.h>
inherit "module";
inherit "roxenlib";

import Security.OpenID;

#define _ok RXML_CONTEXT->misc[" _ok"]

#ifdef OPENID_DEBUG
# define TRACE(X...) report_debug("### OpenID:%d: %s", __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe = 1;
constant module_type = MODULE_TAG|MODULE_FIRST;
constant module_name = "Poppa Tags: Open ID";
constant module_doc  = "To be provided";

string                         db_name;
mapping                        ac_users;
CookieAuth                     cookie_auth;
Configuration                  conf;
typedef mapping(string:string) SqlRow;
typedef array(SqlRow)          SqlResult;
string auth_cookie_name = "RoxenOpenIDauth";

class VariableUserList // {{{
{
  inherit Variable.Mapping;
  constant type = "VariableUserList";

  string key_title = "Username";
  string val_title = "Password";
  int width = 30;

  array(string) render_row(string prefix, mixed val, int width)
  {
    return ({
      Variable.input(prefix + "a", val[0], width),
      Variable.input(prefix + "b", val[1], width, ([ "type" : "password" ]))
    });
  }
} // }}}

class VariableOpList // {{{
{
  inherit Variable.List;
  constant type = "VariableOpList";

  string render_row(string prefix, array(string) val, int width)
  {
    return sprintf(#"
      <input type='hidden' name='%[0]s' value='%[0]s' />
      <td><input type='text' name='%[0]s_name'  value='%[1]s' /></td>
      <td><input type='text' name='%[0]s_url'   value='%[2]s' /></td>
      <td><input type='text' name='%[0]s_alias' value='%[3]s' /></td>",
      prefix, val[0], val[1], val[2]
    );
  }

  array(string) transform_to_form(array(string) val)
  {
    return val;
  }

  array(string) transform_from_form(string v, mapping va)
  {
    if (v == "") return ({ "", "", "" });
    v = v[sizeof(path())..];
#define VAV(X) va[v+"_"+X]
    return ({ VAV("name"), VAV("url"), VAV("alias") });
  }

  array verify_set_from_form(array(array(string)) new_value)
  {
    string warn = "";
    array(array(string)) res = ({});
    //werror("verify_set_from_form(%O)\n", new_value);
    foreach (new_value, array row) {
      //TRACE("row: %O\n", row);
      row = map(row, lambda(string v) { return (string)v; } );
      res += ({ row });
    }
    return ({ warn, res });
  }
  
  string render_form( RequestID id, void|mapping additional_args )
  {
    string prefix = path() + ".";
    int i;

    string res = sprintf("<a name='%s'>\n</a><table>"
                         "<input type='hidden' name='%scount' value='%d' />",
                         path(), prefix, _current_count);

    if (sizeof(query())) {
      res +=
      "<tr><th style='width:20px; text-align:left'>Operator</th>\n"
      "<th style='width:20px; text-align:left'>Login URL</th>\n"
      "<th style='width:20px; text-align:left'>Alias</th></tr>";
    }

    foreach (map(query(), transform_to_form), mixed val) 
    {
      res += "<tr>"+ render_row(prefix+"set."+i, val, width);

#define BUTTON(X,Y)  \
  ("<submit-gbutton2 name='"+X+"'>"+Y+"</submit-gbutton2>")

#define REORDER(X,Y) \
  ("<submit-gbutton2 name='"+X+"' icon-src='"+Y+"'></submit-gbutton2>")

#define DIMBUTTON(X) \
  ("<disabled-gbutton icon-src='"+X+"'></disabled-gbutton>")

#define TD(X) res += "<td>" + (X) + "</td>\n"

      if (i) TD(REORDER(prefix + "up." + i, "/internal-roxen-up"));
      else   TD(DIMBUTTON("/internal-roxen-up"));

      if (i != sizeof(query()) - 1)
        TD(REORDER(prefix + "down." + i, "/internal-roxen-down"));
      else 
      	TD(DIMBUTTON("/internal-roxen-down"));

      TD(BUTTON(prefix+"delete."+i, LOCALE(227, "Delete"))) + "</tr>";

      i++;
    }
    res += "<tr><td colspan='2'>" +
           BUTTON(prefix+"new", LOCALE(297, "New row")) +
           "</td></tr></table>\n\n";

    return res;
  }
} // }}}

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");
  conf = _conf;
  cookie_auth = CookieAuth();

  defvar("db_name",
    Variable.DatabaseChoice(
      "openid_" + (conf ? Roxen.short_name(conf->name):""), 0,
      "OpenID Database",
      "The database where OpenID identities will be stored."
    )->set_configuration_pointer(my_configuration)
  );

  defvar("login_user",
    VariableUserList(
      ([]), VAR_INITIAL|VAR_NO_DEFAULT,
      "Internal users",
      "List of internal users to login as through OpenID"
    )
  );

  array(array(string)) def_providers = ({});
  foreach (values(get_providers()), Provider p)
    def_providers += ({ ({ p->get_name(), p->get_url(), p->get_alias() }) });

  defvar("providers",
    VariableOpList(
      def_providers, VAR_INITIAL,
      "OpenID providers",
      "List of operators that provide OpenID authentication "
      "through a generic URL"
    )
  );
} // }}}

void start(int when, Configuration _conf) // {{{
{
  ::start(when, _conf);
  cookie_auth->start(when, _conf);

  db_name = query("db_name");

  foreach (query("providers"), array(string)p)
    add_provider(Provider( p[0], p[1], p[2] ));

  ac_users = query("login_user");

  if (db_name)
    init_db();
  
  query_tag_set()->prepare_context = set_entities;
} // }}}

Sql.Sql get_db() // {{{ 
{
  return DBManager.get(db_name, conf);
} // }}}

SqlResult q(mixed ... args) // {{{
{
  return get_db()->query(@args);
} // }}}

mixed init_db() // {{{
{
  if (db_name == " none") return 0;
  mapping perms = DBManager.get_permission_map()[db_name];

  if (!get_db()) {
    if (perms && perms[conf->name] == DBManager.NONE) {
      report_error("No permission to read OpenID database: %s\n", db_name);
      return 0;
    }
    
    report_notice("No OpenID database present. Creating \"%s\".\n", 
                  db_name);

    if (!DBManager.get_group("poppa")) {
      DBManager.create_group( 
	"poppa", "Poppa Modules",
	"Various databases used by the Poppa modules", "" 
      );
    }

    DBManager.create_db(db_name, 0, 1, "poppa");
    DBManager.set_permission(db_name, conf, DBManager.WRITE);
    perms = DBManager.get_permission_map()[db_name];
    DBManager.is_module_db(0, db_name,
			   "Used by the OpenID module to "
			   "store its data.");

    if (!get_db()) {
      report_error("Unable to create OpenID database.\n");
      return 0;
    }
  }

  if (perms && perms[conf->name] == DBManager.WRITE)
    setup_tables();
} // }}}

void setup_tables() // {{{
{
  q(#"CREATE TABLE IF NOT EXISTS `user` (
     `identity`  VARCHAR(255) BINARY PRIMARY KEY,
     `cookie`    BLOB,
     `email`     VARCHAR(255),
     `fullname`  VARCHAR(255),
     `firstname` VARCHAR(255),
     `lastname`  VARCHAR(255),
     `language`  VARCHAR(50),
     `gender`    VARCHAR(50)
     ) TYPE=MYISAM");

  DBManager.is_module_table(this_object(), db_name, "user", 0);
} // }}}

mapping get_identity(string idt) // {{{
{
  SqlResult r = q("SELECT * FROM `user` WHERE `identity`=%s", idt||"");
  if (!r || !sizeof(r)) return 0;

  Authentication a;
  if (mixed e = catch(a = Authentication()->from_mapping( r[0] ))) {
    report_error("%s:%d: %s", basename(__FILE__), __LINE__, describe_error(e));
    return 0;
  }

  return ((mapping)a) + ([ "cookie" : r[0]->cookie ]);
} // }}}

string get_db_cookie(string idt) // {{{
{
  SqlResult r = q("SELECT * FROM `user` WHERE `identity`=%s", idt);
  if (!r || !sizeof(r)) return 0;

  Authentication a;
  if (mixed e = catch(a = Authentication()->from_mapping( r[0] ))) {
    report_error("%s:%d: %s", basename(__FILE__), __LINE__, describe_error(e));
    return 0;
  }

  return r[0]->cookie;
} // }}}

void save_identity(Authentication|mapping a) // {{{
{
  if (objectp(a)) a = (mapping)a;

  string sql = "INSERT INTO `user` (identity, cookie, email, fullname,"
               " firstname, lastname, language, gender) "
               "VALUES(%s, %s, %s, %s, %s, %s, %s, %s)";
  q(sql, a->identity, a->cookie||"", a->email, a->fullname, a->firstname,
         a->lastname, a->language, a->gender);
} // }}}

void update_identity(Authentication|mapping a)
{
  if (objectp(a)) a = (mapping)a;

  string sql = "UPDATE `user` SET cookie=%s, email=%s, fullname=%s,"
               " firstname=%s, lastname=%s, language=%s, gender=%s "
               "WHERE identity=%s";

  q(sql, a->cookie, a->email, a->fullname, a->firstname, a->lastname,
         a->language, a->gender, a->identity);
}

// {{{ Macros

#define REDIRECT(TO) do {                                                      \
  mapping r = Roxen.http_redirect((TO), id);                                   \
  if (r->error) RXML_CONTEXT->set_misc (" _error", r->error);                  \
  if (r->extra_heads) RXML_CONTEXT->extend_scope ("header", r->extra_heads);   \
  } while (0)
/// END REDIRECT

#define GET_COOKIE() \
  id->cookies[auth_cookie_name]&&decode_value( id->cookies[auth_cookie_name] );

// }}}

mapping get_cookie(RequestID id)
{
  string cki = id->cookies && id->cookies[auth_cookie_name];
  if (!cki) return 0;
  catch { return decode_value(cki); };
  
  return 0;
}

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

class TagOpenIdAuthenticate // {{{
{
  inherit RXML.Tag;
  constant name = "openid-authenticate";

  mapping(string:RXML.Type) req_arg_types = ([
    "operator-variable" : RXML.t_text(RXML.PXml)
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "path"        : RXML.t_text(RXML.PXml),
    "domain"      : RXML.t_text(RXML.PXml),
    "persistent"  : RXML.t_text(RXML.PXml),
    "return-to"   : RXML.t_text(RXML.PXml),
    "ac-identity" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      mapping cookie = get_cookie(id) || ([]);
      int cookie_time = args->presistent && -1 || Roxen.time_dequantifier(args);
      _ok = 0;

      if (string op = RXML.user_get_var( args["operator-variable"] )) {
	[string uri, string realm] = self_and_realm(args, id);

	mixed e = catch {
	  if ( string acid = args["ac-identity"] )
	    if ( !ac_users[acid] )
	      error("Missconfiguration. Given AC user doesn't exist! ");

	  Manager manager = Manager();
	  manager->set_return_to(uri);
	  manager->set_realm(realm);

	  cookie->op     = op;
	  Endpoint ep    = manager->get_endpoint(op);
	  Association as = manager->get_association(ep);

	  if (string op_url = manager->get_login_url(ep, as)) {
	    cookie->association = as->encode_cookie();
	    Roxen.set_cookie(id, auth_cookie_name, encode_value(cookie),
	                     cookie_time, args->domain, args->path);
	    REDIRECT(op_url);
	  }
	  else error("Unable to get login URL for operator %O\n", op);
	};

	if (e) RXML.user_set_var("openid.error", describe_error(e));
      }
      else if ( id->variables["openid.response_nonce"] ) {
      	TRACE("Cookie: %O\n", cookie);
	if (!cookie || !cookie->op || !cookie->association) {
	  _ok = 0;
	  RXML.user_set_var("openid.error", "Missing cookie for association");
	  return 0;
	}

	[string uri, string realm] = self_and_realm(args, id);

	mixed e = catch {
	  Manager manager = Manager();
	  manager->set_return_to(uri);
	  manager->set_realm(realm);

	  Endpoint ep = manager->get_endpoint(cookie->op);
	  Association assoc = Association()->decode_cookie(cookie->association);
	  Authentication auth = manager->parse_auth_response(id->variables,
							     assoc);

	  if (!get_identity(auth->get_identity()))
	    save_identity(auth);
	  else
	    update_identity(auth);

	  if (string acid = args["ac-identity"] ) {
	    if ( string pwd = ac_users[acid] ) {
	      TRACE("Do cookie login...%s\n", pwd);
	      /*
	      RoxenModule ac = conf->get_provider("acauth_cookie");
	      if (!ac) RXML.run_error("Unable to get provider acauth_cookie");
	      id->variables["_user"] = acid;
	      id->variables["_pass"] = pwd;
	      */

	      mapping acargs = ([
		"username"   : acid,
		"password"   : pwd,
		"path"       : args->path,
		"domain"     : args->domain,
		"persistent" : args->persistent
	      ]);

	      string accookie;
	      if (!(accookie = cookie_auth->auth(name, acargs, id))) {
	      	error("Unable to login in as given proxy user! "
	      	      "This application is misconfigured.");
	      }

	      TRACE(">>> AC-Cookie: %s\n", accookie);
	    }
	    else {
	      RXML.run_error("No internal user %O is configured in "
	                     "open-id.pike");
	    }
	  }

	  Roxen.remove_cookie(id, auth_cookie_name, "");
	  cookie->authentication = auth->get_identity();

	  TRACE("Cookie is: %O\n", cookie);

	  Roxen.set_cookie(id, auth_cookie_name, encode_value(cookie),
	                       cookie_time, args->domain, args->path);
	  _ok = 1;
	};

	if (e) {
	  TRACE("### CRAP: %s\n", describe_backtrace(e));
	  RXML.user_set_var("openid.error", describe_error(e));
	}
      }
      else if ( id->variables["openid.mode"] == "cancel" ) {
      	RXML.user_set_var("openid.error", "Authentication was cancelled by "
      	                                  "the user");
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
  mapping(string:RXML.Type) opt_arg_types = ([
    "path"   : RXML.t_text(RXML.PXml),
    "domain" : RXML.t_text(RXML.PXml),
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string path   = args->path || 0;
      string domain = args->domain || 0;
      Roxen.remove_cookie(id, auth_cookie_name, "", domain, path);
      cookie_auth->logout(name, args, id);
      return 0;
    }
  }
} // }}}

array self_and_realm(mapping args, RequestID id) // {{{
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
} // }}}

// First try API
mapping first_try(RequestID id)
{
  if (string cki = id->cookies[auth_cookie_name] ) {
    catch {
      mapping c = decode_value(cki);
      //TRACE("First try: %O\n", id);
      if (c = get_identity(c->authentication)) {
	id->misc->openid_user = c + ([ "is-authenticated" : 1 ]);
	
      }
    };
  }
}

// Scope extension {{{

mapping openid_user_scope = ([ "is-authenticated" : EntityRoxenOpenID(),
                               "identity"         : EntityRoxenOpenID(),
                               "fullname"         : EntityRoxenOpenID(),
                               "firstname"        : EntityRoxenOpenID(),
                               "lastname"         : EntityRoxenOpenID(),
                               "language"         : EntityRoxenOpenID(),
                               "gender"           : EntityRoxenOpenID(),
                               "email"            : EntityRoxenOpenID(),
                               "error"            : EntityRoxenOpenID() ]);

void set_entities(RXML.Context c) // {{{
{
  c->extend_scope("openid", openid_user_scope + ([]));
} // }}}

class EntityRoxenOpenID // {{{
{
  inherit RXML.Value;

  mixed rxml_const_eval(RXML.Context c, string var, string scope_name)
  {
    c->id->misc->cacheable = 0;
    if (mapping u = c->id->misc->openid_user)
      return u[var];

    return 0;
  }
} // }}}

class CookieAuth
{
  inherit "roxen-module://acauth_cookie";

  void start(int when, Configuration conf)
  {
    ::start(when, conf);
    if (RoxenModule rm = conf->get_provider("acauth_cookie"))
      this->db_name = rm->query("db_name");
  }

  string auth(string tag_name, mapping args, RequestID id)
  {
    if (!args->username) error("No username given to cookie_auth! ");
    if (!args->password) error("No password given to cookie_auth! ");

    string username = args->username;
    string password = args->password;

    AC.AC_DB acdb = online_acdb();
    if (!acdb)
      RXML.parse_error("There's no Access Control database in this server.\n");

    int|AC.IdAuth idauth = auth_std_passwd(acdb, username, password);
    if (!(idauth && objectp(idauth)))
      return 0;

    string random_cookie = get_or_set_random_cookie(idauth->identity());
    int t = args->persistent ? -1 : Roxen.time_dequantifier(args);
    Roxen.set_cookie(id, "RoxenACauth", random_cookie, t, args->domain,
                     args->path);

    return random_cookie;
  }

  void logout(string tag_name, mapping args, RequestID id)
  {
    tag_ac_cookie_logout(tag_name, args, id);
    Roxen.remove_cookie(id, "RoxenACauth", "", args->domain, args->path);
  }
}

// End:Scope extension }}}
