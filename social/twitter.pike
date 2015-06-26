/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  Tags for communicating with the Twitter Socail Graph API.
*/

#charset utf-8

#include <config.h>
#include <module.h>
inherit "module";

inherit "roxen-module://social-tagset" : tagset;

//#define TWITTER_DEBUG

#ifdef TWITTER_DEBUG
# define TRACE(X...) werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]
/* The Twitter Authorization object */
#define TWITTER  id->misc->twitter
#define TWITTER_AUTH  id->misc->twitter->authorization

#define SET_COOKIE(V) Roxen.set_cookie(id, cookie_name, \
                                       encode_cookie(encode_value(V)), -1, 0, "/")
#define REMOVE_COOKIE() Roxen.remove_cookie(id, cookie_name, "", 0, "/")

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Twitter";
constant module_doc  = "Tagset for Twitter autentication and communication.";

Configuration conf;

constant plugin_name = "twitter";
constant cookie_name = "twittersession";
constant Klass = RoxenTwitter;

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

class TagTwitter
{
  inherit tagset::TagSocial;
  constant name = "twitter";

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagTwitter", ({
      TagTwitterLoginUrl(),
      TagTwitterLogin(),
      TagTwitterLogout(),
      TagTwitterEmitRequest()
    })
  );

  // Login URL
  class TagTwitterLoginUrl
  {
    inherit TagSocialLoginUrl;
    constant name = "tw-login-url";

    string do_login_url(mapping args, RequestID id)
    {
      TRACE ("Login URL in Twitter!\n");
      return ::do_login_url(args, id);
    }
  }

  class TagTwitterLogin
  {
    inherit TagSocialLogin;
    constant name = "tw-login";

    array do_login (mapping args, RequestID id)
    {
      array data = ::do_login(args, id);
      TRACE ("do_login in twitter: %O\n\n", data);

      if (args->variable && data && sizeof(data))
        RXML.user_set_var(args->variable, data[0]);
    }
  }

  class TagTwitterLogout
  {
    inherit TagSocialLogout;
    constant name = "tw-logout";
  }

  class TagTwitterEmitRequest // {{{
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "tw-request";

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
      RoxenTwitter api = api_instance(id);

      TRACE("Twitter: %O\n", api);

      //return ({});

      mixed err = catch {
        function f = api[args->method];

        if (f) {
          TRACE("Func: %O(%O, %O)\n", f, args->query, p);
          mapping|array res = f(args->query, p);
          TRACE("res: %O\n", res);

          if (!res) return ret;

          if (args->select) {
            mixed r = get_selection(res, args->select);

            if (r && !arrayp(r))
              ret = ({ r });
            else
              ret = r;
          }
          else {
            if (!arrayp(res))
              ret = ({ res });
            else
              ret = res;
          }

          if (!args["no-cache"]) {
            int len = (args->cache && (int)args->cache) || 600;
            dcache->set(ck, ret, len);
          }

          return ret;
        }
      };

      if (err)
        report_error("Error in twitter.pike: %s\n", describe_error(err));

      return ({});
    }
  }
}

class TagTwitterText // {{{
{
  inherit RXML.Tag;
  constant name = "twitter-text";

  string turl = "http://twitter.com/#!/";

  Regexp.PCRE.Widestring re_hashat =
    Regexp.PCRE.Widestring("(?<=^|(?<=[^-a-zåäöÅÄÖ0-9_.]))"
                           "(@|#)([a-zåäöÅÄÖ]+[a-zåäöÅÄÖ0-9_]+)",
                           Regexp.PCRE.OPTION.CASELESS);

  Regexp.PCRE.Widestring re_url =
    Regexp.PCRE.Widestring("((?:http|https)://(.[^ ]*))( |$)",
                           Regexp.PCRE.OPTION.CASELESS);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = content;

      result = re_url->replace(result,
        lambda (string s, string u, string a, string b) {
          return sprintf("<a href=\"%s\">%s</a>%s", u, a, b);
        }
      );
      result = re_hashat->replace(result,
        lambda (string s, string a, string b) {
          string x = turl;
          string c = "";
          if (a == "@") {
            x += Protocols.HTTP.uri_encode(b);
            c = "at";
          }
          else if (a == "#") {
            x += "search?q=" + Protocols.HTTP.uri_encode(b);
            c = "hash";
          }
          return sprintf("<a class=\"%s\" href=\"%s\">%s%s</a>", c, x, a, b);
        }
      );

      catch (result = utf8_to_string(result));

      return 0;
    }
  }
} // }}}

class RoxenTwitter
{
  inherit Social.Twitter;
}

private class TagSocialBanAdd {}
private class TagSocialBanRemove {}
private class TagEmitBans {}
private class TagEmitSubscope {}
private class TagTimeToDuration {}
