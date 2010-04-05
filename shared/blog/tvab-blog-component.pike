#include <module.h>
inherit "roxen-module://shared-component-code";

import Sitebuilder.Editor;
import Parser.XML.Tree;

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("sitebuilder",X,Y)

constant module_name = "TVAB Blog: CMS components";
//constant module_doc = "TVAB blog related components";

class TVABBlogIndexComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0 ,"TVAB blog: Index");
  }

  string get_component_tag()
  {
    return "tvab-blog-index-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant", "path" });
  }

  mapping get_component_variants()
  {
    return ([]);
  }
}

class TVABBlogIndexComponentInstance
{
  inherit AbstractComponentInstance;
  
  string render_editor(string var_prefix, RequestID id)
  {
    string res =
    render_field("path",
		 ([ "title"   : LOCALE(0, "Sökväg (valfri)"),
		    "type"    : "string",
		    "size"    : "60",
		    "name"    : var_prefix + "path" ]), id);
    return res;
  }
  
  void save_variables(string var_prefix, RequestID id)
  {
    set_field("path", id->variables[var_prefix + "path"]);
  }

  void create(AbstractComponentPlugin p, string|Node xml_data)
  {
    ::create(p, xml_data);
  }
}

/* ========================================================================== */

class TVABBlogArchiveComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0 ,"TVAB blog: Arkiv");
  }

  string get_component_tag()
  {
    return "tvab-blog-archive-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant" });
  }

  mapping get_component_variants()
  {
    return ([]);
  }
}

class TVABBlogArchiveComponentInstance
{
  inherit AbstractComponentInstance;
  
  string render_editor(string var_prefix, RequestID id)
  {
    return "";
  }
  
  void save_variables(string var_prefix, RequestID id)
  {
  }

  void create(AbstractComponentPlugin p, string|Node xml_data)
  {
    ::create(p, xml_data);
  }
}

/* ========================================================================== */

class TVABBlogHomePageComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0 ,"TVAB blog: Hemsida");
  }

  string get_component_tag()
  {
    return "tvab-blog-home-page-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant" });
  }

  mapping get_component_variants()
  {
    return ([]);
  }
}

class TVABBlogHomePageComponentInstance
{
  inherit AbstractComponentInstance;
  
  string render_editor(string var_prefix, RequestID id)
  {
    return "";
  }
  
  void save_variables(string var_prefix, RequestID id)
  {
  }

  void create(AbstractComponentPlugin p, string|Node xml_data)
  {
    ::create(p, xml_data);
  }
}

/* ========================================================================== */

class TVABBlogEntryComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0 ,"TVAB blog: Post");
  }

  string get_component_tag()
  {
    return "tvab-blog-entry-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant" });
  }

  mapping get_component_variants()
  {
    return ([]);
  }
}

class TVABBlogEntryComponentInstance
{
  inherit AbstractComponentInstance;
  
  string render_editor(string var_prefix, RequestID id)
  {
    return "";
  }
  
  void save_variables(string var_prefix, RequestID id)
  {
  }

  void create(AbstractComponentPlugin p, string|Node xml_data)
  {
    ::create(p, xml_data);
  }
}

/* ========================================================================== */

class TVABBlogCategoryComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0 ,"TVAB blog: Kategorier");
  }

  string get_component_tag()
  {
    return "tvab-blog-category-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant" });
  }

  mapping get_component_variants()
  {
    return ([]);
  }
}

class TVABBlogCategoryComponentInstance
{
  inherit AbstractComponentInstance;
  
  string render_editor(string var_prefix, RequestID id)
  {
    return "";
  }

  void save_variables(string var_prefix, RequestID id)
  {
  }

  void create(AbstractComponentPlugin p, string|Node xml_data)
  {
    ::create(p, xml_data);
  }
}

/* ========================================================================== */

class TVABBlogTagComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0 ,"TVAB blog: Etiketter");
  }

  string get_component_tag()
  {
    return "tvab-blog-tag-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant" });
  }

  mapping get_component_variants()
  {
    return ([]);
  }
}

class TVABBlogTagComponentInstance
{
  inherit AbstractComponentInstance;

  string render_editor(string var_prefix, RequestID id)
  {
    return "";
  }

  void save_variables(string var_prefix, RequestID id)
  {
  }

  void create(AbstractComponentPlugin p, string|Node xml_data)
  {
    ::create(p, xml_data);
  }
}
