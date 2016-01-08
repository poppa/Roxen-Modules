/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  This is a Roxen® CMS Insite Editor module
*/

#charset utf-8
#include <module.h>
inherit "roxen-module://shared-component-code";

import Sitebuilder.Editor;
import Parser.XML.Tree;

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)	 _STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y) _DEF_LOCALE("sitebuilder",X,Y)

constant module_name = "Poppa Editor Component: Page divider";
// constant module_doc = "To be provided";

#define TRIM(S) String.trim_all_whites((S))

class HrComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0, "Page divider");
  }

  string get_component_tag()
  {
    return "hr-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant", "class", "margin-top", "margin-bottom" });
  }
}

class HrComponentInstance
{
  inherit AbstractComponentInstance;

  string render_editor(string var_prefix, RequestID id)
  {
    return
    render_field("class",
		 ([ "title"   : LOCALE(0, "CSS class"),
		    "type"    : "string",
		    "size"    : "60",
		    "name"    : var_prefix + "class" ]), id) +
    render_field("margin-top",
		 ([ "title"   : LOCALE(0, "Margin above (pixels)"),
		    "type"    : "string",
		    "size"    : "60",
		    "name"    : var_prefix + "margin-top" ]), id) +
    render_field("margin-bottom",
		 ([ "title"   : LOCALE(0, "Margin below (pixels)"),
		    "type"    : "string",
		    "size"    : "60",
		    "name"    : var_prefix + "margin-bottom" ]), id);
  }

  void save_variables(string var_prefix, RequestID id)
  {
    set_field("class", id->variables[var_prefix + "class"]);
    set_field("margin-top", TRIM(id->variables[var_prefix + "margin-top"]));
    set_field("margin-bottom", TRIM(id->variables[var_prefix + "margin-bottom"]));
  }

  void create(AbstractComponentPlugin p, string|Node xml_data)
  {
    ::create(p, xml_data);
  }
}
