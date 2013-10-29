/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  Gravatar module

  This module generates an URL to a Gravatar image.
  http://www.gravatar.com
*/

#charset utf-8

#include <config.h>
#include <module.h>
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Gravatar tags";
constant module_doc  =
#"Tag for getting a gravatar (Globally Recognized Avatar) for a given e-mail
address. See <a href='http://gravatar.com/'>gravatar.com</a> for more
information";

Configuration conf;

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");
  conf = _conf;
}

void start(int when, Configuration _conf){}

//! Generates a Gravatar image url
class TagGravatar
{
  inherit RXML.Tag;
  constant name = "gravatar";

  mapping(string:RXML.Type) req_arg_types = ([
    "email" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "size" : RXML.t_text(RXML.PEnt),
    "rating" : RXML.t_text(RXML.PEnt),
    "variable" : RXML.t_text(RXML.PEnt),
    "default-image" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      Gravatar g = Gravatar(args->email, args->size, args->rating);

      if (args["default-image"])
        g->image = args["default-image"];

      if (mixed e = catch(result = (string)g))
        RXML.parse_error("%s\n", describe_error(e));

      if (args->variable) {
        RXML.user_set_var(args->variable, result);
        result = "";
      }

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
      Gravatar g = Gravatar(args->email, args->size, args->rating);

      if ( args["default-image"] )
        g->image = args["default-image"];

      if (mixed e = catch(result = g->img()))
        RXML.parse_error("%s\n", describe_error(e));

      if (args->variable) {
        RXML.user_set_var(args->variable, result);
        result = "";
      }

      return 0;
    }
  }
}

//| http://github.com/poppa/Pike-Modules/blob/master/Social.pmod/Gravatar.pike
class Gravatar
{
  //! G rated gravatar is suitable for display on all websites with any
  //! audience type.
  constant RATING_G = "g";

  //! PG rated gravatars may contain rude gestures, provocatively dressed
  //! individuals, the lesser swear words, or mild violence.
  constant RATING_PG = "pg";

  //! R rated gravatars may contain such things as harsh profanity, intense
  //! violence, nudity, or hard drug use.
  constant RATING_R = "r";

  //! X rated gravatars may contain hardcore sexual imagery or extremely
  //! disturbing violence.
  constant RATING_X = "x";

  //! Base URI to the gravatar site
  protected local string gravatar_url = "http://www.gravatar.com/avatar.php?";

  //! Avilable ratings
  protected multiset ratings = (< RATING_G, RATING_PG, RATING_R, RATING_X >);

  //! Default fallback image.
  string image;

  //! The email the Gravatar account is registered with
  string email;

  //! The Gravatar rating
  string rating = RATING_G;

  //! The size of the Gravatar to display
  int size = 80;

  //! Creates a new @[Gravatar] object
  //!
  //! @param _email
  //! The email the account is registerd with
  //! @param _size
  //! Sets the size of the image. Default is @tt{80@}
  //! @param _rating
  //! The rating the Gravatar is registerd as. Default value is @tt{G@}
  void create(void|string _email, void|string|int _size, void|string _rating)
  {
    email = _email;
    size = (int)_size||size;
    rating = _rating||rating;
  }

  //! Creates and returns the URL to the Gravatar
  string get_avatar()
  {
    if (!email)
      error("Missing requierd \"email\".\n");

    if ( !ratings[rating] ) {
      error("Rating is %O. Must be one of \"%s\".\n",
            rating, String.implode_nicely((array)ratings, "or"));
    }

    if (size < 1 || size > 512)
      error("Size must be between 1 and 512.\n");

    return gravatar_url +
    sprintf("gravatar_id=%s&amp;rating=%s&amp;size=%d",encode_id(),rating,size) +
    (image && ("&amp;default=" + Roxen.http_encode_invalids(image))||"");
  }

  //! Returns the Gravatar as a complete @tt{<img/>@} tag.
  string img(void|string alt_text)
  {
    alt_text = alt_text||"Gravatar";
    return sprintf("<img src='%s' height='%d' width='%d' alt='%s' title=''/>",
                   get_avatar(), size, size, alt_text);
  }

  //! Hashes the email.
  protected string encode_id()
  {
    string hash = String.trim_all_whites(lower_case(email));
#if constant(Crypto.MD5)
    hash = String.string2hex(Crypto.MD5.hash(hash));
#else /* Compat cludge for Pike 7.4 */
    hash = Crypto.string_to_hex(Crypto.md5()->update(hash)->digest());
#endif

    return hash;
  }

  //! Casting method.
  //!
  //! @param how
  mixed cast(string how)
  {
    if (how == "string")
      return get_avatar();

    error("Can't cast %O to %O.\n", object_program(this_object()), how);
  }
}

mapping find_internal(string f, RequestID id)
{
  mixed e = catch {
    if (f[-1] == '/')
      f = f[0..sizeof(f)-2];

    array(string) parts = f/"/";

    if (sizeof(parts) > 0) {
      string url = "/";

      if (sscanf(parts[-1], "%*d") > 0) {
        url += parts[0..sizeof(parts)-2]*"/";
        url += "?__max-width=" + parts[-1];
      }
      else
        url += parts*"/";

      mapping(string:mixed) result_mapping = ([]);
      string v = id->conf->try_get_file(url, id, UNDEFINED, UNDEFINED,
                                        UNDEFINED, result_mapping);

      if (v && sizeof(v) && result_mapping->type)
        return Roxen.http_string_answer(v, result_mapping->type);
    }

    return 0;
  };

  if (e) werror("Gravatar: %s\n", describe_backtrace(e));
}

//------------------------------------------------------------------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([
"gravatar" :
#"<desc type='tag'><p><short>
Creates a gravatar URL</short></p></desc>

<attr name='email' required='required'><p>
The email address to fetch a gravatar for</p></attr>

<attr name='size' value='int' optional='optional'><p>
The size of the icon. <tt>1 - 512</tt></p></attr>

<attr name='variable' value='string' optional='optional'><p>
Set the generated URL in this variable instead of outputtning it</tt></p></attr>

<attr name='rating' value='string' optional='optional'><p>
Gravatar rating. Possible values:</p>
<ul>
  <li>g: G rated gravatar is suitable for display on all websites
  with anyaudience type. (Default)</li>
  <li>pg: PG rated gravatars may contain rude gestures, provocatively dressed
  individuals, the lesser swear words, or mild violence.</li>
  <li>r: R rated gravatars may contain such things as harsh profanity, intense
  violence, nudity, or hard drug use.</li>
  <li>x: X rated gravatars may contain hardcore sexual imagery or extremely
  disturbing violence.</li>
</ul>
</attr>

<attr name='default-image' value='string' optional='optional'><p>
URL to default icon to show when no gravatar is found.</p></attr>",

"gravatar-img" :
#"<desc type='tag'><p><short>
Same as <tt><strong>&lt;gravatar /&gt;</strong></tt> except this generates a
<tt>&lt;img /&gt;</tt> tag.</short></p>"
]);
#endif /* manual */