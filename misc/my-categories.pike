#include <module.h>
#include <config.h>
inherit "module";

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y) _DEF_LOCALE("sitebuilder",X,Y)

constant thread_safe = 1;
constant module_type = MODULE_TAG;
LocaleString module_name = LOCALE(0, "TVAB Tags: Kategoritaggar");
LocaleString module_doc  = LOCALE(0, "To be provided");

//| I'm not sure we need to inherit this file...
inherit "modules/sitebuilder/tabs/files/wizards/edit_category.pike";
import Sitebuilder;
import Sitebuilder.FS;

//| {{{ create
void create(Configuration _conf)
{
  set_module_creator("Pontus Östlund <pontus.ostlund@tekniskaverken.se>");
} // }}}

//| {{{ start
void start(int when, Configuration _conf)
{
} // }}}

//| {{{ TagTVABGetCategories
//|
//| When we use our special create-new-blog-page feature we can assign
//| categories to the page directly. This tag creates the category tree with
//| checkboxes
class TagTVABGetCategories
{
  inherit RXML.Tag;
  constant name = "tvab-get-categories";

  mapping(string:RXML.Type) req_arg_types = ([]);

  class Frame
  {
    inherit RXML.Frame;

    array do_enter(RequestID id)
    {
      //| An ugly hack!
      //| Dunno where this is set in the wizards but it doesn't seem to be
      //| available outside of /__frame/ so lets set it manually. It works
      //| for the purpose of Tekniska Verken ;)
      id->misc->theme_img_url = "/edit/__img/{dflt}";
    }

    array do_return(RequestID id)
    {
      SBObject sbobj = id->misc->sbobj;
      Sitebuilder.Category cat = id->misc->sb->get_category_handler();
      array(mapping(string:string)) trees = cat->get_trees(id, sbobj);

      if (sizeof(trees) == 0)
	return def_return();

      mapping|object md = sbobj->metadata(id);
      if (!objectp(md))
	return def_return();

      md = md->md;

      SBObject tree_file = id->misc->wa->sbobj(trees[0]->file, id);
      if (!tree_file)
	return def_return();

      md = tree_file->metadata(id);
      if (mappingp(md)) {
	string msg = sprintf("Unexpected error from metadata(): "
			     "%s; tree_sbobj: %O\n",
			     Sitebuilder.error_msg(md),
			     tree_file);
	report_error(msg);
	return 0;
      }

      md = md->md;
      result = sprintf(
	"<div style='font-weight: bold'>Kategoriträd: <small>%s</small></div>",
	(md->title != "") ? md->title : tree_file->real_abspath()
      );

      result += subcats(id, cat, tree_file, tree_file->real_name()+"!",
			0, 0, ({}), ({}), 1)[0] || "";

      if (result != "") {
	result += sprintf(
	  "<input type='hidden' name='blog-category-file' value='/%s' />",
	  tree_file->real_abspath()
	);
      }

      return 0;
    }

    //| {{{ subcats
    //|
    //| This method is pretty much a copy of the method subcategories() in
    //| modules/sitebuilder/tabs/files/wizards/edit_category.pike so for
    //| documentation (although minimal) see that file...
    //|
    //| What it does is grabbing the categories from a given category file
    array(string|int(0..1))
    subcats(RequestID id, Sitebuilder.Category cat, SBObject tree_sbobj,
	    string prefix, string node, int level, array(string) checked_cats, 
	    array(string) unfolded, int(0..1)|void force_expand)
    {
      string res = "";
      int expand = 0;

      array(mapping(string:string)) subs;
      mixed err = catch {
	subs = cat->get_categories(id, tree_sbobj, node) || ({});
      };

      if (err) {
	report_notice("WARNING: Skipping malformed category tree "
	"/"+tree_sbobj->real_abspath()+":\n"+describe_backtrace(err));
	return ({ 0, 0 });
      }

      sort(subs->name, subs);

      foreach (subs, mapping(string:string) sub) {
	string label = prefix + sub->node;
	string quoted_label = Roxen.html_encode_string(label);
	string name = sub->name;

	[string sub_res, int sub_expand] = subcats(id, cat, tree_sbobj, prefix, 
	                                           sub->node, level+1, 
						   checked_cats, unfolded, 
						   force_expand);

	if( string prev_toggle = id->variables["toggle_" + node] )
	  sub_expand = (prev_toggle == "minus");

	if(has_value(checked_cats, label) || sub_expand || force_expand)
	  expand = 1;

	string toggle = "";

	if (sub_res) {
	  sub_res =
	    "<div id='div_" + quoted_label + "' "
	    "     style='display:" + (sub_expand ? "block":"none") + "'>" +
	    sub_res + "</div>\n";

	  toggle =
	    "<input type='hidden' id='toggle_" + quoted_label + "' "
	    "       name='toggle_" + quoted_label + "' "
	    "       value='" + (sub_expand ? "minus" : "plus") + "'/>\n"
	    "<img src='" + id->misc->theme_img_url +
	    (sub_expand ? "cat_fold.gif" : "cat_unfold.gif") + "' "
	    "     id='img_" + quoted_label + "' " +
	    (force_expand ? "" : "onclick='toggle_div(\""+quoted_label+"\")'")+
	    "/>";
	}

	string var_name = "cat_" + quoted_label, name_bgcolor;
	string checkbox =
	  "<input type='checkbox' name='"+var_name+"' id='"+var_name+"' "
	  "       class='default' " +
	  (has_value(checked_cats, label) ? " checked='checked'" : "")+"/>";

	res += "<table border='0' cellspacing='0' cellpadding='0' "
	       "       class='no-cellpadding'>"
	       "<tr><td>";
	for (int i = 0; i < level; i++) {
	  res += "<img src='" + id->misc->theme_img_url + "cat_line.gif' />"
		 "<img src='/internal-roxen-unit' width='6' height='1' />";
	}

	if(!sub_res)
	  res += "<img src='" + id->misc->theme_img_url + "cat_leaf.gif' />";

	res +=
	  toggle +
	  "</td><td " + (name_bgcolor ? " bgcolor='" + name_bgcolor + "'":"") +
	  "><img src='/internal-roxen-unit' width='2' height='1' />" +
	  checkbox +
	  "</td><td" + (name_bgcolor ? " bgcolor='" + name_bgcolor + "'":"") +
	  "><img src='/internal-roxen-unit' width='1' height='1' />"
	  "<label for='" + var_name + "' class='inline'>" +
	  name +
	  "</label>"
	  "</td></tr>"
	  "</table>";

	if (sub_res)
	  res += sub_res;
      }

      return ({ strlen(res) && res, expand });
    } // }}}

    array def_return()
    {
      result = "";
      return 0;
    }
  }
} // }}}

//| {{{ TagEmitTVABAssignedCategories
//|
//| This tag is for assigning categories to a blog post upon creation of
//| the page.
//|
//| This tag is thus usable with <sb-category /> like this:
//|
//| <sb-edit-area>
//|   <sb-new-file file="myfile.xml" />
//|   <!-- ... -->
//|   <sb-category file="myfile.xml">
//|     <emit source="blog-assigned-categories">
//|       <category file="&_.file;" node="&_.node;" />
//|     </emit>
//|   </sb-category>
//| </sb-edit-area>
class TagEmitTVABAssignedCategories
{
  inherit RXML.Tag;

  constant name = "emit";
  constant plugin_name = "tvab-assigned-categories";

  array get_dataset(mapping args, RequestID id)
  {
    array(mapping) res = ({});
    string file = id->variables["blog-category-file"];

    foreach (indices(id->variables), string key) {
      string val = id->variables[key], node;

      if (key[0..3] == "cat_")
	sscanf(key, "%*s!%s", node);

      if (!node) continue;

      res += ({ ([ "file" : file, "node" : node ]) });
    }

    return res;
  }
} // }}}
