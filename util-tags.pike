#charset utf-8
// This is a Roxen module
//
// Misc utility tags
// Author: Pontus Östlund <poppanator@gmail.com>
//

//#define UTILS_DEBUG

#ifdef UTILS_DEBUG
# define TRACE(X...) werror("%s:%d: %s", basename(__FILE__), __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]

#include <config.h>
#include <module.h>
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Utility tags";
constant module_doc  = "Misc. RXML tags";

Configuration conf;

class TagIfHasValue
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "has";

  mapping(string:RXML.Type) req_arg_types = ([
    "value" : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "variable" : RXML.t_text(RXML.PXml),
    "type"     : RXML.t_text(RXML.PXml),
    "haystack" : RXML.t_text(RXML.PXml)
  ]);

  int eval(string a, RequestID id, mapping args)
  {
    mixed v, k;

    if (args->variable)
      v = RXML.user_get_var(args->variable);
    else if (args->haystack)
      v = args->haystack;
    else
      RXML.parse_error("Missing attribute \"variable\" or \"haystack\"!");

    k = args->value;

    if (args->type) {
      switch (args->type)
      {
        case "int":    k = (int)k;    break;
        case "float":  k = (float)k;  break;
        case "string": k = (string)k; break;
      }
    }

    switch (a)
    {
      case "value":
        return v && has_value(v, k);
      case "index":
        return v && has_index(v, k);
    }

    return 0;
  }
}

class TagIfRoxenTrue
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "roxen-true";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
  ]);

  int eval(mixed a, RequestID id, mapping args)
  {
    mixed v = RXML.user_get_var(a);

    int(0..1) ok = objectp(v) && v == Roxen.true;
    return ok;
  }
}

class TagIfIsVisibe
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "is-visible";

  mapping(string:RXML.Type) req_arg_types = ([
    "visible-from" : RXML.t_text(RXML.PXml),
    "visible-to"   : RXML.t_text(RXML.PXml)
  ]);

  int eval(string a, RequestID id, mapping args)
  {
#define NORMALIZE_DATE(D) replace (D, (["-":"",":":"","T":""," ":""]))

    string now = NORMALIZE_DATE(Calendar.now()->format_time());
    string f = NORMALIZE_DATE(args["visible-from"]);
    string t = NORMALIZE_DATE(args["visible-to"]);

#undef NORMALIZE_DATE

    TRACE("%s = %s <> %s\n", now, f, t);

    if (f == "never" || t == "never")
      return 0;

    if (f == "now" && t == "infinity")
      return 1;

    if (f != "now" && f > now)
      return 0;

    if (t != "infinity" && t < now)
      return 0;

    return 1;
  }
}

class TagIfEmpty
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "empty";

  mapping(string:RXML.Type) opt_arg_types = ([
    "or-has-value" : RXML.t_text(RXML.PXml),
    "split" : RXML.t_text(RXML.PXml)
  ]);

  int eval(string a, RequestID id, mapping args)
  {
    array(string) x = map(a/(args->split||","), String.trim_all_whites);
    array(string) or = ({}), values = ({});

    if (args["or-has-value"])
      or = map(args["or-has-value"]/(args->split||","), String.trim_all_whites);

    foreach (x, string z) {
      string v = RXML.user_get_var(z);

      if (v && sizeof(v) && !has_value(or, v))
        values += ({ v });
    }

    return sizeof(values) == 0;
  }
}

class TagIfSearch
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "search";

  mapping(string:RXML.Type) req_arg_types = ([
    "in" : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "case-insensitive" : RXML.t_text(RXML.PXml),
    "split" : RXML.t_text(RXML.PXml)
  ]);

  int eval(string a, RequestID id, mapping args)
  {
    if ( args["case-insensitive"] ) {
      args->in = lower_case(args->in);
      a = lower_case(a);
    }

    if (args->split) {
      string sp = sizeof(args->split) && args->split || ",";
      foreach ((a/sp)||({}), string x)
        if (search(args->in, x) > -1)
          return 1;

      return 0;
    }

    return search(args->in, a) > -1;
  }
}

#if constant(Standards.JSON)
class TagEmitJSON
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "json";

  mapping(string:RXML.Type) req_arg_types = ([
    "decode"  : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "group-by"  : RXML.t_text(RXML.PXml)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array ret = ({});

    mixed e = catch {
      mixed r = Standards.JSON.decode(args->decode);
      if (arrayp(r)) {
        array a = [array]r;
        if (a && sizeof(a)) {
          foreach (a, mixed v) {
            if (intp(v) || stringp(v) || floatp(v)) {
              ret += ({([ "value" : v ])});
            }
            else {
              ret += ({ v });
            }
          }
        }
      }
      else if (mappingp(r))
        ret = ({ [mapping]r });
    };

    if (e)
      TRACE("Error: %O\n", describe_backtrace(e));

    if (ret && args["group-by"]) {
      string g = args["group-by"];
      mapping ids = ([]);
      array t = ({});

      foreach (ret, mapping m) {
        if (!ids[m[g]]) {
          m->__count = 1;
          ids[m[g]] = m;
          ids[m[g]]->__children = ({ m });
        }
        else {
          ids[m[g]]->__count++;
          ids[m[g]]->__children += ({ m });
        }
      }

      ret = values(ids);
    }

    return ret;
  }
}

class TagJSON
{
  inherit RXML.Tag;
  constant name = "json";

  mapping(string:RXML.Type) opt_arg_types = ([
    "encode"   : RXML.t_text(RXML.PEnt),
    "decode"   : RXML.t_text(RXML.PEnt),
    "variable" : RXML.t_text(RXML.PEnt),
    "scope"    : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (args->encode) {
        string c = content;

        if (args->variable) {
          mixed e = catch {
            mixed v = RXML.user_get_var(args->variable);

            if (multisetp(v))
              v = (array) v;

            result = Standards.JSON.encode(v);
          };

          if (e)
            report_error("Unable to JSON encode: %s\n", describe_error(e));
        }
        else if (args->scope) {
          mapping my_values = ([]);
          RXML.Context context=RXML_CONTEXT;

          foreach (context->list_var(args->scope), string var) {
            mixed val = context->get_var(var, args->scope);

            if (!zero_type(val)) {
              if (multisetp(val))
                val = (array) val;

              my_values[var] = val;
            }
          }

          mixed e = catch {
            result = Standards.JSON.encode(my_values);
          };

          if (e)
            report_error("Unable to JSON encode: %s\n", describe_error(e));
        }
      }
      else if (args->decode) {
        string data = sizeof(args->decode) && args->decode || content;
        if (sizeof(data)) {
          mixed v;
          if (mixed e = catch (v = Standards.JSON.decode(data))) {
            report_error("Failed JSON.decode(): %s\n", describe_error(e));
            return 0;
          }

          if (args->variable)
            RXML.user_set_var(args->variable, v);
        }
      }

      return 0;
    }
  }
}

#endif

class TagMinify
{
  inherit RXML.Tag;
  constant name = "minify";

  mapping(string:RXML.Type) req_arg_types = ([
    // "attribute" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    // "attribute" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string src = args->src || args->href;

      if (!src) {
        if (!sizeof(content)) {
          RXML.parse_error("Missing required attribute \"src\" or \"href\"!");
          return 0;
        }

        if (!args->type) {
          RXML.parse_error("Missing required attribute \"type\" when no "
                           "\"src\" or \"href\" is given!");

          return 0;
        }

        if (!(< "css", "js", "js2" >)[lower_case(args->type)]) {
          RXML.parse_error("Type attribute must be \"css\", \"js\" or \"js2\"!");
          return 0;
        }

        switch (lower_case(args->type)) {
#if constant(Standards.CSS)
          case "css":
            if (args->raw) result = Standards.CSS.minify(content);
            else
              result = "<style>" + Standards.CSS.minify(content) + "</style>";
            return 0;
#endif

#if constant(Standards.JavaScript)
          case "js":
            if (args->raw) result = Standards.JavaScript.minify(content);
            else
              result = "<script>" + Standards.JavaScript.minify(content) +
                       "</script>";
            return 0;
#endif

#if constant(Standards.JavaScript.minify2)
          case "js2":
            if (args->raw) result = Standards.JavaScript.minify2(content);
            else
              result = "<script>" + Standards.JavaScript.minify2(content) +
                       "</script>";
#endif
            return 0;
        }

      }

      array(string) t = src / ".";

      if (!sizeof(t)) {
        RXML.parse_error("Badly formatted attribute. Need a file extension!");
        return 0;
      }

      string ext = lower_case(t[-1]);

      if (!(< "js", "css" >)[ext]) {
        RXML.parse_error("Unhandled filetype. Expected \".js\" or \".css\"!");
        return 0;
      }


      string mintype, tagname, attrname;

      if (ext == "js") {
        tagname = "script";
        attrname = "src";

        if (!args->type)
          mintype = "jsmin";
        else
          mintype = args->type == "js2" ? "jsmin2" : "jsmin";
      }
      else if (ext == "css") {
        tagname = "link";
        attrname = "href";
        mintype = "css";
      }


      if (args->type)
        m_delete(args, "type");

      args[attrname] = Roxen.add_pre_state(src, (< mintype >));

      if (tagname == "script")
        result = Roxen.make_container(tagname, args, "", 1);
      else
        result = Roxen.make_tag(tagname, args, 0, 1);



      return 0;
    }
  }
}

class TagEmitEnv
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "env";

  array get_dataset(mapping args, RequestID id)
  {
    mapping(string:string) e = getenv();
    array(mapping(string:string)) ret = ({});

    foreach (indices(e), string k)
      ret += ({ ([ "index" : k, "value" : e[k] ]) });

    return ret;
  }
}

class TagMyCase
{
  inherit RXML.Tag;
  constant name = "my-case";

  mapping(string:RXML.Type) req_arg_types = ([
    "case" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string c = content;

      switch (args->case) {
        case "up":
        case "upper": result = upper_case(c); break;
        case "down":
        case "lower": result = lower_case(c); break;
        case "caps":
        case "capitalize": result = String.capitalize(lower_case(c)); break;
        case "sillycaps": result = String.sillycaps(lower_case(c)); break;
      }

      return 0;
    }
  }
}

class TagLowerCase
{
  inherit RXML.Tag;
  constant name = "lowercase";

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = lower_case(content);
    }
  }
}

class TagUpperCase
{
  inherit RXML.Tag;
  constant name = "uppercase";

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = upper_case(content);
    }
  }
}

class TagCapitalize
{
  inherit RXML.Tag;
  constant name = "capitalize";

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = String.capitalize(lower_case(content));
    }
  }
}

class TagSillyCaps
{
  inherit RXML.Tag;
  constant name = "sillycaps";

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = String.sillycaps(lower_case(content));
    }
  }
}

class TagNl2br
{
  inherit RXML.Tag;
  constant name = "nl2br";
  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      result = content || "";
      result = replace(replace(result, "\r\n", "\n"), "\n", "<br>");
      return 0;
    }
  }
}

class TagStrip
{
  inherit RXML.Tag;
  constant name = "strip";

  mapping(string:RXML.Type) opt_arg_types = ([
    "trailing" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      content = String.trim_all_whites(content);
      if (has_suffix(content, "<br>"))
        content = content[0..sizeof(content)-5];
      else if (has_suffix(content, "<br/>"))
        content = content[0..sizeof(content)-6];

      result = content;

      return 0;
    }
  }
}

class TagRedirecrMessage
{
  inherit RXML.Tag;
  constant name = "redirect-message";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "variable" : RXML.t_text(RXML.PEnt),
    "ok" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      if (content && sizeof(content)) {
        mapping(string:int|string) m = ([]);

        m->ok = (!args->ok || args->ok == "1");
        m->message = content;

        Roxen.set_cookie(id, "RoxenRedirectMessage", encode_value(m));
      }
      else {
        mixed e = catch {
          string cookie = id->cookies["RoxenRedirectMessage"];

          if (!cookie) {
            _ok = 0;
            return 0;
          }

          if (mapping c = decode_value(cookie)) {
            if (args->variable)
              RXML.user_set_var(args->variable, c);
            else
              result = c->message;
          }
        };

        Roxen.remove_cookie(id, "RoxenRedirectMessage", "");

        _ok = 1;

        if (e) {
          report_error("Failed decoding redirect message cookie: %s",
                       describe_error(e));
          _ok = 0;
        }
      }

      return 0;
    }
  }
}

class TagCimgAttr
{
  inherit RXML.Tag;
  constant name = "cimg-attr";

  mapping(string:RXML.Type) req_arg_types = ([
    "name" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "jpeg-quality" : RXML.t_text(RXML.PEnt),
    "variable" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      array(string) pts = lower_case(args->name)/".";
      array(string) attr = ({});

      if (sizeof(pts) > 1) {
        string ext = pts[-1];
        switch (ext) {
          case "png": attr = ({ "format='png'", "true-alpha='1'" }); break;
          case "gif": attr = ({ "format='gif'", "true-alpha='1'" }); break;
        }
      }

      if (!sizeof(attr)) {
        attr = ({ "format='jpeg'", "jpeg-quality='" +
                  (args["jpeg-quality"]||85) + "'" });
      }

      if (args->variable)
        RXML.user_set_var(args->variable, attr*" ");
      else
        result = attr*" ";

      return 0;
    }
  }
}

class TagCdata
{
  inherit RXML.Tag;
  constant name = "cdata";

  mapping(string:RXML.Type) req_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      content = replace(content, ([ "\r" : "", "\n" : "" ]));
      result = "<![CDATA[" + String.trim_all_whites(content) + "]]>";
      return 0;
    }
  }
}

class TagDump
{
  inherit RXML.Tag;
  constant name = "dump";

  mapping(string:RXML.Type) opt_arg_types = ([
    "scope" : RXML.t_text(RXML.PEnt),
    "variable" : RXML.t_text(RXML.PEnt),
    "pre" : RXML.t_text(RXML.PEnt),
    "js" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      if (args->scope) {
        mapping my_values = ([]);
        RXML.Context context;

        mixed e = catch {
         context = RXML_CONTEXT;
        };

        if (!context) {
          report_notice ("No context found in %O at line %d!",
                         basename (__FILE__), __LINE__);
          return 0;
        }


        e = catch {
          foreach (context->list_var(args->scope), string var) {
            mixed val = context->get_var(var, args->scope);

            if (!zero_type(val)) {
              if (multisetp(val))
                val = (array) val;

              my_values[var] = val;
            }
          }
        };

        if (e) return 0;

        result = replace(sprintf("%O", my_values), ([ "<" : "&lt;",
                                                      ">" : "&gt;",
                                                      "&" : "&amp;" ]));
      }
      else if (args->variable)
        result = sprintf("%O", RXML.user_get_var(args->variable));

      if (args->pre)
        result = sprintf("<pre>%s</pre>", result||"");
      else if (args->js)
        result = sprintf("/*\n%s\n*/", result||"");

      return 0;
    }
  }
}

class TagShorten
{
  inherit RXML.Tag;
  constant name = "shorten";
  mapping(string:RXML.Type) req_arg_types = ([
    "max-length" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "tail" : RXML.t_text(RXML.PEnt),
    "words" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      string tail = args->tail||"...";
      int len = (int)args["max-length"];
      string cont = replace(content, ({ "\r\n","\r","\n" }), ({ " "," "," " }));
      if (sizeof(cont) <= len) {
        result = cont;
        return 0;
      }

      string tmp = "";

      if (args->words) {
        foreach (cont/" ", string word) {
          if (String.trim_all_whites(word) == "") continue;
          if (sizeof(tmp + word) > len) break;
          tmp += " " + word;
        }
        tmp = String.trim_all_whites(tmp);
      }
      else
        tmp = cont[0..len-1];

      sscanf(reverse(tmp), "%*[;:,.?!&-]%s", tmp);
      result = reverse(tmp) + tail;

      return 0;
    }
  }
}

class TagDynamicTemplateRedir
{
  inherit RXML.Tag;
  constant name = "dynamic-template-redirect-url";
  mapping(string:RXML.Type) req_arg_types = ([
    "path" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "skip" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array(string) def_skip = ({ "layout", "toggle-layout" });

    array do_return(RequestID id)
    {
      array(string) skip = map((args->skip||"")/",", String.trim_all_whites) +
                           def_skip;


      array(string) vars = ({});

//      TRACE("%O\n", sort(indices(id)));

      foreach ((mapping)id->variables; string k; mixed var) {
        if (has_value(skip, k)) continue;
        //vars += ({ "
      }
    }
  }
}

#define X_USER_NAME (id->misc->scope_user && id->misc->scope_user->username)

class TagSafeJS
{
  inherit RXML.Tag;
  constant name = "safe-js";

  mapping(string:RXML.Type) opt_arg_types = ([
    "add"    : RXML.t_text(RXML.PEnt),
    "get"    : RXML.t_text(RXML.PEnt),
    "script" : RXML.t_text(RXML.PEnt),
    "onload" : RXML.t_text(RXML.PEnt),
    "minify" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_enter(RequestID id)
    {
      if (args->add) {
        string s;
        s = Roxen.parse_rxml(content &&
                             String.trim_all_whites(content) || "", id);

        if (!id->misc->js_tail)
          id->misc->js_tail = ({});

        id->misc->js_tail += ({ s });
      }
      else if (args->script) {
        if (!id->misc->js_script)
          id->misc->js_script = ({});

        id->misc->js_script += ({ args->script });
      }

      return 0;
    }


    array do_return(RequestID id)
    {
      if (args->add)
        return 0;

      if (args->get) {
        if (id->misc->js_script) {
          foreach (Array.uniq(id->misc->js_script), string ss) {
            result += sprintf("<script src='%s'></script>", ss);
          }
        }

        if (id->misc->js_tail) {
          array(string) js = ({});

          foreach (Array.uniq(id->misc->js_tail), string ss)
            js += ({ "{ " + ss + "}" });

          string s = replace(js*"\n",
                     ({ "&lt;", "&gt;", "&amp;" }),
                     ({ "<",    ">",    "&"     }));

#if constant(Standards.JavaScript)
          if (args->minify)
            s = Standards.JavaScript.minify(s);
#endif

          result += "<script>" + s + "</script><noscript></noscript>";

          id->misc->js_tail = 0;
        }
      }
      else {
        string s;
        s = content && String.trim_all_whites(content) || "";
        if (sizeof (s)) {
          s = replace(s, ({ "&lt;", "&gt;", "&amp;" }),
                         ({ "<",    ">",    "&"     }));

          if (args->onload)
            s = "$(function() { " + s + " });";

#if constant(Standards.JavaScript)
          if (args->minify)
            s = Standards.JavaScript.minify(s);
#endif

          result = "<script>" + s + "</script><noscript></noscript>";
        }
      }

      content = "";

      return 0;
    }
  }
}

class TagCssMin
{
  inherit RXML.Tag;
  constant name = "css-min";

  mapping(string:RXML.Type) req_arg_types = ([
    // "attribute" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    // "attribute" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {

#if constant(Standards.CSS)
      result = "<style>" + Standards.CSS.minify(content) + "</style>";
#else
      result = "<style>" + content + "</style>";
#endif

      return 0;
    }
  }
}


class TagMD5
{
  inherit RXML.Tag;
  constant name = "md5";

  mapping(string:RXML.Type) opt_arg_types = ([
    "value" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = md5(args->value||content);
      return 0;
    }
  }
}

string md5(string in)
{
#if constant(Crypto.MD5)
  return String.string2hex(Crypto.MD5.hash(in));
#else
  return Crypto.string_to_hex(Crypto.md5()->update(in)->digest());
#endif
}

class TagPadINT
// <padint pad="3" separator=",">3000000</padint>
// resulterar i 3,000,000
{
  inherit RXML.Tag;
  constant name = "padint";

  mapping(string:RXML.Type) opt_arg_types = ([
    "pad" : RXML.t_text(RXML.PEnt),
    "separator" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) req_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string d = content || "";

      if (strlen(d) == 0) return 0;

      int    p  = (int)args->pad || 3;
      string pc = args->separator || " ";
      string r  = "";
      array  c  = reverse(d)/"";

      for (int i = 0; i < sizeof(c); i++) {
        r += c[i];
        if ((((i+1) % p) == 0) && ((i+1) < strlen(d))) r+= pc;
      }

      result = reverse(r);
      return 0;
    }
  }
}

class TagWordWrap
{
  inherit RXML.Tag;
  constant name = "wordwrap";

  mapping(string:RXML.Type) opt_arg_types = ([
    "width" : RXML.t_text(RXML.PXml),
    "break" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
        {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      string data  = String.trim_all_whites(content - "\r");
      int    width = (int)(args->width||80);
      string delim = args->break||"\n";

      string tmp, out = "";
      array parts = data/"\n";

      foreach (parts, string part) {
        tmp = "";
        array words = part/" ";
        foreach (words, string word) {
          if (sizeof(tmp) + sizeof(word) > width) {
            out += String.trim_all_whites(tmp) + delim;
            tmp = "";
          }
          tmp += word  + " ";
        }

        out += String.trim_all_whites(tmp) + "\n";
      }

      result = String.trim_all_whites(out);

      return 0;
    }
  }
}

class TagUtf8
{
  inherit RXML.Tag;
  constant name = "utf8";

  mapping(string:RXML.Type) opt_arg_types = ([
    "encode" : RXML.t_text(RXML.PXml),
    "decode" : RXML.t_text(RXML.PXml),
    "data"   : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      if (!args->encode && !args->decode)
        RXML.parse_error("Missing required attribute \"encode\" or \"decode\"");

      result = args->data||content;

      if (!sizeof(result) || result == RXML.Nil)
        return 0;

      if (args->encode)
        catch (result = string_to_utf8(args->data||content));
      else if (args->decode)
        catch (result = utf8_to_string(args->data||content));

      return 0;
    }
  }
}

class TagZeroPad
{
  inherit RXML.Tag;
  constant name = "zeropad";
  mapping(string:RXML.Type) req_arg_types = ([
    "length" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      string s = content || "";

      int len = (int)args->length;
      while (sizeof(s) < len)
        s = "0" + s;

      result = s;
      return 0;
    }
  }
}

class TagSleep
{
  inherit RXML.Tag;
  constant name = "sleep";
  mapping(string:RXML.Type) opt_arg_types = ([
    "seconds" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      int timeout = 0;
      if (args->seconds)
        timeout = (int)args->seconds;
      else if (args->minutes)
        timeout = ((int)args->minutes)*60;

      sleep(timeout);
      return 0;
    }
  }
}

class TagPageUri
{
  inherit RXML.Tag;
  constant name = "page-uri";
  mapping(string:RXML.Type) opt_arg_types = ([
    "variable" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      string proto, server, path;
      string url  = lower_case(conf->get_url());
      int    port = (int)id->misc->port;

      (sscanf(url, "%s://%s:%d/%s", proto, server, port, path) == 4) ||
       sscanf(url, "%s://%s/%s", proto, server, path);

      if (!path || !sizeof(path)) path = id->not_query;
      if (id->query) path += "?" + id->query;

      string r = proto + "://" + server;

      if ((proto == "http" && port != 80) || (proto == "https" && port != 443))
        r += ":" + port;

      r += path;

      if (args->variable)
        RXML.user_set_var(args->variable, r);
      else
        result = r;

      return 0;
    }
  }
}

class TagSwapProtocol
{
  inherit RXML.Tag;
  constant name = "swap-protocol";

  mapping(string:RXML.Type) opt_arg_types = ([
    "https" : RXML.t_text(RXML.PXml),
    "http"  : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      NOCACHE();

      string proto, server, path;
      string url  = conf->get_url();
      int    port = (int)id->misc->port;

      (sscanf(url, "%s://%s:%d/%s", proto, server, port, path) == 4) ||
       sscanf(url, "%s://%s/%s", proto, server, path);

      path         = id->not_query;
      array  https = args->https && map(args->https/",",String.trim_all_whites);
      array  http  = args->http  && map(args->http/",", String.trim_all_whites);

      TRACE("proto:  %O\n"
            "server: %O\n"
            "port:   %O\n"
            "path:   %O\n"
            "https:  %O\n"
            "http:   %O\n",
            proto, server, port, path, https, http);

      if (https && port != 443) {
        foreach (https, string redir) {
          if (glob(redir, path)) {
            string new_path = sprintf("https://%s%s", server, path);
            mapping r = Roxen.http_redirect(new_path, id);

            if (r->error)
              RXML_CONTEXT->set_misc(" _error", r->error);
            if (r->extra_heads)
              RXML_CONTEXT->extend_scope("header", r->extra_heads);
            if (args->text)
              RXML_CONTEXT->set_misc(" _rettext", args->text);

            return 0;
          }
        }
      }
      else if (https && port == 443) {
        foreach (https, string redir)
          if (glob(redir, path))
            return 0;
      }

      if (http && port == 443) {
        http = map(args->http/",", String.trim_all_whites);
        foreach (http, string redir) {
          if (glob(redir, path)) {
            string new_path = sprintf("http://%s%s", server, path);
            mapping r = Roxen.http_redirect(new_path, id);
            if (r->error)
              RXML_CONTEXT->set_misc(" _error", r->error);
            if (r->extra_heads)
              RXML_CONTEXT->extend_scope("header", r->extra_heads);
            if (args->text)
              RXML_CONTEXT->set_misc(" _rettext", args->text);

            return 0;
          }
        }
      }

      return 0;
    }
  }
}

class TagNiceSize
{
  inherit RXML.Tag;
  constant name = "nicesize";

  mapping(string:RXML.Type) opt_arg_types = ([
    "size" : RXML.t_text(RXML.PEnt)
  ]);

#define KB 1024
#define MB 1048576
#define GB 1073741824

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      int size = (int)(args->size||content);
      string out;

      if (size < KB)
        out = (string)size + " B";
      else if (size > KB && size < MB)
        out = ((string)((int)(size/KB))) + " kB";
      else if (size > MB && size < GB)
        out = ((string)((int)(size/MB))) + " MB";
      else
        out = ((string)((int)(size/GB))) + " GB";

      result = out;
      return 0;
    }
  }
}

class TagStripTags
// A copy of html_wash.pike except this can take defines of tags to not
// paragraphify when paragraphify is being used.
{
  inherit RXML.Tag;
  constant name = "strip-tags";
  Regexp link_regexp;

  string paragraphify(string s)
  {
    // more than one newline is considered a new paragraph
    array(string) ss = (replace(
          replace(s - "\r" - "\0", "\n\n", "\0"),
          "\0\n", "\0"
        )/"\0") - ({ "\n", "" });

    return map(ss, lambda(string x) {
      if (!has_prefix(lower_case(x), "<p"))
        return "<p>" + x + "</p>";

      return x;
    }) * "";
  }

  string unparagraphify(string s)
  {
    return replace(replace(s, ({ "<P>", "</P>" }), ({ "<p>", "</p>" })),
                   ({ "</p>\n<p>", "</p>\r\n<p>", "</p><p>", "<p>", "</p>" }),
                   ({ "\n\n",      "\n\n",        "\n\n",    "",    "" }) );
  }

  array parse_arg_array(string s)
  {
    if (!s)
      return ({ });

    return ((s - " ")/",") - ({ "" });
  }

  array safe_container(Parser.HTML p, mapping args, string cont,
                        string close_tags, mapping keep_attrs)
  {
    string tag = lower_case(p->tag_name());

    if (keep_attrs)
      args &= (keep_attrs[tag] || ({ }));

    Parser.HTML parser = p->clone();
    string res = String.trim_all_whites(parser->finish(cont)->read());

    if (tag == "blockquote" && (res && res[0] != '<'))
      res = "\0[p\0]" + res + "\0[/p\0]";

    return ({
      replace(Roxen.make_tag(tag, args), ({ "<",">" }), ({ "\0[","\0]" })) +
              res + "\0[/"+tag+"\0]"
    });
  }

  array safe_tag(Parser.HTML p, mapping args,
                 string close_tags, mapping keep_attrs)
  {
    string tag = lower_case(p->tag_name());

    if(keep_attrs)
      args &= (keep_attrs[tag] || ({ }));

    return ({
      replace(
        RXML.t_xml->format_tag(
          tag, args, 0,
          (close_tags ? 0 : RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT)
        ),
        ({ "<",">" }), ({ "\0[","\0]" })
      ) // Replace
    });
  }

  string filter_body(string s, array keep_tags, array keep_containers,
                     string close_tags, string keep_attributes)
  {
    // Replace < and > with \1 and \2 instead of quoting with &lt; and &gt; to
    // be able regexp match on single characters.
    // \0 is used to keep allowed tags.
    s -= "\0";
    s -= "\1";
    s -= "\2";

    mapping keep_attrs;

    if (keep_attributes) {
      keep_attrs = ([ ]);
      foreach (keep_attributes/",", string entry) {
        if (sscanf(entry, "%s:%s", string tag, string attr) == 2)
          keep_attrs[tag] = (keep_attrs[tag] || ({ })) + ({ attr });
      }
    }

    Parser.HTML parser = Parser.HTML();
    parser->case_insensitive_tag(1);
    parser->set_extra(close_tags, keep_attrs);

    foreach (keep_tags, string tag)
      parser->add_tag(tag, safe_tag);

    foreach (keep_containers, string container)
      parser->add_container(container, safe_container);

    return replace(parser->finish(s)->read(),
                   ({ "<",  ">",  "&",     "\0[", "\0]" }),
                   ({ "\1", "\2", "&amp;", "<",   ">" }));
  }

  string linkify(string s, string|void target)
  {
    string fix_link(string l)
    {
      if (l[0..6] == "http://" || l[0..7] == "https://" || l[0..5] == "ftp://")
        return l;

      if (l[0..3] == "ftp.")
        return "ftp://"+l;

      return "http://"+l;
    };

    Parser.HTML parser = Parser.HTML();

    parser->add_container("a", lambda(Parser.HTML p, mapping args)
                               { return ({ p->current() }); });
    parser->_set_data_callback(
      lambda(Parser.HTML p, string data) {
        return ({
          utf8_to_string(link_regexp->replace(string_to_utf8(data),
            lambda(string link) {
              link = fix_link(link);
              return
                "<a href='" + link + "'" +
                (
                  target ? " " +
                    Roxen.make_tag_attributes((["target":target])) : ""
                ) + ">" + link + "</a>";
            }
          ))
        });
      }
    );

    return parser->finish(s)->read();
  }

  string remove_illegal_chars(string s)
  {
    string result = "";

    while (sizeof(s)) {
      string rest = "";
      sscanf(s, "%s%*[\x0-\x8\xb\xc\xe-\x1f\x7f-\x84\x86-\x9f]%s", s, rest);
      result += s;
      s = rest;
    }

    return result;
  }

  string unlinkify(string s)
  {
    string tag_a(string tag, mapping arg, string cont)
    {
      if (sizeof(arg) == 1 && arg->href == cont)
        return cont;
    };

    return parse_html(s, ([ ]), ([ "a":tag_a ]) );
  }

  string encode_nopara(string in, string nopara)
  {
    Parser.HTML parser = Parser.HTML();
    foreach (nopara/",", string np) {
      parser->add_container(np,
        lambda(Parser.HTML p, mapping args, string cntent) {
          string k = "\5nopara" + (passcnt++);
          encpasses[k] = Roxen.make_container(
            p->tag_name(), ([]),
            replace(String.trim_all_whites(cntent),
                    ({ "<", ">" }), ({ "&lt;", "&gt;" }))
          );
          return ({ k });
        }
      );
    }

    return parser->finish(in)->read();
  }

  string recode_nopara(string in)
  {
    foreach (encpasses; string k; string v)
      in = replace(in, k, v);

    return in;
  }

  mapping encpasses = ([]);
  int     passcnt   = 0;

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      encpasses = ([]);
      passcnt = 0;
      result = content||"";

      if (args->nopara)
        result = encode_nopara(result, args->nopara);

      if(args->unparagraphify)
        result = unparagraphify(result);

      if( args["unlinkify"] )
        result = unlinkify(result);

      if( !args["keep-all"] )
        result = filter_body(result,
                             parse_arg_array(args["keep-tags"]),
                             parse_arg_array(args["keep-containers"]),
                             args["close-tags"],
                             args["keep-attributes"]);

      if(args->paragraphify)
        result = paragraphify(result);

      if (args->nl2br)
        result = replace(result, "\n", "<br/>");

      if( args["linkify"] )
        result = linkify(result, args["link-target"]);

      if ( !args["keep-all"] )
        result = replace(result, ({ "\1", "\2" }), ({ "&lt;", "&gt;" }));

      if (args->nopara)
        result = recode_nopara(result);

      if( args["remove-illegal-xml-chars"] )
        result = remove_illegal_chars(result);

      sscanf(result, "&lt;%*s&gt;%s", result);

      if (args->cdata)
        result = "<![CDATA[" + result + "]]>";

      return 0;
    }
  }

  void create()
  {
    req_arg_types = ([]);
    opt_arg_types = ([ "keep-all":RXML.t_text(RXML.PXml),
                       "keep-tags":RXML.t_text(RXML.PXml),
                       "keep-containers":RXML.t_text(RXML.PXml),
                       "keep-attributes":RXML.t_text(RXML.PXml),
                       "paragraphify":RXML.t_text(RXML.PXml),
                       "unparagraphify":RXML.t_text(RXML.PXml),
                       "linkify":RXML.t_text(RXML.PXml),
                       "link-target":RXML.t_text(RXML.PXml),
                       "unlinkify":RXML.t_text(RXML.PXml),
                       "close-tags":RXML.t_text(RXML.PXml) ]);

#define L_VALID_CHARS "[^][ \t\n\r<>\"'`(){}|\1\2]"
    link_regexp =
      Regexp("(((http)|(https)|(ftp))://(" L_VALID_CHARS "+)(\\." L_VALID_CHARS "+)+)|"
             "(((www)|(ftp))(\\." L_VALID_CHARS "+)+)");
  }
}

class TagVcalendar
{
  inherit RXML.Tag;
  constant name = "vcalendar";

  mapping(string:RXML.Type) req_arg_types = ([
    "from-date" : RXML.t_text(RXML.PEnt),
    "to-date"   : RXML.t_text(RXML.PEnt),
    "summary"   : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "filename"    : RXML.t_text(RXML.PEnt),
    "location"    : RXML.t_text(RXML.PEnt),
    "description" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      string vcal =
      "BEGIN:VCALENDAR\n"
      "VERSION:1.0\n"
      "BEGIN:VEVENT\n"
      "CLASS:PRIVATE\n"
      "SUMMARY;CHARSET=ISO-8859-15:%s\n"
      "LOCATION;CHARSET=ISO-8859-15:%s\n"
      "DESCRIPTION;CHARSET=ISO-8859-15:%s\n"
      "DTSTART:%s\n"
      "DTEND:%s\n"
      "END:VEVENT\n"
      "END:VCALENDAR";

      Calendar.Second fdate = Calendar.parse( "%Y-%M-%D%[ T]%h:%m",
                                              args["from-date"] );
      Calendar.Second tdate = Calendar.parse( "%Y-%M-%D%[ T]%h:%m",
                                              args["to-date"] );
      fdate = fdate && (fdate->hour()-1);
      tdate = tdate && (tdate->hour()-1);

      catch(args->description = string_to_utf8(args->description));
      result = sprintf(vcal,
        args->summary,
        args->location||"",
        args->description||"",
        fdate->format_iso_short()-"-"-":"+"Z",
        tdate->format_iso_short()-"-"-":"+"Z"
      );

      mapping headers = ([
        "Content-Type"        : "text/calendar",
        "Content-Length"      : (string)sizeof(result),
        "Content-Disposition" : "attachment; "
                                "filename=\"" + (args->filename||"calendar") +
                                ".ics\""
      ]);

      RXML_CONTEXT->extend_scope("header", headers);
    }
  }
}

class TagIsSetOr
{
  inherit RXML.Tag;
  constant name = "issetor";

  mapping(string:RXML.Type) req_arg_types = ([
    "a" : RXML.t_text(RXML.PXml),
    "b" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = sizeof(args->a) ? args->a : args->b;
    }
  }
}
class TagEmitAttachment
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "attachment";

  mapping(string:RXML.Type) req_arg_types = ([
    "prefix"  : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([]);

  array get_dataset(mapping args, RequestID id)
  {
    string pf = args->prefix;
    array(mapping) res = ({});

    foreach (id->real_variables; string key; array value) {
      if ((sscanf(key, pf+"%*d.%*s") == 1)) {
        mixed e = catch {
          res += ({
            ([ "content"  : value[0],
               "mimetype" : id->real_variables[key+".mimetype"][0],
               "filename" : id->real_variables[key+".filename"][0],
               "length"   : sizeof(value[0])
            ])
          });
        };

        if (e) {
          TRACE("Unable to handle %s! %s\n", key, describe_error(e));
        }
      }
    }

    return res;
  }
}

class TagEmitGroupedKeywords
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "grouped-keywords";

  mapping(string:RXML.Type) req_arg_types = ([
    "variable"  : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([]);

  array get_dataset(mapping args, RequestID id)
  {
    array(mapping(string:array)) res = ({});
    mapping(string:array) tmp = ([]);
    array(mapping(string:string)) data = RXML.user_get_var(args->variable);

    foreach (data, mapping v) {
      string t = lower_case(v->title);
      if ( !tmp[t] )
        tmp[t] = ({});

      tmp[t] += ({ v->path });
    }

    foreach (tmp; string k; array v) {
      res += ({
        ([ "index" : upper_case( k[0..0] ) + k[1..],
           "value" : v ])
      });
    }

    return res;
  }
}

class TagMonthName
{
  inherit RXML.Tag;
  constant name = "month-name";

  mapping(string:RXML.Type) opt_arg_types = ([
    "variable" : RXML.t_text(RXML.PXml),
    "value" : RXML.t_text(RXML.PXml),
    "lang" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      string v = args->value || String.trim_all_whites(content);
      v = "2012-" + v + "-01";

      //werror ("\nGet month name: %s: %O\n", v, sort(indices(id)));
      string lang = args->lang || id->request_headers["accept-language"];
      if (lang) lang = (lang/",")[0];

      mixed e = catch {
        Calendar.Calendar cal = Calendar.ISO_UTC;
        if (lang) cal = cal->set_language (lang);
        Calendar.Day d = cal->parse("%Y-%M-%D", v);

        if (!d) RXML.run_error("Unable to parse date %O\n", v);
        if (args->variable)
          RXML.user_set_var(args->variable, d->month_name());
        else
          result = d->month_name();
      };

      if (e) report_error ("Unhandled data: %s\n", describe_backtrace(e));

      return 0;
    }
  }
}

void create(Configuration _conf)
{
  conf = _conf;
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");
}

void start(int when, Configuration _conf)
{
}
