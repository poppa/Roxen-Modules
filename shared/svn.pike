// NOTE: Very much work in progress

#include <module.h>
inherit "module";
inherit "roxenlib";

import Parser.XML.Tree;

#define POPPA_DEBUG

#define _ok RXML_CONTEXT->misc[" _ok"]

#ifdef POPPA_DEBUG
# define TRACE(X...) report_debug("SVN: " + sprintf(X))
#else
# define TRACE(X...)
#endif

#define EMPTY(X) (!((X) && sizeof((X))))
#define IS_SET_OR(X, Y) (((X) && sizeof((X)) && (X)) || Y)

import RC.SVN;

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Subversion";
constant module_doc  = "Subverion ... ";

Configuration conf;

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus Östlund <pontus@poppa.se>");
  conf = _conf;
} // }}}

void start(int when, Configuration _conf) // {{{
{
} // }}}

//! Add a new TimeTrack
class TagSvnInit // {{{
{
  inherit RXML.Tag;
  constant name = "svn-init";

  mapping(string:RXML.Type) req_arg_types = ([
   "repository" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
   "username" : RXML.t_text(RXML.PEnt),
   "password" : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      set_repository_base( args["repository"] );
      return 0;
    }
  }
} // }}}

//! Add a new TimeTrack
class TagSvnBasePath // {{{
{
  inherit RXML.Tag;
  constant name = "svn-base-path";

  mapping(string:RXML.Type) req_arg_types = ([]);
  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = get_repository_base();
      return 0;
    }
  }
} // }}}

//! Add a new TimeTrack
class TagSvnParent // {{{
{
  inherit RXML.Tag;
  constant name = "svn-parent";

  mapping(string:RXML.Type) req_arg_types = ([
    "path" : RXML.t_text(RXML.PEnt),
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (args->path[-1] == '/')
      	args->path = args->path[..sizeof(args->path)-2];

      result = dirname(args->path);
      return 0;
    }
  }
} // }}}

//! Add a new TimeTrack
class TagSvnCat // {{{
{
  inherit RXML.Tag;
  constant name = "svn-cat";

  mapping(string:RXML.Type) req_arg_types = ([
    "path" : RXML.t_text(RXML.PEnt),
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "revision"  : RXML.t_text(RXML.PEnt),
    "highlight" : RXML.t_text(RXML.PEnt),
    "tabsize"   : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if (EMPTY(args->path))
      	RXML.parse_error("\"path\" can not be empty!");

      Cat cat = Cat(args->path, IS_SET_OR(args->revision, 0));
      if (string res = cat->get_contents()) {
      	string t = resolve_filetype(args->path, res);
      	
      	if (is_binary(res)) {
      	  if (is_image(t)) {
      	    RXML.user_set_var("var.is-image", "1");
      	    RXML.user_set_var("var.img-type", t);
      	    result = res;
      	    return 0;
      	  }
      	  RXML.user_set_var("var.is-binary", "1");
      	  result = "This file is binary!";
      	  return 0;
      	}
      	
      	if (String.width(res) == 8)
      	  res = utf8_to_string(res);
      	
      	if (is_plaintext(t)) {
      	  RXML.user_set_var("var.is-plaintext", "1");
      	  result = res;
      	  return 0;
      	}

      	if (t && args->highlight) {
	  Syntaxer.Hilite parser = Syntaxer.get_parser(t);
	  parser->tabsize = args->tabsize && (int)args->tabsize||8;
	  res = parser->parse(res);
      	}
      	result = res;
      }
      return 0;
    }
  }
} // }}}

class TagEmitSvnCat // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "svn-cat";

  mapping(string:RXML.Type) req_arg_types = ([
    "path" : RXML.t_text(RXML.PEnt),
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "revision" : RXML.t_text(RXML.PEnt),
    "highlight" : RXML.t_text(RXML.PEnt),
    "tabsize"   : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    Cat cat = Cat(args->path, IS_SET_OR(args->revision, 0));
    string kind, colored_source;
    string res = cat->get_contents();
    string t = resolve_filetype(args->path, res);

    if (is_binary(res))
      kind = is_image(t) ? "image" : "binary";
    else {
      if (String.width(res) == 8)
	catch(res = utf8_to_string(res));

      if (is_plaintext(t))
      	kind = "plaintext";
      else if (args->highlight) {
      	kind = "source";
      }
      Syntaxer.Hilite parser = Syntaxer.get_parser(t);
      parser->tabsize = args->tabsize && (int)args->tabsize||8;
      colored_source = parser->parse(res);
    }

    mapping out = ([
      "type"           : t,
      "kind"           : kind,
      "source"         : res,
      "colored-source" : colored_source
    ]);

    return ({ out });
  }
} // }}}

class TagIfSvnIsFile // {{{ 
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "svn-is-file";

  int eval(string path, RequestID id, mapping m) 
  {
    return !EMPTY(path) && Info(path)->get_type() == "file";
  }
} // }}}

class TagEmitSvnLog // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "svn-log";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "path"     : RXML.t_text(RXML.PEnt),
    "revision" : RXML.t_text(RXML.PEnt),
    "verbose"  : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    array flags = ({});
    if (args->maxrows)
      flags += ({ "-l", args->maxrows });
    if (args->verbose)
      flags += ({ "-v" });

    //TRACE("Log: %O, %O, %O\n", args->revision, IS_SET_OR(args->path, 0), flags);
    
    Log svnlog = Log((int)args->revision, IS_SET_OR(args->path, 0), @flags);

    array(mapping(string:string)) out = ({});
    foreach (values(svnlog), Log.Entry entry) {
      out += ({ ([
      	"author"   : entry->get_author(),
      	"date"     : entry->get_date()->format_mtime(),
      	"message"  : entry->get_message(),
      	"revision" : (string)entry->get_revision(),
      	"paths"    : entry->get_paths()
      ]) });
    }

    return out;
  }
} // }}}

class TagEmitSvnInfo // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "svn-info";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "path"     : RXML.t_text(RXML.PEnt),
    "revision" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    Info info = Info(IS_SET_OR(args->path, 0), args->revision);
    string ipath = info->get_url()[sizeof(get_repository_base())-1..];
    array(mapping(string:string)) out =  ({ ([
      "author"        : info->get_author(),
      "date"          : info->get_date()->format_mtime(),
      "type"          : info->get_type(),
      "url"           : info->get_url(),
      "uuid"          : info->get_uuid(),
      "root"          : info->get_root(),
      "internal-path" : ipath,
      "revision"      : (string)info->get_revision()
    ]) });

    return out;
  }
} // }}}

class TagEmitSvnDiff // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "svn-diff";

  mapping(string:RXML.Type) req_arg_types = ([
    "path" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "revision-a" : RXML.t_text(RXML.PEnt),
    "revision-b" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    if (EMPTY(args->path))
      RXML.parse_error("\"path\" must not be empty!");

    Diff diff;
    // Most likely if an error occures we're trying to diff on a file with
    // only one revision
    mixed e = catch {
      diff = Diff(IS_SET_OR(args->path, 0), 
                  IS_SET_OR(args["revision-a"], 0),
                  IS_SET_OR(args["revision-b"], 0));
    };

    if (e) {
      TRACE("Error in diff: %s\n", describe_backtrace(e));
      return ({});
    }

    array(mapping(string:mixed)) out =  ({});

    foreach (values(diff), Diff.Index idx) {
      array(mapping) p = ({});
      foreach (values(idx), string line) {
      	string t = line[0..0];
      	p += ({ ([
	  "type" : t,
	  "line" : replace(line, ({ "\t" }), ({ "  "*2 }))
	]) });
      }

      out += ({ ([ "value" : p, "path" : idx->get_path() ]) });
    }

    return out;
  }
} // }}}

class TagEmitSvnDiffTable // {{{
{
  inherit TagEmitSvnDiff;
  constant plugin_name = "svn-diff-table";

  array get_dataset(mapping args, RequestID id)
  {
    if (EMPTY(args->path))
      RXML.parse_error("\"path\" must not be empty!");

    Diff diff;
    // Most likely if an error occures we're trying to diff on a file with
    // only one revision
    mixed e = catch {
      diff = Diff(IS_SET_OR(args->path, 0), 
                  IS_SET_OR(args["revision-a"], 0),
                  IS_SET_OR(args["revision-b"], 0));
    };

    if (e) {
      TRACE("Error in diff: %s\n", describe_error(e));
      return ({});
    }

    array(mapping(string:mapping)) out =  ({});

    [array old, array new] = Diff.table(diff);

    for (int i; i < sizeof(old); i++)
      out += ({([ "old" : old[i], "new" : new[i] ])});

    return out;
  }
} // }}}

class TagEmitSvnLs // {{{
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "svn-ls";

  mapping(string:RXML.Type) req_arg_types = ([
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "path" : RXML.t_text(RXML.PEnt)
  ]);

  array get_dataset(mapping args, RequestID id)
  {
    string path = args->path && sizeof(args->path) && args->path;
    List ls = List(path);
    string base = ls->get_path();
    array(mapping(string:string)) out = ({});
    foreach (values(ls), object /* List.Dir|List.File */ entry) {
      int(0..1) has_size = entry->get_type() == "file";
      out += ({ ([
      	"base"     : base,
	"name"     : entry->get_name(),
	"type"     : entry->get_type(),
	"size"     : has_size ? (string)entry->get_size() : "0",
	"nicesize" : has_size ? Roxen.sizetostring(entry->get_size()) : "0",
	"revision" : entry->get_revision(),
	"author"   : entry->get_author(),
	"date"     : entry->get_date()->format_mtime()
      ]) });
    }

    return out;
  }
} // }}}

int(0..1) is_binary(string contents, void|int limit, void|int check_len)
{
  int bins = 0;
  int clen = sizeof(contents);
  limit = limit||5;
  check_len = check_len||100;
  check_len = clen < check_len ? clen : check_len;

  for (int i = 0; i < check_len; i++) {
    if (contents[i] == '\0')
      bins++;

    if (bins >= limit)
      return 1;
  }

  return 0;
}

int(0..1) is_plaintext(string type)
{
  return (< "txt" >)[lower_case(type)];
}

int(0..1) is_image(string type)
{
  return (< "png", "gif", "jpg", "jpeg" >)[lower_case(type)];
}

string resolve_filetype(string filename, string contents)
{
  if (filename && sizeof(filename) && search(filename, ".") > -1) {
    string t = lower_case( reverse(basename(filename)/".")[0] );
    if (t && lower_case(t) == "jpg")
      t = "jpeg";
    return t;
  }
  else if (contents && sizeof(contents)) {
    if (sscanf(contents, "#!%s\n", string shebang) > 0) {
      if (search(shebang, "/") > -1) {
      	if (search(shebang, "/env") > 0) {
      	  sscanf(shebang, "%*s/env %s", shebang);
      	  return shebang;
      	}

      	if (search(shebang, " ") > -1)
      	  sscanf(shebang, "%s ", shebang);

      	sscanf(reverse(shebang), "%s/", shebang);
      	return shebang;
      }
      else
      	return shebang;
    }
  }
}
