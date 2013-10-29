/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  Adds the X-UA-Compatible header to Internet Explorer.
*/
#charset utf-8
#include <config.h>
#include <module.h>
inherit "module";

//#define IECOMPAT_DEBUG

#ifdef IECOMPAT_DEBUG
# define TRACE(X...) \
  report_debug("%s:%d: %s", basename(__FILE__), __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Poppa Tags: IE Compatibility";
constant module_doc  = "Internet Explorer compatibility filter. Adds the "
                       "X-UA-Compatible header to Internet Explorer.";

private string mode, edit_mode;

void create(Configuration conf)
{
  set_module_creator("Pontus Östlund <poppanator@gmail.com>.");

  defvar("ie_compat_mode",
         Variable.String("IE=edge", VAR_INITIAL,
         "Compatibility mode",
         "For a list of available modes se <a href='http://blogs.msdn.com/b"
         "/askie/archive/2009/03/23/understanding-compatibility-modes-in-"
         "internet-explorer-8.aspx'>MSDN</a>"));

  defvar("ie_compat_edit_mode",
         Variable.String("IE=edge", VAR_INITIAL,
         "Compatibility mode in Insite Editor",
         "This mode will be used when inside the Insite Editor."));
}

void start(int whence, Configuration conf)
{
  mode = query("ie_compat_mode");
  edit_mode = query("ie_compat_edit_mode");
}

mapping|void filter(mapping result, RequestID id)
{
  if (result) {

    if (!result->extra_heads) result->extra_heads = ([]);
    string extra_ct = result->extra_heads["Content-Type"];
    string rtype = extra_ct || result->type;

    if (rtype == "text/html") {
      string cli = id->client*" ";

      TRACE ("Request client is: %s\n", cli);

      // Cache crawler
      if (cli == "Mozilla/4.0 (compatible; MSIE 5.0; Windows NT)")
        return;

      if (search(cli, " MSIE ") > -1) {
        sscanf (cli, "%*sMSIE %d.%*d", int ver);

        if (ver < 9) {
          // Quirks mode in editor
          if (!(search(id->not_query, "/__frame/")   > -1 ||
                search(id->not_query, "/fckeditor")  > -1 ||
                search(id->not_query, "/__internal") > -1 ||
                search(id->not_query, "/_internal")  > -1 ))
          {
            TRACE ("Editor view %s\n", mode);
            result->extra_heads["X-UA-Compatible"] = edit_mode;
          }
          else {
            TRACE ("Emulate %s\n", edit_mode);
            result->extra_heads["X-UA-Compatible"] = mode;
          }
        }
      }
    }
  }
}
