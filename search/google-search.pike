/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.
*/

#charset utf-8

#include <module.h>
#include <config.h>
inherit "module";

#define GS_DEBUG

#ifdef GS_DEBUG
# define TRACE(X...) werror("%d:%s: %s",__LINE__,basename(__FILE__),sprintf(X))
#else
# define TRACE(X...) 0
#endif

#define _ok RXML_CONTEXT->misc[" _ok"]

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Google Site Search";
constant module_doc  = "Custom search at Google";

Configuration conf;

void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");

  defvar("api_key",
         Variable.String("", 0, "API key", "Default API key"));

  defvar("search_engine",
         Variable.String("", 0, "Search engine", "Default search engine ID"));

  defvar("num_results",
         Variable.Int(10, 0, "Number of results", "Default number of results "
                                                  "to display per page"));

  conf = _conf;
}

protected string api_key;
protected string search_engine;
protected int num_results;

void start(int when, Configuration _conf)
{
  api_key       = query("api_key");
  search_engine = query("search_engine");
  num_results   = query("num_results");
}

#define EMPTY_OR(A,X) (((A) && sizeof((A)) && (A)) || (X))

class TagGoogleSearchResult
{
  inherit RXML.Tag;
  constant name = "google-search-result";

  mapping(string:RXML.Type) req_arg_types = ([
    "query" : RXML.t_text(RXML.PXml)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "api-key"       : RXML.t_text(RXML.PXml),
    "search-engine" : RXML.t_text(RXML.PXml),
    "num-results"   : RXML.t_text(RXML.PXml),
    "start"         : RXML.t_text(RXML.PXml),
  ]);

  private class SearchData
  {
    string query;
    array(mapping(string:string)) result;
    mixed navigation;
    mapping header;
    mapping(string:mixed) outervars;

    string _sprintf(int t)
    {
      return t == 'O' && sprintf(
        "%O(\nresult: %O\n"
        "\tnavigation: %O\n"
        "\theader: %O\n"
        "\toutervars: %O\n)",
        this_object(), result, navigation, header,
        outervars
      );
    }
  }

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagGoogleSearchResult", ({
      TagGoogleSearchResultEntries(),
      TagGoogleSearchResultNavigation(),
      TagGoogleSearchResultHeader()
    })
  );

  class Frame
  {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    int no_query, do_iterate;

    array do_enter(RequestID id)
    {
      TRACE("IN ARGS: %O\n", args);

      if (RXML_CONTEXT->misc->gsearch_data)
        parse_error("<%s> can not be nested.\n", name);

      no_query = 0;
      do_iterate = 1;

      // Abort if the form isn't posted or if it's posted with an
      // empty query field
      if (args->query && !sizeof(args->query) || !args->query) {
        do_iterate = -1;
        no_query = 1;
        return 0;
      }

      mapping(string:string|int) vars = ([
        "start" : EMPTY_OR(args->start, "1"),
        "num"   : EMPTY_OR(args["num-results"], (string)num_results)
      ]);

      TRACE("VARS: %O\n", vars);

      GoogleSearch cli;
      cli = GoogleSearch(EMPTY_OR(args["api-key"], api_key),
                         EMPTY_OR(args["search-engine"], search_engine));

      object /*GoogleSearch.Result*/ res;

      string cache_file_name = sprintf("result.%s.json", (string)vars->start);
      string p = combine_path(dirname(__FILE__), cache_file_name);

      if (0 && Stdio.exist(p)) {
        res = cli->Result(Stdio.read_file(p));
        TRACE("Using cached result\n");
      }
      else {
        if (mixed e = catch(res = cli->query(args->query, vars))) {
          report_error("Search error: %s\n", describe_backtrace(e));
          RXML.parse_error("Unable to handle query!\n");
        }

        Stdio.write_file(p, cli->raw_data || "");
      }

      if (!res || !sizeof(res->items())) {
        TRACE("No result\n");
        do_iterate = -1;
        no_query = 1;
        return 0;
      }

      array(mapping) results = map(res->items(),
        lambda(mapping m) {
          sscanf(m->link, "%*s://%*s.%*s/%s", string nice_link);

          foreach (m; string mk; string mv)
            catch ( m[mk] = utf8_to_string(mv) );

          m["nice-link"] = "/" + nice_link;
          return m;
        }
      );

      int current      = res->start_index();
      int total        = res->total_results();
      int size         = res->raw_result()->queries->request[0]->count;
      int pages        = (int)ceil((float)total/(float)size);
      int current_page = (int)ceil(((float)current/(float)total)*(float)pages);

      TRACE("\nCurrent index: %4d\n"
            "Total hits:    %4d\n"
            "Per page:      %4d\n"
            "Pages:         %4d\n"
            "Current page:  %4d\n",
            current, total, size, pages, current_page);


      SearchData sd  = SearchData();
      sd->result     = results;
      sd->header     = ([
        "current"  : current,
        "total"    : total,
        "num"      : size,
        "page"     : current_page,
        "pages"    : pages,
        "next"     : res->next_index(),
        "previous" : res->previous_index()
      ]);

      if (!sd->header->next)
        m_delete(sd->header, "next");

      if (!sd->header->previous)
        m_delete(sd->header, "previous");

      RXML_CONTEXT->misc->gsearch_data = sd;

      //TRACE("SD: %O\n", sd);

      return 0;
    }

    array do_return(RequestID id)
    {
      m_delete(RXML_CONTEXT->misc, "gsearch_data");

      _ok = 1;

      if (no_query) {
        result = "";
        return 0;
      }

      if (content == RXML.Nil || sizeof(content) == 0) {
        _ok = 0;
        return 0;
      }

      result = content;

      return 0;
    }
  }

  // Tag for listing the results from the search
  class TagGoogleSearchResultEntries
  {
    inherit RXML.Tag;
    constant name = "google-search-result-entries";

    class Frame
    {
      inherit RXML.Frame;
      array(mapping) ret;
      mapping(string:mixed) vars;
      int i, last, counter;
      SearchData sd;

      array do_enter(RequestID id)
      {
        if (!(sd = RXML_CONTEXT->misc->gsearch_data))
          RXML.parse_error("Missing context RXML->misc->gsearch_data.\n");

        if (!content)
          content = "NO CONTENT";

        ret = sd->result;
        // The variables in sd->outervars isn't really in use at the moment
        // but are kept for future use...
        vars = copy_value(sd->outervars);
        counter = 0;
        i = 0;
        last = ret && sizeof(ret) || 0;
        return 0;
      }

      int do_iterate(RequestID id)
      {
        if (i >= last)
          return 0;

        vars = ret[i++];
        vars["counter"] = ++counter;
        return 1;
      }

      array do_process(RequestID id)
      {
        result = Roxen.parse_rxml(content, id);
        return 0;
      }

      array do_return(RequestID id)
      {
        if (content != RXML.nil)
          result = result || "WHAT";
        else
          result = "";

        return 0;
      }
    }
  }

  class TagGoogleSearchResultHeader
  {
    inherit RXML.Tag;
    constant name = "google-search-result-header";

    mapping(string:RXML.Type) opt_arg_types = ([]);

    class Frame
    {
      inherit RXML.Frame;
      string res = "";
      mapping(string:mixed) vars;
      int i, counter;

      array do_enter(RequestID id)
      {
        i = 0;
        counter = 0;
        return 0;
      }

      int do_iterate(RequestID id)
      {
        if (i > 0) return 0;

        vars = RXML_CONTEXT->misc->gsearch_data->header;
        vars->counter = ++counter;

        i++;
        return 1;
      }

      array do_process(RequestID id)
      {
        if (content)
          result = Roxen.parse_rxml(content, id);

        return 0;
      }

      array do_return(RequestID id)
      {
        return 0;
      }
    }
  }

  class TagGoogleSearchResultNavigation
  {
    inherit RXML.Tag;
    constant name = "google-search-result-navigation";

    mapping(string:RXML.Type) opt_arg_types = ([]);

    class Frame
    {
      inherit RXML.Frame;
      string res = "";
      int i, counter, size, total, pages, current, pagecount;
      mapping(string:mixed) vars;

      array do_enter(RequestID id)
      {
        mapping h = RXML_CONTEXT->misc->gsearch_data->header;

        total     = h->total;
        size      = h->num;
        pages     = h->pages;
        current   = h->page;
        pagecount = 0;

        if (pages > 10) {
          int step   = 10;
          int ppages = pages;
          int inc    = 0;
          int start  = 0;

          if (current > 1 && current <= 10) {
            pages += (current-1);
          }
          else if (current > 10) {

          }

          TRACE("\nSPLIT NAV:\n"
                "       Pages:    %9d\n"
                "       Current:  %9d\n"
                "       Interval: %4d-%4d\n",
                pages, current, 0, 0);

          pages = 10;
        }

        i       = 0;
        counter = 0;
        return 0;
      }

      int do_iterate(RequestID id)
      {
        if (i >= pages) return 0;

        vars = ([]);
        vars->start = (pagecount * size) + 1;
        vars->counter = ++counter;
        if (counter == current) vars->current = 1;

        pagecount++;
        i++;
        return 1;
      }

      array do_process(RequestID id)
      {
        if (content)
          result = Roxen.parse_rxml(content, id);

        return 0;
      }

      array do_return(RequestID id)
      {
        return 0;
      }
    }
  }
}

class GoogleSearch
{
  constant BASE_URI = "https://www.googleapis.com/customsearch/v1";
  protected string api_key;
  protected string cx;
  protected string alt = "json";

  protected mapping headers = ([
    "User-Agent" : "Pike HTTP Client (Pike " + __VERSION__ + ")"
  ]);

  public string raw_data;

  /*
  q={searchTerms}
  num={count?}
  start={startIndex?}
  hr={language?}
  safe={safe?}
  cx={cx?}
  cref={cref?}
  sort={sort?}
  filter={filter?}
  gl={gl?}
  cr={cr?}
  googlehost={googleHost?}
  alt=json
  */

  #define NULL "\0"

  protected mapping allowed = ([
    "num"        : 10,
    "start"      : 1,
    "hr"         : NULL,
    "safe"       : NULL,
    "cx"         : NULL,
    "cref"       : NULL,
    "sort"       : NULL,
    "filter"     : NULL,
    "gl"         : NULL,
    "cr"         : NULL,
    "googlehost" : NULL,
    "alt"        : "json"
  ]);

  void create(string _api_key, string _cx)
  {
    api_key = _api_key;
    cx = _cx;
  }

  void num_results(int num)
  {
    allowed->num = num;
  }

  mixed query(string q, void|mapping args)
  {
    mapping params = ([ "key" : api_key,
                        "q"   : q,
                        "cx"  : cx,
                        "alt" : alt ]);
    if (args) {
      TRACE("In args: %O\n", args);
      foreach (args; string k; string v) {
        if ( allowed[k] )
          params[k] = v;
      }
    }

    Params p = Params()->add_mapping(params);

    TRACE("Query params: %O\n", p);

    Protocols.HTTP.Query cli;
    cli = Protocols.HTTP.get_url(BASE_URI, p->to_mapping());

    Stdio.write_file("result.json", cli->data());

    if (cli->status != 200)
      error("Bad HTTP status (%d) in response! ", cli->status);

    return Result(raw_data = cli->data());
  }

  class Result
  {
    protected mapping raw;

    void create(string|mapping data)
    {
      if (stringp(data))
        raw = Standards.JSON.decode(data);
      else
        raw = data;
    }

    array(mapping) items()
    {
      return raw->items||({});
    }

    mapping raw_result()
    {
      return raw;
    }

    int total_results()
    {
      return (int)raw->queries->request[0]->totalResults;
    }

    string search_terms()
    {
      return raw->queries->request[0]->searchTerms;
    }

    int start_index()
    {
      return raw->queries->request[0]->startIndex;
    }

    int next_index()
    {
      if (raw->queries->nextPage)
        return raw->queries->nextPage[0]->startIndex;
    }

    int previous_index()
    {
      if (raw->queries->previousPage)
        return raw->queries->previousPage[0]->startIndex;
    }
  }
}

//! Checks if A is an instance of B (either directly or by inheritance)
#define INSTANCE_OF(A,B) (object_program((A)) == object_program((B)) || \
                          Program.inherits(object_program((A)),         \
                                           object_program(B)))


string urlencode(string s)
{
#if constant(Protocols.HTTP.uri_encode)
  return Protocols.HTTP.uri_encode(s);
#elif constant(Protocols.HTTP.http_encode_string)
  return Protocols.HTTP.http_encode_string(s);
#endif
}

class Params
{
  //! The parameters.
  protected array(Param) params;

  //! Creates a new instance of @[Params]
  //!
  //! @param args
  void create(Param ... args)
  {
    params = args||({});
  }

  //! Sign the parameters
  //!
  //! @param secret
  //!  The API secret
  string sign(string secret)
  {
    return roxen.md5(sort(params)->name_value()*"" + secret);
  }

  //! Parameter keys
  array _indices()
  {
    return params->get_name();
  }

  //! Parameter values
  array _values()
  {
    return params->get_value();
  }

  //! Returns the array of @[Param]eters
  array(Param) get_params()
  {
    return params;
  }

  //! Turns the parameters into a query string
  string to_query()
  {
    array o = ({});
    foreach (params, Param p)
      o += ({ urlencode(p->get_name()) + "=" + urlencode(p->get_value()) });

    return o*"&";
  }

  //! Turns the parameters into a mapping
  mapping to_mapping()
  {
    return mkmapping(params->get_name(), params->get_value());
  }

  //! Add a mapping of key/value pairs to the current instance
  //!
  //! @param value
  //!
  //! @returns
  //!  The object being called
  Params add_mapping(mapping value)
  {
    foreach (value; string k; mixed v)
      params += ({ Param(k, (string)v) });

    return this;
  }

  //! Add @[p] to the array of @[Param]eters
  //!
  //! @param p
  //!
  //! @returns
  //!  A new @[Params] object
  Params `+(Param|Params p)
  {
    Params pp = object_program(this)(@params);
    pp += p;

    return pp;
  }

  //! Append @[p] to the @[Param]eters array of the current object
  //!
  //! @param p
  Params `+=(Param|Params p)
  {
    if (INSTANCE_OF(p, this))
      params += p->get_params();
    else
      params += ({ p });

    return this;
  }

  //! Remove @[p] from the @[Param]eters array of the current object.
  //!
  //! @param p
  Params `-(Param|Params p)
  {
    if (!p) return this;

    array(Param) the_params;
    if (INSTANCE_OF(p, this))
      the_params = p->get_params();
    else
      the_params = ({ p });

    return object_program(this)(@(params-the_params));
  }

  //! Index lookup
  //!
  //! @param key
  //! The name of a @[Param]erter to find.
  Param `[](string key)
  {
    foreach (params, Param p)
      if (p->get_name() == key)
        return p;

    return 0;
  }

  //! Clone the current instance
  Params clone()
  {
    return object_program(this)(@params);
  }

  //! String format method
  //!
  //! @param t
  string _sprintf(int t)
  {
    return t == 'O' && sprintf("%O(%O)", object_program(this), params);
  }
}

class Param
{
  //! The name of the parameter
  protected string name;

  //! The value of the parameter
  protected string value;

  //! Creates a new instance of @[Param]
  //!
  //! @param _name
  //! @param _value
  void create(string _name, mixed _value)
  {
    name = _name;
    low_set_value((string)_value);
  }

  //! Getter for the parameter name
  string get_name()
  {
    return name;
  }

  //! Setter for the parameter name
  //!
  //! @param _name
  void set_name(string _name)
  {
    name = _name;
  }

  //! Getter for the parameter value
  string get_value()
  {
    return value;
  }

  //! Setter for the parameter value
  //!
  //! @param _value
  void set_value(mixed _value)
  {
    low_set_value((string)_value);
  }

  //! Returns the name and value as querystring key/value pair
  string name_value()
  {
    return name + "=" + value;
  }

  //! Same as @[name_value()] except this URL encodes the value.
  string name_value_encoded()
  {
    return urlencode(name) + "=" + urlencode(value);
  }

  //! Comparer method. Checks if @[other] equals this object
  //!
  //! @param other
  int(0..1) `==(mixed other)
  {
    //if (object_program(other) != object_program(this)) return 0;
    if (!INSTANCE_OF(this, other)) return 0;
    if (name == other->get_name())
      return value == other->get_value();

    return 0;
  }

  //! Checks if this object is greater than @[other]
  //!
  //! @param other
  int(0..1) `>(mixed other)
  {
    //if (object_program(other) != object_program(this)) return 0;
    if (!INSTANCE_OF(this, other)) return 0;
    if (name == other->get_name())
      return value > other->get_value();

    return name > other->get_name();
  }

  //! Checks if this object is less than @[other]
  //!
  //! @param other
  int(0..1) `<(mixed other)
  {
    //if (object_program(other) != object_program(this)) return 0;
    if (!INSTANCE_OF(this, other)) return 0;
    if (name == other->get_name())
      return value < other->get_value();

    return name < other->get_name();
  }

  //! String format method
  //!
  //! @param t
  string _sprintf(int t)
  {
    return t == 'O' && sprintf("%O(%O,%O)", object_program(this), name, value);
  }

  //! Makes sure @[v] to set as @[value] is in UTF-8 encoding
  //!
  //! @param v
  private void low_set_value(string v)
  {
    value = v;
    if (String.width(value) < 8) {
      werror(">>> UTF-8 encoding value in Param(%O, %O)\n", name, value);
      if (mixed e = catch(value = string_to_utf8(value))) {
        werror("Warning: string_to_utf8() failed. Already encoded?\n%s\n",
               describe_error(e));
      }
    }
  }
}