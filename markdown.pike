#charset utf-8

#include <config.h>
#include <module.h>
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Markdown";
constant module_doc  = #"Maybe later";

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <pontus@roxen.com>");
}

void start(int when, Configuration _conf){}

class TagMarkdown
{
  inherit RXML.Tag;
  constant name = "markdown";

  mapping(string:RXML.Type) req_arg_types = ([]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "trim"        : RXML.t_text(RXML.PEnt),
    "newline"     : RXML.t_text(RXML.PEnt),
    "smartypants" : RXML.t_text(RXML.PEnt),
    "highlight"   : RXML.t_text(RXML.PEnt),
    "basedir"     : RXML.t_text(RXML.PEnt)
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
#if constant(Parser.Markdown.Marked)

      string c = content;
      mapping options = ([]);

      if (args->trim) {
        c = String.trim_all_whites(c);
      }

      if (args->newline) {
        options->newline = (< "", "1", "yes", "true" >)[args->newline];
      }

      if (args->smartypants) {
        options->smartypants = true;
      }

#if constant(Tools.Standalone.pike_to_html)

      Tools.Standalone.pike_to_html pike_hilighter;
      pike_hilighter = Tools.Standalone.pike_to_html();

      if (args->highlight) {
        options->highlight = lambda (string code, string lang) {
          if (lang && lang == "pike") {
            return pike_hilighter->convert(code);
          }
          else if (lang && lang == "hilfe") {
            return highlight_hilfe(code, pike_hilighter);
          }
          return code;
        };
      }

#endif

      result = utf8_to_string(Parser.Markdown.marked(content, options));

      if (args->basedir) {
        Parser.HTML pp = Parser.HTML();
        pp->add_tags(([
          "img" : lambda (Parser.HTML p, mapping attr) {
            if (attr->src) {
              attr->src = combine_path(args->basedir, attr->src);
              return ({ Roxen.make_tag("img", attr)  });
            }
          }
        ]));

        result = pp->feed(result)->finish()->read();
      }

#else
      RXML.parse_error("Module Parser.Markdown.Marked not available in this "
                       "Pike installation.");
#endif

      return 0;
    }
  }
}

string highlight_hilfe(string s, Tools.Standalone.pike_to_html ph)
{
  array(string) lines = replace(s, ([ "\r\n" : "\n", "\r" : "\n" ]))/"\n";
  array(string) out = ({});

  foreach (lines, string line) {
    if (sscanf(line, "%[ \t]>%s", string prefix, string code) == 2) {
      if (sizeof(code)) {
        prefix += "&gt;";
        if ((< ' ', '\t' >)[code[0]]) {
          sscanf(code, "%[ \t]%s", string prefix2, code);
          prefix += prefix2;
        }
        code = ph->convert(code);
        if (code[-1] == '\n')
          code = code[..<1];
        line = sprintf("<span class='input'>%s<span class='code'>%s</span></span>", prefix, code);
      }
      else {
        continue;
      }
    }
    else {
      line = sprintf("<span class='output'>%s</span>", line);
    }

    out += ({ line });
  }

  return out * "\n";
}
