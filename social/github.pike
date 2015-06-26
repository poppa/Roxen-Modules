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

#define GITHUB_DEBUG

#ifdef GITHUB_DEBUG
# define TRACE(X...) report_debug("Github (%3d): %s", __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]
/* The Github Authorization object */
#define GH  id->misc->github
#define GH_AUTH  id->misc->github->authorization

#define SET_COOKIE(V) Roxen.set_cookie(id, cookie_name, \
                                       encode_cookie(encode_value(V)), -1, 0, "/")
#define REMOVE_COOKIE() Roxen.remove_cookie(id, cookie_name, "", 0, "/")

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Github";
constant module_doc  = "Tagset for Github autentication and communication.";

Configuration conf;

constant plugin_name = "github";
constant cookie_name = "ghsession";
constant Klass = RoxenGithub;
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

class TagGithub
{
  inherit tagset::TagSocial;
  constant name = "github";

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagGithub", ({
      TagGithubLoginUrl(),
      TagGithubLogin(),
      TagGithubLogout(),
      TagGithubEmitRequest()
    })
  );

  // Login URL
  class TagGithubLoginUrl
  {
    inherit TagSocialLoginUrl;
    constant name = "gh-login-url";

    string do_login_url(mapping args, RequestID id)
    {
      TRACE("Login URL in Github: %O!\n", GH_AUTH->get_scope());
      return ::do_login_url(args, id);
    }
  }

  class TagGithubLogin
  {
    inherit TagSocialLogin;
    constant name = "gh-login";

    array do_login(mapping args, RequestID id)
    {
      array data = ::do_login(args, id);
      TRACE ("do_login in Github: %O\n\n", data);

      if (data && sizeof(data) && args->variable)
        RXML.user_set_var(args->variable, data[0]);
    }
  }

  class TagGithubLogout
  {
    inherit TagSocialLogout;
    constant name = "gh-logout";
  }

  class TagGithubEmitRequest // {{{
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "gh-request";

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
      RoxenGithub api = api_instance(id);

      mixed err = catch {
        function f = api[args->method];

        TRACE("Function: %O(%O, %O)\n", f, args->query, p);

        if (f) {
          mapping|array res = f(args->query, p);

          TRACE("Res: %O\n", res);

          if (args->select) {
            mixed r = get_selection(res, args->select);

            if (r && !arrayp(r))
              ret = ({ r });
            else
              ret = r;
          }
          else if (res) {
            if (mappingp(res))
              ret = ({ res });
            else
              ret = res;
          }

          if (res && !args["no-cache"]) {
            int len = (args->cache && (int)args->cache) || 600;
            dcache->set(ck, ret, len);
          }

          return ret;
        }
      };

      if (err) {
        report_error("Error in github.pike: %s\n", describe_backtrace(err));
        RXML.user_set_var("var.gh-error", describe_error(err));
      }

      return ({});
    }
  }
}

class RoxenGithub
{
  inherit Social.Github;
}


private class TagSocialBanAdd {}
private class TagSocialBanRemove {}
private class TagEmitBans {}
private class TagEmitSubscope {}
private class TagTimeToDuration {}
