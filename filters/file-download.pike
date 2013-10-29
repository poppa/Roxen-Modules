/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.
*/

#charset utf-8
#include <config.h>
#include <module.h>
inherit "module";

//#define FILE_DOWNLOAD_DEBUG

#ifdef FILE_DOWNLOAD_DEBUG
# define TRACE(X...) \
  report_debug("%s:%d: %s", basename(__FILE__), __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Poppa Tags: Download file";
constant module_doc  = "Raise the browser's download dialog";

private array(string) forbidden;
private string qsv;

void create(Configuration conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");

  defvar("disallow_ct",
         Variable.StringList(({ "sitebuilder/*", "roxen/*" }), VAR_INITIAL,
         "Disallowed content types",
         "Content types that will not be given the extra HTTP header"));

  defvar("query_string_variable",
         Variable.String("__download", VAR_INITIAL,
         "Query string variable",
         "If this query string variable exists in the request the file "
         "will be given an extra HTTP header to force the browser's "
         "download dialog"));
}

void start(int whence, Configuration conf)
{
  forbidden = query("disallow_ct");
  qsv = query("query_string_variable");
}

int(0..1) is_allowed(string ct)
{
  foreach (forbidden, string p)
    if (glob(p, ct))
      return 0;

  return 1;
}

mapping|void filter(mapping result, RequestID id)
{
  if (id->variables[qsv] == "1" && result) {
    if (is_allowed(result->type)) {
      if (!result->extra_heads) result->extra_heads = ([]);
      result->extra_heads["Content-Disposition"] =
        "attachment; filename=\"" + basename(id->not_query) + "\"";
    }
  }
}
