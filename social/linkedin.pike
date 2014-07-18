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

//#define LINKEDIN_DEBUG

#ifdef LINKEDIN_DEBUG
# define TRACE(X...) report_debug("Linkedin (%3d): %s", __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]
/* The Ln Authorization object */
#define LN  id->misc->linkedin
#define LN_AUTH  id->misc->linkedin->authorization

#define SET_COOKIE(V) Roxen.set_cookie(id, cookie_name, \
                                       encode_cookie(encode_value(V)), -1, 0, "/")
#define REMOVE_COOKIE() Roxen.remove_cookie(id, cookie_name, "", 0, "/")

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Linkedin";
constant module_doc  = "Tagset for Linkedin autentication and communication.";

Configuration conf;

constant plugin_name = "linkedin";
constant cookie_name = "lnsession";
constant Klass = RoxenLinkedin;
private DataCache dcache = DataCache();

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");
  conf = _conf;
  tagset::create(conf);
}

void start(int when, Configuration _conf){}

class TagLinkedin
{
  inherit tagset::TagSocial;
  constant name = "linkedin";

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagLinkedin", ({
      TagLinkedinLoginUrl(),
      TagLinkedinLogin(),
      TagLinkedinLogout(),
      TagLinkedinEmitRequest()
    })
  );

  // Login URL
  class TagLinkedinLoginUrl
  {
    inherit TagSocialLoginUrl;
    constant name = "ln-login-url";

    string do_login_url(mapping args, RequestID id)
    {
      TRACE("Login URL in Ln: %O!\n", LN_AUTH->get_scope());
      return ::do_login_url(args, id);
    }
  }

  class TagLinkedinLogin
  {
    inherit TagSocialLogin;
    constant name = "ln-login";

    array do_login(mapping args, RequestID id)
    {
      array data = ::do_login(args, id);
      TRACE ("do_login in Ln: %O\n\n", data);

      if (data && sizeof(data) && args->variable)
        RXML.user_set_var(args->variable, data[0]);
    }
  }

  class TagLinkedinLogout
  {
    inherit TagSocialLogout;
    constant name = "ln-logout";
  }

  class TagLinkedinEmitRequest // {{{
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "ln-request";

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
      RoxenLinkedin api = api_instance(id);

      mixed err = catch {
        function f = api[args->method];

        TRACE("Function: %O(%O, %O)\n", f, args->query, p);

        if (f) {
          mapping res = f(args->query, p);

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
        report_error("Error in linkedin.pike: %s\n", describe_error(err));
        RXML.user_set_var("var.ln-error", describe_error(err));
      }

      return ({});
    }
  }
}

class RoxenLinkedin
{
  inherit Social.Linkedin;
}
