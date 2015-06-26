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

inherit "roxen-module://social-tagset" : tagset;

//#define GPLUS_DEBUG

#ifdef GPLUS_DEBUG
# define TRACE(X...) report_debug("G+ Roxen (%3d): %s", __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]
/* The Google+ Authorization object */
#define GP  id->misc->gplus
#define GP_AUTH  id->misc->gplus->authorization

#define SET_COOKIE(V) Roxen.set_cookie(id, cookie_name, \
                                       encode_cookie(encode_value(V)), -1, 0, "/")
#define REMOVE_COOKIE() Roxen.remove_cookie(id, cookie_name, "", 0, "/")

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Google+";
constant module_doc  = "Tagset for Google+ autentication and communication.";

Configuration conf;

constant plugin_name = "gplus";
constant cookie_name = "gpsession";
constant Klass = RoxenGooglePlus;
constant SOCIAL_MAIN_MODULE = 0;

private DataCache dcache = DataCache();

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");
  conf = _conf;
  tagset::create(conf);
}

void start(int when, Configuration _conf){}

multiset(string) query_provides() { return 0; }

class TagGooglePlus
{
  inherit tagset::TagSocial;
  constant name = "google-plus";

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagGooglePlus", ({
      TagGooglePlusLoginUrl(),
      TagGooglePlusLogin(),
      TagGooglePlusLogout(),
      TagGooglePlusEmitRequest()
    })
  );

  // Login URL
  class TagGooglePlusLoginUrl
  {
    inherit TagSocialLoginUrl;
    constant name = "gp-login-url";

    string do_login_url(mapping args, RequestID id)
    {
      TRACE("Login URL in Google+: %O!\n", GP_AUTH->get_scope());
      return ::do_login_url(args, id);
    }
  }

  class TagGooglePlusLogin
  {
    inherit TagSocialLogin;
    constant name = "gp-login";

    array do_login(mapping args, RequestID id)
    {
      array data = ::do_login(args, id);
      TRACE ("do_login in Google+: %O\n\n", data);

      if (data && sizeof(data) && args->variable)
        RXML.user_set_var(args->variable, data[0]);
    }
  }

  class TagGooglePlusLogout
  {
    inherit TagSocialLogout;
    constant name = "gp-logout";
  }

  class TagGooglePlusEmitRequest // {{{
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "gp-request";

    array do_request(mapping args, RequestID id)
    {
      array ret = ({});

      string ck;
      if (!args["no-cache"]) {
        TRACE("No no-cache, try get cache\n");
        ck = do_get_cache_key(args, id);

        if (ret = dcache->get(ck)) {
          TRACE("Got cached result:%O!\n", ret);
          return ret;
        }
      }

      mapping p = do_get_params(args, id);
      RoxenGooglePlus api = api_instance(id);

      mixed err = catch {
        function f = api[args->method][args->query];

        TRACE("Function: %O(%O, %O)\n", f, args->query, p);

        string uid = args->user || 0;

        if (f) {
          mapping res = f(uid);

          TRACE("Res: %O\n", res);

          if (args->select) {
            mixed r = get_selection(res, args->select);

            if (r && !arrayp(r))
              ret = ({ r });
            else
              ret = r;
          }
          else if (res) ret = ({ res });

          if (res && !args["no-cache"]) {
            int len = (args->cache && (int)args->cache) || 600;
            dcache->set(ck, ret, len);
          }

          return ret;
        }
      };

      if (err) {
        report_error("Error in google-plus.pike: %s\n", describe_error(err));
        RXML.user_set_var("var.gp-error", describe_error(err));
      }

      return ({});
    }
  }
}

class RoxenGooglePlus
{
  inherit Social.Google.Plus;
}

private class TagSocialBanAdd {}
private class TagSocialBanRemove {}
private class TagEmitBans {}
private class TagEmitSubscope {}
private class TagTimeToDuration {}
