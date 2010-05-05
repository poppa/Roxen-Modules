// This is a Roxen® module
//
// Misc utility tags
// Author: Pontus Östlund <pontus@poppa.se>
//
// Tab width: 8
// Indent width: 2

//#define UTILS_DEBUG

#include <config.h>
#include <module.h>
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "TVAB Tags: Utility tags";
constant module_doc  = "Misc. tags from Tekniska Verken!";

Configuration conf;

#ifdef TAGS_DEBUG
# define TRACE(X...) report_debug(X)
#else
# define TRACE(X...) 0
#endif

class TagNl2br // {{{ 
{
  inherit RXML.Tag;
  constant name = "nl2br";
  class Frame 
  {
    inherit RXML.Frame;
    array do_return(RequestID id) 
    {
      result = content || "";
      result = replace(replace(result, "\r\n", "\n"), "\n", "<br/>");
      return 0;
    }
  }
} // }}}

class TagEmpty // {{{ 
{
  inherit RXML.Tag;
  constant name = "empty";

  mapping(string:RXML.Type) req_arg_types = ([
    "tag" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id) 
    {
      string t = args->tag;
      m_delete(args, "tag");
      result = Roxen.make_container(t, args, "");
      return 0;
    }
  }
} // }}}

class TagShorten // {{{ 
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
      if (sizeof(content) <= len) {
	result = content;
	return 0;
      }

      string cont = replace(content, ({ "\r\n","\r","\n" }), ({ " "," "," " }));
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
} // }}}

class TagBase64 // {{{ 
{
  inherit RXML.Tag;
  constant name = "base64";
  
  mapping(string:RXML.Type) opt_arg_types = ([
    "encode" : RXML.t_text(RXML.PEnt),
    "decode" : RXML.t_text(RXML.PEnt)
  ]);
  
  class Frame 
  {
    inherit RXML.Frame;
    array do_return(RequestID id) 
    {
      if (args->decode) 
	result = MIME.decode_base64(content);
      else
	result = MIME.encode_base64(content);
      return 0;
    }
  }
} // }}}

class TagSafeJS // {{{ 
{
  inherit RXML.Tag;
  constant name = "safe-js";
  
  class Frame 
  {
    inherit RXML.Frame;
    array do_return(RequestID id) 
    {
      result = content && String.trim_all_whites(content) || "";
      result = replace(result, ({ "&lt;", "&gt;", "&amp;" }),
			       ({ "<",    ">",    "&"     })); 
      result = "\n<script type='text/javascript'>\n//<![CDATA[\n" + result + 
               "\n//]]>\n</script>\n";
      return 0;
    }
  }
} // }}}

class TagMD5 // {{{ 
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
} // }}}

string md5(string in)
{
#if constant(Crypto.MD5)
  return String.string2hex(Crypto.MD5.hash(in));
#else
  return Crypto.string_to_hex(Crypto.md5()->update(in)->digest());
#endif
}

/*
class TagRandomString // {{{
{
  inherit RXML.Tag;
  constant name = "random-string";
  
  mapping(string:RXML.Type) req_arg_types = ([
    "length"      : RXML.t_text(RXML.PEnt)
  ]);
  
  mapping(string:RXML.Type) opt_arg_types = ([
    "alpha"       : RXML.t_text(RXML.PEnt),
    "number"      : RXML.t_text(RXML.PEnt),
    "punctuation" : RXML.t_text(RXML.PEnt),
    "lowercase"   : RXML.t_text(RXML.PEnt),
    "uppercase"   : RXML.t_text(RXML.PEnt),
    "exclude"     : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      if ((int)args->length < 1)
	RXML.parse_error("Argument length must at least be 1", id);

      int flags = 0, cases = 0;

      if (args->alpha)       flags  = Utils.ALPHA;
      if (args->number)      flags |= Utils.NUMBER;
      if (args->punctuation) flags |= Utils.PUNCTUATION;
      if (!flags)            flags  = Utils.ALPHA|Utils.NUMBER;
      if (args->lowercase)   cases  = Utils.LOWERCASE;
      if (args->uppercase)   cases |= Utils.UPPERCASE;
      if (!cases)            cases  = Utils.LOWERCASE|Utils.UPPERCASE;

      result = Utils.random_string((int)args->length, flags, cases,
                                   args->exclude||0);
      return 0;
    }
  }
} // }}}
*/

class TagPadINT // {{{
// Lägger till separator i långa tal. Ex:
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
} // }}}

class TagWordWrap // {{{ 
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
} // }}}

class TagUtf8 // {{{ 
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
      else if(args->decode)
	catch (result = utf8_to_string(args->data||content));

      return 0;
    }
  }
} // }}}

class TagZeroPad // {{{
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
} // }}}

class TagSleep // {{{
{
  inherit RXML.Tag;
  constant name = "sleep";
  mapping(string:RXML.Type) opt_arg_types = ([ 
    "seconds" : RXML.t_text(RXML.PXml)
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      
      int timeout = 0;
      if (args->seconds)
	timeout = (int)args->seconds;
      else if (args->minutes)
	timeout = ((int)args->minutes)*60;

      sleep(timeout);
      return 0;
    }
  }
} // }}}

class TagGetUniqueComponentID // {{{
/* Om vi skapar egna "editor"-sidor genom sb-edit-area och lägger in
 * komponenter kan vi anropa denna tagg för att få ett ID att lägga i
 * id-taggen för komponenten:
 *
 * <my-component>
 *   <id><get-unique-component-id /></id>
 *   <variant>0</variant>
 *   <!-- ... -->
 * </my-component>
*/
{
  inherit RXML.Tag;
  constant name = "get-unique-component-id";

  mapping(string:RXML.Type) req_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = Sitebuilder.Editor.get_unique_component_id();
      return 0;
    }
  }
} // }}}

class TagGetUniqComponentID // {{{
{
  inherit TagGetUniqueComponentID;
  constant name = "get-uniq-component-id";
} // }}}

class TagSwapProtocol // {{{ 
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
} // }}}

class TagNiceSize // {{{
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
} // }}}

class TagStripTags // {{{
// A copy of html_wash.pike except this can take defines of tags to not 
// paragraphify when paragraphify is being used.
{
  inherit RXML.Tag;
  constant name = "strip-tags";
  Regexp link_regexp;

  string paragraphify(string s)
  {
    // more than one newline is considered a new paragraph
    return
      "<p>"+ ((
	replace(
	  replace(s - "\r" - "\0", "\n\n", "\0"),
	  "\0\n", "\0"
	)/"\0") - ({ "\n", "" })
      )*("</p><p>") + "</p>";
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
    string res = parser->finish(cont)->read();
    
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
    // Replace < and > with \1 and \2 in stead of quoting with &lt; and &gt; to
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
} // }}}

class TagAQuery // {{{
{
  inherit RXML.Tag;
  constant name = "a-query";

  mapping(string:RXML.Type) req_arg_types = ([
    "name"  : RXML.t_text(RXML.PEnt),
    "value"  : RXML.t_text(RXML.PEnt),
  ]);
  
  mapping(string:RXML.Type) opt_arg_types = ([
    "toggle" : RXML.t_text(RXML.PEnt),
    "toggle-text" : RXML.t_text(RXML.PEnt),
    "add-class" : RXML.t_text(RXML.PEnt),
    "wrap" : RXML.t_text(RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      array(string)tmp = ({});
      int(0..1) isset = 0;
      int(0..1) toggle = 0;

      foreach ((id->query||"")/"&", string p) {
	sscanf(p, "%s=%s", string k, string v);
	if (k == args->name) {
	  isset = 1;
	  if (args->toggle && v != args->toggle) {
	    v = args->toggle;
	    toggle = 1;
	  }
	  else
	    v = args->value;
	}
	if (k && v && sizeof(v))
	  tmp += ({ sprintf("%s=%s", k, v) });
      }

      string out = tmp*"&";

      if (!isset) {
	if (sizeof(out)) out += "&";
	out += sprintf("%s=%s", args->name, args->value);
      }
      else {
      	werror("Isset is true: %O\n", out);
      }

      if (sizeof(out))
	out = "?" + out;

      if (toggle) {
      	if (args->wrap) 
      	  content = sprintf( "<%s>%s</%[0]s>", args->wrap,args["toggle-text"] );
      	else
	  content = args["toggle-text"];
      }

      
      if ( args["add-class"] && toggle) {
      	if ( args["class"] )
      	  args["class"] += " " + args["add-class"] ;
      	else
      	  args["class"] = args["add-class"];
      }
      
      string href = args->href;
      m_delete(args, "name");
      m_delete(args, "value");
      m_delete(args, "href");
      m_delete(args, "wrap");
      m_delete(args, "toggle");
      m_delete(args, "toggle-text");
      m_delete(args, "add-class");

      result = sprintf("<a href='%s%s'%{ %s='%s'%}>%s</a>", 
                       id->not_query, out, (array)args, content);
      return 0;
    }
  }
} // }}}

void create(Configuration _conf) // {{{
{
  conf = _conf;
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");
} // }}}

void start(int when, Configuration _conf) // {{{
{
} // }}}

