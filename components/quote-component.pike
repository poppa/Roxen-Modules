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
#define LOCALE(X,Y)  _STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y) _DEF_LOCALE("sitebuilder",X,Y)

constant module_name = "Poppa Editor Component: Quote component";
// constant module_doc = "To be provided";

class QuoteComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0, "Quote");
  }

  string get_component_tag()
  {
    return "quote-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant", "quote", "quotee" });
  }

  mapping(int:string) get_component_variants()
  {
    return ([]);
  }
}

class QuoteComponentInstance
{
  inherit AbstractComponentInstance;

  string render_editor(string var_prefix, RequestID id)
  {
    string res =
      render_field("quote",
        ([ "title" : "Quote",
           "type"  : "text",
           "size"  : "60",
           "name"  : var_prefix + "quote" ]), id) +

      render_field("quotee",
        ([ "title" : "Quoted",
           "type"  : "string",
           "size"  : "60",
           "name"  : var_prefix + "quotee" ]), id);

    return res;
  }

  void save_variables(string var_prefix, RequestID id)
  {
    set_field("quote",  id->variables[var_prefix + "quote"]);
    set_field("quotee", id->variables[var_prefix + "quotee"]);
  }

  void create(AbstractComponentPlugin p, string|Node xml_data)
  {
    ::create(p, xml_data);
  }
}
