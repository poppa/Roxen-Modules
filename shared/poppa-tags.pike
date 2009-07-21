#include <config.h>
#include <module.h>
inherit "module";

//#define POPPA_DEBUG

#define _ok RXML_CONTEXT->misc[" _ok"]

#ifdef POPPA_DEBUG
# define TRACE(X...) report_debug("Poppa tags: " + sprintf(X))
#else
# define TRACE(X...)
#endif

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Misc tags";
constant module_doc  = "Misc. RXML tags.";

Configuration conf;

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <pontus@poppa.se>");
  conf = _conf;

  defvar("bitly_login", Variable.String(
    "", 0, "Bitly login",
    "Username to call the Bitly API as"
  ));

  defvar("bitly_apikey", CleartextPassword(
    "", 0, "Bitly API key",
    "The Bitly API key to use for the Bilty tag"
  ));
}

void start(int when, Configuration _conf){}

class CleartextPassword
{
  inherit Variable.Password;

  int(0..1) set_from_form( RequestID id )
  {
    mapping val;
    if (sizeof( val = get_form_vars(id)) && val[""] && strlen( val[""] )) {
      set( val[""] );
      return 1;
    }
    return 0;
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    additional_args = additional_args || ([]);
    additional_args->type="password";
    return Variable.input(path(), "*"*sizeof(query()), 30, additional_args);
  }
}

//! Generates a Gravatar image url
class TagGravatar
{
  inherit RXML.Tag;
  constant name = "gravatar";

  mapping(string:RXML.Type) req_arg_types = ([
    "email" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "size"          : RXML.t_text(RXML.PEnt),
    "rating"        : RXML.t_text(RXML.PEnt),
    "default-image" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      Social.Gravatar g = Social.Gravatar(args->email, args->size,
                                          args->rating);

      if (mixed e = catch(result = (string)g))
	RXML.parse_error("%s\n", describe_error(e));

      return 0;
    }
  }
}


//! Generates a Gravatar image tag
class TagGravatarImg
{
  inherit TagGravatar;
  constant name = "gravatar-img";

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      Social.Gravatar g = Social.Gravatar(args->email, args->size,
                                          args->rating);

      if (mixed e = catch(result = g->img()))
	RXML.parse_error("%s\n", describe_error(e));

      return 0;
    }
  }
}

//! Generates a bitly URL
class TagBitly
{
  inherit RXML.Tag;
  constant name = "bitly";

  mapping(string:RXML.Type) req_arg_types = ([
    "url" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "expand"  : RXML.t_text(RXML.PEnt),
    "login"   : RXML.t_text(RXML.PEnt),
    "apikey"  : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string login  = args->login  || query("bitly_login");
      string apikey = args->apikey || query("bitly_apikey");

      if (!login) {
	RXML.parse_error("Missing requierd attribute \"login\". Either "
                         "provide it in the tag or set it in the module "
			 "settings in the Admin Interface.\n");
      }

      if (!apikey) {
	RXML.parse_error("Missing requierd attribute \"apikey\". Either "
                         "provide it in the tag or set it in the module "
			 "settings in the Admin Interface.\n");
      }

      string url = args->url;
      RoxenBitly bit = RoxenBitly(login, apikey);
      Social.Bitly.Response resp;

      if (!args->expand) {
	resp = bit->shorten(args->url);
	if (resp) {
	  if (resp->success())
	    url = resp->result()->nodeKeyVal->shortUrl;
	  else
	    report_error("Unable to shorten URL: %O\n", resp->error_message());
	} 
	else
	  report_error("Unable to query Bitly.shorten()!\n");
	  
      }
      else {
	resp = bit->expand(args->url);
	if (resp) {
	  if(resp->success())
	    url = resp->result()->nodeKeyVal->longUrl;
	  else
	    report_error("Unable to expand URL: %O\n", resp->error_message());
	} 
	else
	  report_error("Unable to query Bitly.expand()!\n");
      }

      result = sprintf("<a href=%O>%s</a>", url, content||url||"");

      return 0;
    }
  }

  object /* RoxenBitly.DataCache */ bitlycache;

  class RoxenBitly
  {
    inherit Social.Bitly;

    void create(string u, string api)
    {
      handle = u;
      apikey = api;

      if (!bitlycache)
	bitlycache = DataCache();

      cache = bitlycache;
    }

    class DataCache
    {
      mapping cache;

      void create() { cache = ([]); }

      this_program set(string key, mixed value)
      {
	cache[key] = value;
	return this_object();
      }

      mixed get(string key)    { return cache[key];    }
      mixed delete(string key) { m_delete(cache, key); }
      mixed flush()            { cache = ([]);         }
      // For comaptibility with Social.Bitly.DataCache
      void  write(){}
    }
  }
}

//! Emit weather forecast
class TagEmitForecast // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "forecast";

  private mapping(string:mapping(string:mixed)) cache = ([]);
  
  mapping(string:RXML.Type) req_arg_types = ([
    "location" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "unit" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string ckey = sprintf("%s:%s", args->location, args->unit||"c");
    Social.Yahoo.Forecast f;

    if ( mapping c = cache[ckey] ) {
      if (time() - c->time > c->forecast->time_to_live()) {
	TRACE("Found cached forecast\n");
	f = c->forecast;
      }
    }

    if (!f) {
      f = Social.Yahoo.Forecast(args->location, args->unit);
      f->parse();

      cache[ckey] = ([
	"forecast" : f,
	"time"     : time()
      ]);
    }
    
    mapping m = ([
      "text"          : f->condition->text,
      "code"          : f->condition->code,
      "temp"          : f->condition->temp,
      "date"          : f->strtotime(f->condition->date),
      "long"          : f->geo->long,
      "lat"           : f->geo->lat,
      "sunrise"       : f->normalize_time(f->astronomy->sunrise),
      "sunset"        : f->normalize_time(f->astronomy->sunset),
      "wind-speed"    : f->wind->speed,
      "wind-unit"     : f->units->speed,
      "small-img-url" : f->condition_img_url("small"),
      "large-img-url" : f->condition_img_url("large")
    ]);
    
    return ({ m });
  }
} // }}}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([
"gravatar" :
  #"<desc type='tag'><p><short>
  Creates an URL to a <a href='http://gravatar.com'>Gravatar</a> icon.
  (<b>G</b>lobally <b>r</b>ecognized <b>avatar</b>)</short>
  </p></desc>

  <attr name='email'><p>
  The email address to generate the URL for.</p></attr>

  <attr name='size' optional='optional' value='int' default='80'><p>
  Size of the icon (<tt>1 to 512</tt>)</p></attr>

  <attr name='rating' optional='optional' value='string' default='G'><p>
  The gravatar rating. <tt>G, PG, R or X</tt></p></attr>

  <attr name='default-image' optional='optional' value='string'><p>
  If no gravatar is found for the given email this image will be displayed
  instead. Can be <tt>identicon</tt>, <tt>monsterid</tt>, <tt>wavatar</tt> or
  an <tt>url to an image</tt>
  </p></attr>",

"gravatar-img" :
  #"<desc type='tag'><p><short>
  Exactly as <tt>&lt;gravatar/&gt;</tt> except this generates the entire
  <tt>&lt;img/&gt;</tt> tag.</short>
  </p></desc>",

"bitly" :
  #"<desc type='cont'><p><short>
  <a href='http://bit.ly'>Bitly</a> is a service for shortening, track and
  share links. This tag uses the Bitly API to shorten long URL:s</short>
  </p></desc>

  <attr name='url'><p>
  The URL to shorten, or expand if already shortened by Bitly.</p></attr>

  <attr name='expand' optional='optional' value='expand'><p>
  If given, assumes the URL is already shortened by Bitly and thus expands
  it back to its original URL.</p></attr>

  <attr name='login' value='string' optional='optional'><p>
  The Bitly username to call the Bitly services as.</p>
  <p>NOTE! This can be set in the module settings in the Admin interface</p>
  </attr>

  <attr name='apikey' value='string' optional='optional'><p>
  The API key of the user to call the Bitly services as.</p>
  <p>NOTE! This can be set in the module settings in the Admin interface</p>
  </attr>"
]);

#endif /* manual */
