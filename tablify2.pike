// This is a Roxen® module
// Based on the original tablify.pike
//
// Author: Pontus Östlund <pontus@poppa.se>
//
// Tab width:    8
// Indent width: 2

// {{{ HEAD
#charset utf-8
#include <module.h>
inherit "module";

//#define TABLIFY2_DEBUG

#ifdef TABLIFY2_DEBUG
# define TRACE(X...) report_debug("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe   = 1;
//constant module_unique = 1;
constant module_type   = MODULE_TAG;
constant module_name   = "TVAB Tags: Tablify2";
constant module_doc    =
#"This module provides the <tt>&lt;tablify2&gt;</tt> tag that is used to
generate tables from CSV/TSV data.";

// Default argument values
constant _opts = ([
  "rowseparator"     : "\n",
  "cellseparator"    : "\t",
  "interactive-sort" : 0,
  "notitle"          : 0,
  "sortcol"          : 0,
  "squeeze"          : 0, // Squezees consecutive cell separators into one cell
  "head-class"       : 0, // Applies to the tr in thead
  "head-style"       : 0,
  "odd-row-class"    : 0,
  "even-row-class"   : 0,
  "odd-row-style"    : 0,
  "even-row-style"   : 0,
  "last-row-style"   : 0,
  "last-row-class"   : 0,
  "last-cell-class"  : 0,
  "last-cell-style"  : 0,
  "first-cell-class" : 0,
  "first-cell-style" : 0,
  "sort-asc-img"     : "/internal-roxen-sort-asc",
  "sort-desc-img"    : "/internal-roxen-sort-desc",
  "numstyle"         : "color:blue;text-align:right",
  "neg-numstyle"     : "color:red;text-align:right",
  "numclass"         : 0,
  "neg-numclass"     : 0,
  // NOTE: When title-font is set all gtext-arguments will apply if they are
  // prefixed with "title-".
  "title-font"       : 0,
  "title-fontsize"   : "12",
  "title-bgcolor"    : "#112266",
  "title-fgcolor"    : "#FFFFFF",
  "no-escape"        : 0, // Don't HTML encode cell content
  "linkify"          : 0,
  "allow-html"       : 0,
  "modulo"           : "1",
  "row-titles"       : 0,
  "caption"          : 0,
  "nosort"           : 0,
  "pager"            : 0,
  "pager-before"     : 0,
  "no-pager-after"   : 0,
  "pagervar"         : 0,
  "append-query"     : 0,
  "sum"              : 0, // Sum numeric columns
  // Url for dynamically created links, like interactive sort and pager.
  // index.xml is default.
  "url"              : 0
]);

// Valid attributes for the table tag
constant _tblargs = ({
  "cellspacing",
  "cellpadding",
  "border",
  "summary",
  "width",
  "frame",
  "rules",
  "height"
});

// Standard HTML attributes
constant _commonargs = ({
  "id",
  "lang",
  "title",
  "onclick",
  "ondbclick",
  "onmousedown",
  "onmouseup",
  "onmouseover",
  "onmousemove",
  "onmouseout",
  "onkeypress",
  "onkeydown",
  "onkeyup",
  "style",
  "class",
  "align", // deprecated according to w3c
  "bgcolor"
});

// Allowed alignments
constant _aligns = (< "left", "center", "right" >);

// Allowed column types
constant _types  = (< "text", "int", "float", "economic-int",
                      "economic-float", "num" >);

constant FLOAT_COLS = (< "float", "economic-float" >);
constant INT_COLS   = (< "int", "economic-int", "num" >);
constant NUM_COLS   = FLOAT_COLS + INT_COLS;

#define EMPTY_CELL "&#160;"

// Valid chars for matching linkable strings. From html_wash.pike
#define VALID_CHARS "[^][ \t\n\r<>\"'`(){}|\1\2]"
// This is some what ugly ;)
#define EMAIL_RE "[a-zA-Z.-_]+@[a-zA-Z.-_]+\.[a-zA-Z]"
#if constant(Regexp.PCRE)
object(Regexp.PCRE)
RELINK = Regexp.PCRE("(((http)|(https)|(ftp))://(" VALID_CHARS "+)"
                     "(\\." VALID_CHARS "+)+)|"
                     "(((www)|(ftp))(\\." VALID_CHARS "+)+)|"
                     "(" + EMAIL_RE + ")");
#else
object(Regexp)
RELINK = Regexp("(((http)|(https)|(ftp))://(" VALID_CHARS "+)"
                "(\\." VALID_CHARS "+)+)|"
                "(((www)|(ftp))(\\." VALID_CHARS "+)+)|"
                "(" + EMAIL_RE + ")");
#endif

// Allowed containers in cell data
// Pretty much all tags except table related and none body.
array _cont = ({
  "a",          "abbr",       "acronym",    "address",    "b",         "bdo",
  "big",        "blockquote", "cite",       "code",       "dd",        "del",
  "div",        "dfn",        "dl",         "dt",         "em",        "form",
  "h1",         "h2",         "h3",         "h4",         "h5",        "h6",
  "i",          "iframe",     "input",      "ins",        "kbd",       "label",
  "li",         "ol",         "option",     "p",          "pre",       "q",
  "samp",      "script",      "select",     "small",      "span",      "strong",
  "sub",       "sup",         "textarea",   "tt",         "u",         "ul",
  "var"
});

// Allowed tags in cell data
array _tags = ({ "br", "button", "hr", "img", "input" });

// }}}

// create
void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus Östlund (with a little help from some original "
                     "Roxen modules) <pontus@poppa.se>");
} // }}}

// start
void start(int when, Configuration _conf) {}

class PageState // {{{
{
  inherit StateHandler.Page_state;

  // Pretty much copied from StateHandler.Page_state
  // ([server-x.y.z]/etc/modules/StateHandler.pmod)
  string encode_revisit_url(RequestID id, mixed value,
                            void|string|array key, void|string var,
                            void|string url)
  {
    string other_vars;
    url = url || (id->not_query/"/")[-1];

    if (id->query) {
      other_vars = "&" + id->query;
      int i = search (other_vars, "&__state=");
      if (i >= 0) {
        int j = search (other_vars, "&", i + 1);
        other_vars = other_vars[..i - 1] + (j > 0 ? other_vars[j..] : "");
      }
    }
    else other_vars = "";

    return url +
      "?" + (var || "__state") + "=" + uri_encode(value, key) + other_vars;
  }
} // }}}

class TagTablify2
{
  inherit RXML.Tag;
  constant name = "tablify2";

  // Callback for parse_html where we setup the alignment rule
  string _align(string tag, mapping arg, string data, mapping args) // {{{
  {
    array align = map(data/args->rowseparator,
      lambda(string row) {
        return map(row/(arg->split||" "),
          lambda(string cell) {
            cell = String.trim_all_whites(cell);
            if (args->squeeze && cell == "")
              return;

            return _aligns[cell] ? cell : "left";
          }
        );
      }
    );

    args->align = align && align[0]-({ 0 });

    return "";
  } // }}}

  // Callback for the <type/> tag.
  string _type(string tag, mapping arg, string data, mapping args) // {{{
  {
    array type = map(data/args->rowseparator,
      lambda(string row) {
        return map(row/(arg->split||" "),
          lambda(string cell) {
            cell = String.trim_all_whites(cell);
            if (args->squeeze && cell == "") return;
            return _types[cell] ? cell : "text";
          }
        );
      }
    );

    args->coltype = type && type[0]-({ 0 });

    return "";
  } // }}}

  // Callback for the <caption/> tag.
  string _caption(string tag, mapping arg, string data, mapping args) // {{{
  {
    TRACE("Found caption tag: %s\n", data||"");
    args->caption = data;
    return "";
  } // }}}

  string _tfoot(string tag, mapping arg, string data, mapping args) // {{{
  {
    TRACE("Found tfoot tag\n");
    args->tfoot = Roxen.make_container("tfoot", arg, data);
    return "";
  } // }}}

  string _tbody(string tag, mapping arg, string data, mapping args) // {{{
  {
    TRACE("Found tbody tag\n");
    args->tbody = Roxen.make_container("tbody", arg, data);
    return "";
  } // }}}

  // Checks if argument is set and if not returns the default from _opts
  mixed isarg(mapping args, string key) // {{{
  {
    return ( args[key] ? args[key] : _opts[key] );
  } // }}}

  // Create the sorting arrow in interactive mode
  string get_arrow(string order, mapping args) // {{{
  {
    string arrow = isarg(args, "sort-" + order + "-img");
    return "<img src='" + arrow + "' alt='" + order + "' title='' "
           "style='margin-left: 5px' />";
  } // }}}

  // If a key in args exists as an index in the reference array it's okey to
  // use as an html tag attribute
  mapping set_attr_args(array ref, mapping args) // {{{
  {
    mapping out = ([]);
    foreach (ref, string k)
      if ( args[k] )
        out[k] = args[k];

    return out;
  } // }}}

  // Creates a string of html tag attributes
  // We could use Roxen.make_tag_attributes() but since we can have integers
  // as values from the _opts mapping that will cause an internal server error
  // so we use this instead.
  string mk_attr(mapping m) // {{{
  {
    string s = "";
    foreach (m; string k; string v)
      if (v && stringp(v) && sizeof(v))
        s += sprintf(" %s=\"%s\"", k, Roxen.html_encode_string(v));
    return s;
  } // }}}

  // Search for linkable string. Slightly modified from wash_html.pike
  string linkify(string s) // {{{
  {
    mapping fix_link(string l)
    {
      // Not exactly bullet proof ;)
      sscanf(l, "%s@%s.%s", string n, string sd, string td);

      if (n && sd && td) {
        l = n + "@" + sd + "." + td;
        return ([ "proto" : "mailto:" + l, "url" : l ]);
      }

      if(l[0..6] == "http://" || l[0..7] == "https://" || l[0..5] == "ftp://")
        return ([ "proto" : l ]);

      if(l[0..3] == "ftp.")
        return ([ "proto" : l ]);

      return ([ "proto" : "http://" + l, "url" : l ]);
    };

    Parser.HTML parser = Parser.HTML();

    parser->add_container("a",
      lambda(Parser.HTML p, mapping _args) {
        return ({ p->current() });
      }
    );

    parser->_set_data_callback(
      lambda(Parser.HTML p, string data) {
        return ({
          utf8_to_string(RELINK->replace(string_to_utf8(data),
            lambda(string link){
              mapping m = fix_link(link);
              return "<a href='" + m->proto +"'>"+ (m->url||m->proto) +"</a>";
            }
          ))
        });
      }
    );

    return parser->finish(s)->read();
  } // }}}

  // Fixes the interactive sorting links
  // From tablify.pike
  string encode_url(int col, int state, mapping args, RequestID id) // {{{
  {
    state = col == abs(state) ? -1*state : col;
    return args->state->encode_revisit_url(id, state, args->sort_state_key,
                                           0, args->url) +
           "#" + args->state_id;
  } // }}}

  // From wash_html.pike
  string safe_cont(string tag, mapping m, string cont) // {{{
  {
    return replace(
      Roxen.make_tag(tag, m),
      ({ "<",">" }), ({ "\1[","\1]" })
    ) + cont + "\1[/" + tag + "\1]";
  } // }}}

  // From wash_html.pike
  string safe_tag(string tag, mapping m, string close_tags) // {{{
  {
    return replace(
      RXML.t_xml->format_tag(
        tag, m, 0, (close_tags?0:RXML.FLAG_COMPAT_PARSE|RXML.FLAG_EMPTY_ELEMENT)
      ),
      ({ "<",">" }), ({ "\1[","\1]" })
    );
  } // }}}

  // Setup default cell attributes. The num* rules isn't set here since they
  // can differ from row to row.
  array cell_formats(mapping args) // {{{
  {
    array out = allocate(args->flood);
    mapping map;

    for (int i = 0; i < args->flood; i++) {
      map = ([ "style" : ({}), "class" : ({}) ]);

      if (has_index(args->align, i))
        map->style += ({ "text-align:" + args->align[i] });

      if (i == 0) {
        if ( args["first-cell-style"] )
          map->style += ({ args["first-cell-style"] });
        if ( args["first-cell-class"] )
          map["class"] += ({ args["first-cell-class"] });
      }
      else if (i == args->flood-1) {
        if ( args["last-cell-style"] )
          map->style += ({ args["last-cell-style"] });
        if ( args["last-cell-class"] )
          map["class"] += ({ args["last-cell-class"] });
      }

      map["style"] = map["style"]*";";
      map["class"] = map["class"]*" ";
      out[i] = map;
    }

    return out;
  } // }}}

  // Takes a string of css styles and remove duplicate properties.
  // The last occurance of a property will be kept!
  string unique_styles(string css) // {{{
  {
    if (!css || !sizeof(css))
      return 0;

    css += ";";
    mapping s = ([]);

    map(css/";",
      lambda(string c) {
        if (search(c, ":") == -1) return;
        [string k, string v] = map(c/":", String.trim_all_whites);
        s[k] = v;
      }
    );

    array out = ({});
    foreach (s; string k; string v)
      out += ({ k + ":" + v });

    return out*";";
  } // }}}

  // Parse the tag content, setup rows, aligment and so on...
  string parse_indata(string content, mapping args, RequestID id) // {{{
  {
    string tail = "";

    if (!content || !sizeof(content))
      return "";

    args->rowseparator  = isarg(args, "rowseparator");
    args->cellseparator = isarg(args, "cellseparator");

    if (args["allow-html"]) {
      if (args["no-escape"])
        content = Roxen.html_decode_string(content);

      content -= "\1";
      mapping allowed_tags = mkmapping(_tags,allocate(sizeof(_tags),safe_tag));
      mapping allowed_cont = mkmapping(_cont,allocate(sizeof(_cont),safe_cont));
      content = parse_html(content, allowed_tags, allowed_cont, 1);

      TRACE("Content after parse: %s\n", content);
    }

    args->align = ({});
    args->flood = 0; // The highest number of cells in a row

    // Look for alignment and type rules e t c
    mapping cbs = ([ "align"   : _align,
                     "type"    : _type,
                     "caption" : _caption,
                     "tfoot"   : _tfoot,
                     "tbody"   : _tbody ]);

    content     = parse_html(content, ([]), cbs, args);
    array rows  = (content/args->rowseparator) - ({ "" });

    args->sort_state_key  = args->state_id + "sort"  + id->misc->tablifies;
    args->pager_state_key = args->state_id + "pager" + id->misc->tablifies;

    // args->state = StateHandler.Page_state(id);
    args->state = PageState(id);

    if (id->real_variables->__state)
      args->state->uri_decode( id->real_variables->__state[0] );

    // If append-query is used we need to save the stuff we write to id->query
    // so that we can remove it from id->query before leaving the tag. If not
    // a second instance of <tablify2/> in the same page will get this too
    // in its id->query and that might not be what we want.
    string bogus_query;

    // This part can probably be solved in a nicer manner!
    if (args["append-query"]) {
      args["append-query"] = replace(args["append-query"], "&amp;", "&");

      array qparts = args["append-query"]/"&";

      mapping id_query = ([]);
      id->query && sizeof(id->query) && map(id->query/"&",
        lambda(string pt) {
          catch {
            [string k, string v] = pt/"=";
            if (k && v) id_query[k] = v;
          };
        }
      );

      array|string append_query = ({});
      map(qparts,
        lambda (string part) {
          catch {
            [string k, string v] = part/"=";
            if ( id->variables[k] )
              m_delete(id_query, k);

            append_query += ({ part });
          };
        }
      );

      array t = ({});
      foreach (id_query; string k; string v)
        t += ({ k + "=" + v });

      id->query = t*"&";
      append_query = append_query*"&";

      if (sizeof(id->query))
        append_query = "&" + append_query;

      id->query += append_query;
      bogus_query = append_query;
    }

    TRACE("Args: %O\n", args);

    rows = map(rows,
      lambda(string line) {
        array row = map(line/args->cellseparator,
          lambda(string col) {
            col = String.trim_all_whites(col);

            if (!args["no-escape"])
              col = Parser.XML.Tree.text_quote(col);

            if (args->linkify)
              col = linkify(col);

            return col;
          }
        );

        if (args->squeeze)
          row -= ({ "" });

        int s = sizeof(row);
        if (s > args->flood)
          args->flood = s;

        return row;
      }
    );

    if (!sizeof(rows)) {
      if (!args->tbody)
        return "";
    }

    rows -= ({({})});

    array titles;
    if (!args->notitle) {
      titles = ({ rows[0] });
      rows   = rows[1..];
    }

    if (args["interactive-sort"]) {
      if (args->nosort)
        args->nosort = (multiset)(args->nosort/",");
      else
        args->nosort = (<>);

      if (!args->state)
        args->state = PageState(id);

      args->state->register_consumer(args->sort_state_key);
      args->sortcol = (int)args->sortcol;

      if (args->state->stateid == args->sort_state_key)
        args->sortcol = args->state->get(args->sort_state_key)||args->sortcol;
    }

    if ((int)args->sortcol) {

      rows = map (rows, lambda (array(string) row) {
        int len = sizeof (row);
        if (len < args->flood)
          row += allocate (args->flood - len, "");

        return row;
      });

      // If squeezing, the number of indexes in each row might differ which can
      // result in an out of range exception when sorting. So we need to even
      // out the length of each row
      if (args->squeeze) {
        rows = map(rows,
          lambda (array row) {
            int len;
            if ((len = sizeof(row)) < args->flood)
              row += allocate(args->flood - len, EMPTY_CELL);
            return row;
          }
        );
      }

      int sortcol = abs((int)args->sortcol)-1;
      if (sortcol < args->flood) {
        int num;
        if (args->coltype && (sortcol+1 <= sizeof(args->coltype))) {
          switch ( args->coltype[sortcol] ) {
            case "num":
            case "int":
            case "float":
            case "economic-int":
            case "economic-float":
              rows = map(rows,
                lambda(array a, int c) {
                  string b;
                  catch { b = replace(a[c]-" "-"%", ({ "," }), ({ "." })); };
                  if (!b) b = "0";
                  return ({ (sizeof(a) > c) ? (float)b : -1e99 }) + a;
                }, sortcol
              );
              sortcol = 0;
              num     = 1;
          }
        }

        sort(column(rows, sortcol), rows);

        if(num) {
          // When sorting on numeric values a fake column is added at the
          // beginning of each row so we need to remove it.
          rows = map(rows, lambda(array a) { return a[1..]; } );
        }

        if ((int)args->sortcol < 0) {
          rows = reverse(rows);
          args->sort_negative = 1;
        }
      }
    }

    // Setup pageing
    if (args->pager) {
      args->state->register_consumer(args->pager_state_key, id);
      args->pager = (int)args->pager;
      int page = 0;

      if (id->real_variables->__state) {
        page = (int)args->state->get(args->pager_state_key)||1;
        if (page < 0) page = -page;
        page -= 1;
      }

      int num_rows = sizeof(rows);
      int pages    = (int)ceil((float)num_rows/(float)args->pager);
      int start_at = 0;
      args->pages  = pages;

      // Shouldn't happen but you'll never know!
      // if (page > pages) page = 0;

      args->page = page;
      start_at = args->pager * page;

      rows = rows[start_at..start_at+args->pager-1];
    }

    if (titles) rows = titles + rows;

    if (args->pager && args->pages > 1) {
      args->_pager = "<div class='tablify-pager'><ul>\n";
      for (int i = 0; i < args->pages; i++) {
        string uri = args->state->encode_revisit_url(id, i+1,
                                                     args->pager_state_key,
                                                     0, args->url);
        string css = (i == args->page) ? " class='active'" : "";
        args->_pager += sprintf(
          "<li%s><a href='%s#%s'>%d</a></li>\n",
          css, uri, args->state_id, (i+1)
        );
      }

      args->_pager += "</ul><span class='break'/></div>\n";

      if (args->pagervar)
        RXML.user_set_var(args->pagervar, args->_pager);
    }

    if (isarg(args, "sum"))
      args->sum = allocate(args->flood);

    string table = mk_table(rows, args, id);

    if (args["allow-html"])
      table = replace(table, ({ "\1[", "\1]" }), ({ "<", ">" }));

    if (bogus_query)
      id->query -= bogus_query;

    return
      (args->_pager && args["pager-before"] ? args->_pager : "") +
      table +
      (args->_pager && !args["no-pager-after"] && !args->pagervar ?
        args->_pager : "");
  } // }}}

  // Create the resultning table
  string mk_table(array rows, mapping args, RequestID id) // {{{
  {
    string table = "<table", tbod = "<tbody>\n", thead = "<thead>\n";
    mapping attr = ([]);
    attr->id = args->state_id;
    attr += set_attr_args(_tblargs + _commonargs, args);
    table += mk_attr(attr) + ">\n";
    attr = 0;

    if (args->caption)
      table += "<caption>" + args->caption + "</caption>\n";

    foreach (_tblargs; string key;)
      if ( args[key] )
        m_delete(args, key);

    int(0..1) gtext = !!sizeof(args->gtextargs);

    if (gtext) {
      if (!args->gtextargs->fgcolor)
        args->gtextargs->fgcolor = _opts["title-fgcolor"];

      if (!args->gtextargs->bgcolor)
        args->gtextargs->bgcolor = _opts["title-bgcolor"];

      if (!args->gtextargs->fontsize)
        args->gtextargs->fontsize = _opts["title-fontsize"];

      args->gtextargs = (array)args->gtextargs;
    }

    if (!args->numclass && !args->numstyle)
      args->numstyle = _opts->numstyle;

    if ( !args["neg-numclass"] && !args["neg-numstyle"] )
      args["neg-numstyle"] = _opts["neg-numstyle"];

    array cell_formats = cell_formats(args);

    // Odd row attributes
    string ora = mk_attr(([ "style" : isarg(args, "odd-row-style"),
                            "class" : isarg(args, "odd-row-class") ]));
    // Even row attributes
    string era = mk_attr(([ "style" : isarg(args, "even-row-style"),
                            "class" : isarg(args, "even-row-class") ]));

    // Last row attributes
    string lra = mk_attr(([ "style" : isarg(args, "last-row-style"),
                            "class" : isarg(args, "last-row-class") ]));
    if (lra && lra == "")
      lra = 0;

    int       i         = 0;
    int       nrows     = sizeof(rows)-1;
    int(0..1) thead_set = 0;
    int       modulo    = (int)isarg(args, "modulo");
    int(0..1) do_sum    = !!args->sum;
    mapping(int:string) sum_colstyles = ([]);

    foreach (rows, array row) {
      if (!args->notitle) {
        args->style   = args["head-style"] || _opts["head-style"];
        args["class"] = args["head-class"];

        if (args->style == "")
          args->style = 0;

        string attr = mk_attr(([ "class" : args["class"],
                                 "style" : args->style ]));

        thead += "<tr" + attr + ">\n";
        int col = 0;
        string align;

        // Draw the header cells
        foreach (row, string s) {
          col++;

          if (gtext)
            s = sprintf("<gtext%{ %s='%s'%}>%s</gtext>", args->gtextargs, s);

          if (s == "") s = EMPTY_CELL;

          if ( args["interactive-sort"] && !args->nosort[(string)col] ) {
            int scol = col;
            // Keep the sort order sticky!
            if (!(abs((int)args->sortcol) == col) && args->sort_negative)
              scol = -1*scol;

            string arrow = "";
            if ((abs((int)args->sortcol)||0) == col)
              arrow = get_arrow((args->sort_negative ? "asc" : "desc"), args);

            s = sprintf(
              "<a href='%s' rel='nofollow'>%s%s</a>",
              encode_url(scol, ((int)args->sortcol)||0, args, id),
              s, arrow
            );
          }

          align = mk_attr( cell_formats[col-1] );
          thead += "<th scope='col'" + align + ">" + s + "</th>\n";
        }

        for (int j = col; j < args->flood; j++) {
          align = mk_attr( cell_formats[j] );
          thead += "<th scope='col'" + align +"'>" + EMPTY_CELL + "</th>\n";
        }

        table += thead + "</tr>\n</thead>\n";
        args->notitle = 1;
        thead_set = 1;
        continue;
      }

      mapping extra_attributes = ([]);

      if (sizeof(row)) {
        mixed fc = row[0];
        if (stringp(fc)) {
          if (sscanf(fc, "[#%s:%s]", string t, string v) == 2) {
            extra_attributes[t] = v;
            sscanf( row[0], "[#%*s:%*s]%s", row[0] );
          }
        }
      }

      if (i == 0 && thead_set) {
        i++;
        table += tbod;
      }

      int mod = (i/modulo) % 2;

      if (lra && i == nrows) {
        string na = merge_row_attr(mod ? era : ora, lra, extra_attributes);
        table += "<tr" + na + ">\n";
      }
      else
        table += "<tr"+merge_row_attr(mod?era:ora,"",extra_attributes)+">\n";

      int col = 0;
      string tag, cell_attr;

      foreach (row, string s) {
        col++;
        if (args["row-titles"] && col == 1) {
          tag = "th";
          cell_attr = mk_attr( cell_formats[0] ) + " scope='row'";
        }
        else {
          tag = "td";
          mapping cell_format = copy_value( cell_formats[col-1] );

          if (args->coltype && has_index(args->coltype, col-1)) {
            string coltype = args->coltype[col-1];

            if ( do_sum && NUM_COLS[coltype] ) {
              if ( INT_COLS[coltype] )
                catch (args->sum[col-1] += (int)s);
              else if ( FLOAT_COLS[coltype] )
                catch (args->sum[col-1] += (float)s);
            }

            switch (coltype) {
              case "text": break;
              default:
                // Negative number
                if (s[0..0] == "-" &&
                   (< "economic-int", "economic-float">)[coltype] )
                {
                  if ( args["neg-numstyle"] && !(cell_format->negnumstyle)) {
                    cell_format->style += ";" + args["neg-numstyle"];
                    cell_format->negnumstyle = 1;
                  }
                  if ( args["neg-numclass"] && !(cell_format->negnumclass)) {
                    cell_format["class"] += " " + args["neg-numclass"];
                    cell_format->negnumclass = 1;
                  }
                }
                else {
                  if (args->numstyle && !(cell_format->numstyle)) {
                    cell_format->style += ";" + args->numstyle;
                    cell_format->numstyle = 1;
                  }
                  if (args->numclass && !(cell_format->numclass)) {
                    cell_format["class"] += " " + args->numclass;
                    cell_format->numclass = 1;
                  }
                }
            }
          }
          cell_format->style = unique_styles(cell_format->style);
          cell_attr = mk_attr(cell_format);

          if ( do_sum && cell_attr && !sum_colstyles[col-1] )
            sum_colstyles[col-1] = cell_attr;

          cell_format = 0;
        }
        s = sizeof(s) && s || EMPTY_CELL;
        table += sprintf("<%s%s>%s</%s>\n", tag, cell_attr, s, tag);
      }

      for (int j = col; j < args->flood; j++) {
        table += sprintf(
          "<td%s>%s</td>\n",
          mk_attr(cell_formats[j] ), EMPTY_CELL
        );
      }

      table += "</tr>\n";

      i++;
    }

    if (thead_set)
      table += "</tbody>\n";

    if (args->tbody && sizeof(args->tbody) && (sizeof(rows) == 0 || (
      sizeof(rows) == 1 && thead_set)))
    {
      table += args->tbody;
    }

    TRACE("Coltypes: %O : %O\n", args->coltype, NUM_COLS);

    if (do_sum && args->coltype) {
      table += "<tfoot>\n<tr>\n";
      i = 0;

      TRACE("args->sum(%O)\n", args->sum);

      foreach (args->sum, mixed v) {
        if ( !NUM_COLS[args->coltype[i]] ) {
          table += "<td>" + EMPTY_CELL + "</td>";
          continue;
        }

        if (floatp(v))
          table += sprintf("<td%s>%.2f</td>\n", sum_colstyles[i-1]||"", v);
        else if (intp(v))
          table += sprintf("<td%s>%d</td>\n", sum_colstyles[i-1]||"", v);
      }

      table += "</tr>\n</tfoot>\n";
    }
    else if (args->tfoot) {
      TRACE("Appending table footer\n");
      table += replace(args->tfoot, ({ "&amp;","&#38;" }), ({ "&","&" }));
    }

    table += "</table>\n";

    return gtext ? Roxen.parse_rxml(table, id) : table;
  } // }}}

  string merge_row_attr(string a, string b, mapping extras) // {{{
  {
    sscanf(a, "%*sclass=\"%s\"", string ac);
    sscanf(b, "%*sclass=\"%s\"", string bc);
    sscanf(a, "%*sstyle=\"%s\"", string as);
    sscanf(b, "%*sstyle=\"%s\"", string bs);

    string oc = (({ ac, bc, extras["class"] }) - ({ 0 }))*" ";
    string os = (({ as, bs, extras["style"] }) - ({ 0 }))*";";
    if (sizeof(os))
      os = unique_styles(os);

    string out = "";
    if (sizeof(oc))
      out = sprintf(" class=\"%s\"", oc);
    if (sizeof(os))
      out += sprintf(" style=\"%s\"", os);

    return out;
  } // }}}

  // ---

  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      if (!id->misc->tablifies)
        id->misc->tablifies = 0;

      args->state_id = name + id->misc->tablifies++;

      // Setup GTEXT arguments
      args->gtextargs = ([]);
      foreach (args; string key; string v) {
        sscanf(key, "title-%s", string fv);
        if (fv) args->gtextargs[fv] = v;
      }

      if ( args["data-variable"] ) {
        content += map(RXML.user_get_var( args["data-variable"] ),
          lambda (array(string) row) {
            return ((array(string))row)*(args->cellseparator||_opts->cellseparator);
          }
        )*(args->rowseparator||_opts->rowseparator);
      }

      TRACE("Parse: %O\n", content);

      result = parse_indata(content, args, id);
    }
  }
}

// Compat tag for my earlier version of tablify
class TagTablifyW3C
{
  inherit TagTablify2;
  constant name = "tablify-w3c";
}

TAGDOCUMENTATION
#ifdef manual
constant tagdoc = ([
"tablify2" : ({ "<desc type='cont'><p><short>"
/* Description */ #"
Transforms text into tables.</short></p>
<p><em>This is a rewritten version of the
original &lt;tablify/&gt tag that better conform to modern HTML markup as well
as adding a few new features and removing some deprecated HTML markup which
result can better be achived with CSS nowadays. Some of the documentation is
taken from the old <tt>tablify</tt> where attributes are the same.</em></p>
<p>The default behavior is to use <em>tabs</em> as column delimiters and
<em>newlines</em> as row delimiters. The values in the first row are assumed to
be cell titles. Missing cells will get <tt><ent>#160</ent></tt> as content to
force all cells to be drawn (in Internet Explorer) if borders are on, thus
avoiding broken layout when, e.g. a dynamic variable happens to be empty. No
attributes are required for tablify to work. All allowed standard table tag
attributes will be kept.</p>
<p></p>
<div>Empty rows will be removed:</div>
<ex>
<tablify2 style='border: 1px solid black' cellpadding='5'>
X       Y       Z
1       2       3

4       5       6
7       8       9
</tablify2>
</ex>
<p></p>
<div>The data will be prescanned to find the widest number of cells:</div>
<ex>
<tablify2 border='1'>
A       B
1       2
3       4
5       6       Tail!
</tablify2>
</ex>
<p></p>
<div>The first cell in each row can also be treated as a row header:</div>
<ex>
<tablify2 border='1' row-titles=''>
        Y1      Y2      Y3
X1      0       1       2
X2      1       2       3
X3      2       3       4
</tablify2>
</ex>

<attr name='*'><p>
 <b>NOTE!</b> All valid standard table attributes applies.</p>
</attr>

<attr name='rowseparator' value='string' default='newline'>
  <p>Defines the character or string used to seperate the rows.</p>
</attr>

<attr name='cellseparator' value='string' default='tab'><p>
 Defines the character or string used to seperate the cells.</p>

<ex>
<tablify2 cellseparator=','>
Element, Mass
H, 1.00797
He, 4.0026
Li, 6.939
</tablify2>
</ex>
</attr>

<attr name='notitle'><p>
 Don't add a title to the columns and treat the first row in the
 indata as real data instead.</p>
</attr>

<attr name='row-titles'><p>
 Treat the first cell in every row as a row header (&lt;th&gt;&lt;/th&gt;)</p>
</attr>

<attr name='interactive-sort'><p>
 Makes it possible for the user to sort the table with respect to any
 column.</p>
</attr>

<attr name='nosort' value='number[,number[,...]]'><p>
 Comma separated list of columns that should not be interactivly sortable
 when in interactive sort mode.</p>

<ex>
<tablify2 nosort='3' interactive-sort='' border='1'>
_A_     _B_     _C_
a       3.3     Alpha
b       2.1     Bravo
c       5.2     Charlie
d       2.6     Delta
</tablify2>
</ex>
</attr>

<attr name='sortcol' value='number'><p>
 Defines which column to sort the table with respect to. The leftmost
 column is number 1. Negative value indicate reverse sort order.</p>
</attr>

<attr name='squeeze'><p>
 Merge consecutive empty cells into one cell. Makes it possible to work with
 more human readable CSV, TSV data:</p>
<ex>
<tablify2 border='1' squeeze='' cellpadding='3' head-style='background:#ccc'>
Name                    Movie                   Year
Arnold Schwarzenegger   Terminator              1984
Sylvester Stallone      Spy Kids 3-D: Game Over 2003
Vin Diesel              xXx                     2002
</tablify2>

<p>Without the squeeze attribute</p>

<tablify2 border='1' cellpadding='3' head-style='background:#ccc'>
Name                    Movie                   Year
Arnold Schwarzenegger   Terminator              1984
Sylvester Stallone      Spy Kids 3-D: Game Over 2003
Vin Diesel              xXx                     2002
</tablify2>
</ex>
</attr> <!-- Squeeze -->

<attr name='no-escape'><p>
 Per default all HTML special characters (&lt;, &gt;, &) will be escaped.
 This attribute turns escapeing off.</p>
</attr>

<attr name='linkify'><p>
 With this attribute set tablify2 tries to find things to turn into clickable
 links. Searches for web addresses (ftp, http, https, www) and e-mail addresses
 as well</p>
<ex>
<tablify2 linkify='' squeeze=''>
Name                            E-mail                  WWW
Roxen Internet Software AB      sales@roxen.com         www.roxen.com
Tekniska Verken i Linköping AB  info@tekniskaverken.se  www.tekniskaverken.se
Pontus Östlund                  spam@poppa.se           www.poppa.se
</tablify2>
</ex>
</attr>

<attr name='allow-html'><p>
 All (almost) valid HTML tags will be kept but other HTML special chars will
 still be escaped.</p>
<ex>
<vform>
  <tablify2 allow-html='' notitle=''>
    <align>right left</align>
    <label for='a'>Name</label> <vinput type='string' name='a' id='a'/>
    <label for='b'>E-mail</label>       <vinput type='email' name='b' id='b'/>
  </tablify2>
</vform>
</ex>
</attr>

<attr name='modulo' value='number'><p>
 Defines how many consecutive rows should have the same color.</p>
<ex>
<tablify2 modulo='2' even-row-style='background:#f6f6ff'>
Element Mass
H       1.00797
He      4.0026
Li      6.939
Be      9.0122
B       10.811
</tablify2>
</ex>
</attr>

<attr name='caption' value='string'><p>
 Adds a caption tag inside the table</p>
</attr>

<attr name='sum' value='string'><p>
 Sums the columns if the column is of numeric type (one of the float or int
 variants). The result of each column is put in a <tt>TFOOT</tt> tag.</p>

<ex>
<tablify2 sum=''>
<type>text int economic-float</type>
Date    Value   Cost
2009-06-01      2       3.5
2009-07-01      5       8.23
2009-08-01      3       5.0
</tablify2>
</ex>
</attr>

<attr name='data-variable' value='string'><p>
 Name of an RXML variable to use as data. Useful if the data is set up as an
 RXML array.</p>
<ex-box>
<set variable='var.data' type='array'>
 <value type='array'>
  <value>A value</value>
  <value>Another value</value>
  <value>A third value</value>
 </value>
 <value type='array'>
  <value>More value</value>
  <value>Even more value</value>
  <value>Most value</value>
 </value>
</set>

<tablify2 data-variable='var.data' />
</ex-box>
</attr>

<attr name='pager' value='number'><p>
 Split the rowset into pages. The value defines how many rows should be
 displayed per page. The pager it self is an unordered list wrapped in a
 div-container with the CSS class <tt>tablify-pager</tt>.</p>
</attr>

<attr name='pager-before'><p>
  Adds the pager before the table.</p>
</attr>

<attr name='no-pager-after'><p>
  Skip the pager after the table.</p>
</attr>

<attr name='pagervar'><p>
  If given the pager will be accessible through this RXML variable</p>
</attr>

<attr name='append-query' value='string'><p>
  Append a querystring to the cell titles when in interactive mode.</p>
</attr>

<h2>GText headers</h2>

<p>It's possible to create bitmaps from the headers by setting the
<tt>title-font</tt> attribute. This will run the headers (cell titles) through
<cont>gtext</cont>. You can apply all <cont>gtext</cont>-attributes by prefixing
them with <tt>title-</tt>. So <tt>title-italic</tt>, <tt>title-black</tt>,
<tt>title-glow</tt> and so on will be copied as arguments to <cont>gtext</cont>
</p>

<ex>
<tablify2 title-font='franklin gothic demi' title-fontsize='10'
          title-bgcolor='#006699' title-fgcolor='#ffffff' cellpadding='3'
          title-black='' head-style='background:#006699' squeeze=''>
Name                    Movie                   Year
Arnold Schwarzenegger   Terminator              1984
Sylvester Stallone      Spy Kids 3-D: Game Over 2003
Vin Diesel              xXx                     2002
</tablify2>
</ex>

<h2>Styling</h2>

<attr name='head-style' value='string'><p>
 CSS style to apply to the first row if cell titles are being drawn.</p>
</attr>

<attr name='head-class' value='string'><p>
 CSS class to apply to the first row if cell titles are being drawn.</p>
</attr>

<attr name='even-row-style' value='string'><p>
  CSS style to apply to every even row.</p>
</attr>

<attr name='even-row-class' value='string'><p>
  CSS class to apply to every even row.</p>
</attr>

<attr name='odd-row-style' value='string'><p>
  CSS style to apply to every odd row.</p>
</attr>

<attr name='odd-row-class' value='string'><p>
  CSS class to apply to every odd row.</p>
</attr>

<attr name='last-row-class' value='string'><p>
  CSS class to apply to the last row.</p>
</attr>

<attr name='first-cell-style' value='string'><p>
  CSS style to apply to every first cell in a row.</p>
</attr>

<attr name='first-cell-class' value='string'><p>
  CSS class to apply to every first cell in a row.</p>
</attr>

<attr name='last-cell-style' value='string'><p>
  CSS style to apply to every last cell in a row.</p>
</attr>

<attr name='last-cell-class' value='string'><p>
  CSS class to apply to every last cell in a row.</p>
</attr>

<attr name='arrow-asc-img' value='string' default='/internal-roxen-sort-asc'><p>
  Image to use as ascending sorting indicator in interactive sort mode.</p>
</attr>

<attr name='arrow-desc-img' value='string' default='/internal-roxen-sort-desc'><p>
  Image to use as descending sorting indicator in interactive sort mode.</p>
</attr>", ([

"align" : #"<desc type='cont'><p>
 The container 'align' may be used inside the tablify container to
 describe the contents of the fields should be aligned. Available
 fields are:</p>

   <list type='ul'>
     <item><p>left (default)</p></item>
     <item><p>center</p></item>
     <item><p>right</p></item>
   </list>

<ex>
<tablify2 border='1' width='500'>
<align>center left right</align>
Column 1        Column 2        Column 3
Value 1 Value two       Value 3
Another value   Again   Yet again and again
</tablify2>
</ex>

<attr name='split' value='string' default='space'><p>
 How to split the alignment rules</p>
</attr>
",

"type" : #"<desc type='cont'><p>
 The container 'type' may be used inside the tablify container to
 describe the type of contents the fields in a column has. Available
 fields are:</p>

   <list type='ul'>
   <item><p>text</p></item>
   <item><p>num</p></item>
   <item><p>int</p></item>
   <item><p>economic-int</p></item>
   <item><p>float</p></item>
   <item><p>economic-float</p></item>
   </list>

 <p>The economic-* variants will take negative values into concideration.<br/>
 Style with the <tt>numstyle</tt>, <tt>neg-numstyle</tt>, <tt>numclass</tt> and
 <tt>neg-numclass</tt> attributes.</p>

<attr name='split' value='string' default='space'><p>
 How to split the column type rules</p>

<ex>
<tablify2>
<type split=','>num, text, economic-float</type>
Integer Text    Economic float
1       one     1.0
-3      minus three     -3.0
2       two     2.0
6       six     6.0
</tablify2>
</ex>
</attr>
"])
})
]);
#endif