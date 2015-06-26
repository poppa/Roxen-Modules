// This is a Roxen® module
// Based on the original tablify.pike
//
// Author: Pontus Östlund <pontus@poppa.se>
//
// Tab width:    8
// Indent width: 2

#charset utf-8
#include <module.h>
inherit "module";

//#define MARKDOWN_DEBUG

#ifdef MARKDOWN_DEBUG
# define TRACE(X...) werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe   = 1;
//constant module_unique = 1;
constant module_type   = MODULE_TAG;
constant module_name   = "Poppa Tags: Markdown";
constant module_doc    =
#"This module provides the <tt>&lt;markdown&gt;</tt> tag that is used to
generate HTML from Markdown text";

// create
void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus Östlund (with a little help from some original "
                     "Roxen modules) <poppanator@gmail.com>");
} // }}}

// start
void start(int when, Configuration _conf) {}

class TagMarkdown
{
  inherit RXML.Tag;
  constant name = "markdown";

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
      result = Markdown.transform(content);

      return 0;
    }
  }
}