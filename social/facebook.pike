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

//#define FB_DEBUG

#ifdef FB_DEBUG
# define TRACE(X...) report_debug("FB Roxen (%3d): %s", __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]
/* The Facebook Authorization object */
#define FB  id->misc->facebook
#define FB_AUTH  id->misc->facebook->authorization

#define SET_COOKIE(V) Roxen.set_cookie(id, cookie_name, \
                                       encode_cookie(encode_value(V)), -1, 0, "/")
#define REMOVE_COOKIE() Roxen.remove_cookie(id, cookie_name, "", 0, "/")

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Facebook";
constant module_doc  = "Tagset for Facebook autentication and communication.";

Configuration conf;

constant plugin_name = "facebook";
constant cookie_name = "fbsession";
constant Klass = RoxenFacebook;

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

class TagFacebook
{
  inherit tagset::TagSocial;
  constant name = "facebook";

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagFacebook", ({
      TagFacebookLoginUrl(),
      TagFacebookLogin(),
      TagFacebookLogout(),
      TagFacebookEmitRequest()
    })
  );

  // Login URL
  class TagFacebookLoginUrl
  {
    inherit TagSocialLoginUrl;
    constant name = "fb-login-url";

    string do_login_url(mapping args, RequestID id)
    {
      TRACE("Login URL in Facebook: %O!\n", FB_AUTH->get_scope());
      return ::do_login_url(args, id);
    }
  }

  class TagFacebookLogin
  {
    inherit TagSocialLogin;
    constant name = "fb-login";

    array do_login(mapping args, RequestID id)
    {
      array data = ::do_login(args, id);
      TRACE ("do_login in facebook: %O\n\n", data);
    }
  }

  class TagFacebookLogout
  {
    inherit TagSocialLogout;
    constant name = "fb-logout";
  }

  class TagFacebookEmitRequest // {{{
  {
    inherit TagEmitSocialRequest;
    constant plugin_name = "fb-request";

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
      RoxenFacebook api = api_instance(id);

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
        report_error("Error in facebook.pike: %s\n", describe_error(err));
        RXML.user_set_var("var.fb-error", describe_error(err));
      }

      return ({});
    }
  }
}

class RoxenFacebook
{
  inherit Social.Facebook;
}


private class TagSocialBanAdd {}
private class TagSocialBanRemove {}
private class TagEmitBans {}
private class TagEmitSubscope {}
private class TagTimeToDuration {}

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