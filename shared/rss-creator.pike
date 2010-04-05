// This is a Roxen® module
// Author: Pontus Östlund <pontus@poppa.se>
//
// Tab width:    8
// Indent width: 2

#define RSS_DEBUG

#if constant(roxen)

#include <config.h>
#include <module.h>
#define RSS_WRITER   RXML_CONTEXT->misc->rss_writer
inherit "module";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "TVAB Tags: RSS Feed creator";
constant module_doc  = "Tags generating rss feeds.";

void create(Configuration conf)
{
  set_module_creator("Pontus Östlund <pontus@poppa.se>.");
}

class TagRssWriter
{
  inherit RXML.Tag;

  constant name = "rss-writer";

  Channel chnl;

  mapping(string:RXML.Type) opt_arg_types = ([
    "title"       : RXML.t_text(RXML.PEnt),
    "link"        : RXML.t_text(RXML.PEnt),
    "description" : RXML.t_text(RXML.PEnt),
    "image"       : RXML.t_text(RXML.PEnt),
    "version"     : RXML.t_text(RXML.PEnt),
    "encoding"    : RXML.t_text(RXML.PEnt)
  ]);

  class TagRssItem
  {
    inherit RXML.Tag;
    constant name = "add-item";

    mapping(string:RXML.Type) opt_arg_types = ([
      "title"       : RXML.t_text(RXML.PEnt),
      "date"        : RXML.t_text(RXML.PEnt),
      "description" : RXML.t_text(RXML.PEnt),
      "link"        : RXML.t_text(RXML.PEnt),
      "image"       : RXML.t_text(RXML.PEnt)
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
	Item item         = Item();
	item->title       = args->title||"";
	item->pubDate     = args->date||"2000-01-01";
	item->description = args->description||content||"";
	item->link        = nmpath(args->link||"");

	if (args->image) {
	  item->image = Image(([ "url"   : nmpath(args->image),
	                         "link"  : nmpath(args->link),
	                         "title" : args->title ]));
	}

	foreach (({ "title","date","description","link","image" }), string key)
	{
	  if ( args[key] )
	    m_delete(args, key);
	}

	item->populate(args);

	if (chnl)
	  chnl += item;
	else
	  report_error("No channel object found in rss-creator");

	return 0;
      }
    }
  }

  class TagAddNamespace
  {
    inherit RXML.Tag;
    constant name = "add-namespace";

    mapping(string:RXML.Type) opt_arg_types = ([
      "name"  : RXML.t_text(RXML.PEnt),
      "value" : RXML.t_text(RXML.PEnt)
    ]);

    class Frame
    {
      inherit RXML.Frame;

      array do_return(RequestID id)
      {
	wlog("Adding namespace: %s=\"%s\"", args->name, args->value);
	RSS_WRITER && RSS_WRITER->add_namespace(args->name, args->value);
	return 0;
      }
    }
  }
  
  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagRssWriter", ({
      TagRssItem(),
      TagAddNamespace()
    })
  );

  class Frame
  {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    array do_enter(RequestID id)
    {
      if (RSS_WRITER)
	parse_error("<%s> can not be nested.\n", name);

      RSS_WRITER = Writer(args->encoding||"iso-8859-1", args->version||"2.0",1);

      if (args->link)
	args->link = nmpath(args->link);

      chnl = Channel(args);
      if (args->image) {
	chnl->image = Image(([ "url"   : nmpath(args->image),
			       "link"  : nmpath(args->link),
			       "title" : args->title ]));
      }

      return 0;
    }

    array do_return(RequestID id)
    {
      result = RSS_WRITER && RSS_WRITER->render(chnl, 0);
      if (!result)
	RXML.run_error("Couldn't create RSS feed");

      m_delete(RXML_CONTEXT->misc, "rss_writer");
      chnl = 0;
      return 0;
    }
  }
}

#endif // constant(roxen)

string nmpath(string p)
{
  sscanf(p, "%s://%s", string proto, string path);
  if (!proto || !path)
    return replace(p, "//", "/");
  
  return proto + "://" + replace(path, "//", "/");
}

void wlog(mixed ... args)
{
#ifdef RSS_DEBUG
  if (args && args[0][-1] != '\n')
    args[0] += "\n";

  args[0] = "RSS: " + args[0];
  report_debug(@args);
#endif
}

import Parser.XML.Tree;

class Writer
{
  string    version;
  string    encoding;
  int       add_head;
  mapping   namespace = ([]);

  void create(string|void enc, string|void ver, int|void add_xml_declaration)
  {
    encoding  = enc||"utf-8";
    version   = ver||"2.0";
    add_head  = add_xml_declaration||0;
  }

  string render(Channel chnl, int(0..1)|void validate)
  {
    mapping attr = ([ "version" : version ]);
    if (sizeof(namespace))
      foreach (namespace; string k; string v)
	attr[k] = v;

    Node n = SimpleRootNode();
    if (add_head) {
      n->add_child(SimpleHeaderNode(([ "version" : "1.0",
                                       "encoding" : encoding ])));
    }
    Node root    = SimpleElementNode("rss", attr);
    Node channel = SimpleElementNode("channel", ([]));
    n->add_child(root->add_child(channel));

    if (validate)
      chnl->validate();

    if (!chnl->has_index("lastBuildDate"))
      chnl->lastBuildDate = chnl->last_build_date();

    thing_to_node(chnl, channel);

    string res = n && n->render_xml(1);

    if (res && (lower_case(encoding)-"-") == "iso88591")
      res = utf8_to_string(res);

    return res;
  }

  void add_namespace(string name, string value)
  {
    namespace[name] = value;
  }

  void add_namespaces(mapping nss)
  {
    foreach (nss; string name; string val)
      add_namespace(name, val);
  }

  protected void thing_to_node(Thing thing, SimpleNode n)
  {
    mapping data = thing->get_data();
    array keys = indices(data);

    if (thing->type == "channel") {
      // Put the items last
      keys -= ({ "items" });
      keys += ({ "items" });
    }

    foreach (keys, string k) {
      mixed v = data[k]||"";

      if ((lower_case(encoding)-"-") == "iso88591" && stringp(v))
	v = string_to_utf8(v);

      if (objectp(v)) {
	SimpleNode new_node = SimpleElementNode(k, ([]));
	if (stringp(k))
	  n->add_child(new_node);
	thing_to_node(v, new_node);
      }
      else if (arrayp(v)) {
	foreach (v, Thing t) {
	  SimpleNode new_node = SimpleElementNode(t->type, ([]));
	  n->add_child(new_node);
	  thing_to_node(t, new_node);
	}
      }
      else
	n->add_child(SimpleElementNode(k, ([]))->add_child(SimpleTextNode(v)));
    }
  }
}

class Thing
{
  constant type = "thing";
  protected mapping container = ([]);
  protected multiset nmpath_nodes = (< "guid", "link", "url" >);
  
  void create(mapping(string:mixed)|void data)
  {
    data && populate(data);
  }

  void populate(mapping(string:mixed) data)
  {
    foreach (data; string key; mixed val) {
      switch (key)
      {
	case "image":
	  if (stringp(val))
	    val = Image(([ "url" : val ]));
	  break;

	case "date": key = "pubDate";
	case "lastBuildDate":
	case "pubDate":
	  val = fix_date(val);
	  break;
      }
      
      if ( nmpath_nodes[key] )
	val = nmpath(val);

      container[key] = val;
    }
  }
  
  string fix_date(string date)
  {
    if (date && sizeof(date)) {
      mixed o = strtotime(date, 1);
      if (objectp(o))
	date = o->format_http();
    }

    return date;
  }

  mixed `->=(string index, mixed val)
  {
    switch (index)
    {
      case "image":
	if (stringp(val))
	  val = Image(([ "url" : val ]));
	break;

      case "date":
	index = "pubDate";
      case "dc:date":
      case "lastBuildDate":
      case "pubDate":
      	val = fix_date(val);
	break;
    }
    container[index] = val;
    return 1;
  }

  int(0..1) has_index(string which)
  {
    return container[which];
  }

  string get_index(string which)
  {
    return container[which];
  }

  array items()
  {
    return container->items;
  }

  mapping get_data()
  {
    return container;
  }

  string _sprintf(int t)
  {
    return t == 'O' && sprintf("RSS.%s(%O)", String.capitalize(type), container);
  }
}

class Channel
{
  inherit Thing;
  constant type = "channel";
  array req_elements = ({ "title", "link", "description" });

  void create(mapping(string:mixed)|void data)
  {
    container->items = ({});
    populate(data);
  }

  void add_item(Item item)
  {
    container->items += ({ item });
  }

  int validate()
  {
    array missing = ({});
    foreach (req_elements, string k)
      if ( !container[k] )
	missing += ({ k });

    if (sizeof(missing)) {
      string msg = String.implode_nicely(missing);
      string num = sizeof(missing) == 1 ? "" : "s";
      error("RSS.Channel() is missing required element%s: %s\n", num, msg);
      return 0;
    }

    return 1;
  }

  string last_build_date()
  {
    array find = ({ "date", "pubDate", "lastBuildDate", "dc:date" });
    Item i = sizeof(container->items) && container->items[0];
    if (i) {
      foreach (find, string k)
	if (i->has_index(k))
	  return i->get_index(k);
    }
    return 0;
  }

  mixed `+(Item item)
  {
    container->items += ({ item });
    return this_object();
  }

  string _sprintf(int t)
  {
    return t == 'O' && sprintf(
	    "RSS.Channel(\n"
	    "  Title: %s,\n"
	    "  Desc:  %s,\n"
	    "  Link:  %s,\n"
	    "  Items: %d\n)",
	    container->title||"(no title)",
	    container->description||"(no description)",
	    container->link||"(no link)",
	    sizeof(container->items));
  }
}

class Item
{
  inherit Thing;
  constant type = "item";
}

class Image
{
  inherit Thing;
  constant type = "image";
}

//| {{{ strtotime
//|
//! Converts a date string into a Calendar.Second.
//!
//! @param date
//!   A string reprsentation of a date.
//! @param retobj
//!   If 1 the @[Calendar.Second()] object will be returned
//! @returns
//!   Either an ISO formatted date string or the @[Calendar.Second()] object if
//!   @[retobj] is 1. If no conversion can be made @[date] will be returned.
string|Calendar.Second strtotime(string date, int|void retobj)
{
  if (!date || !sizeof(date))
    return 0;

  Calendar.Second cdate;

  string fmt = "%e, %D %M %Y %h:%m:%s %z";

  catch { cdate = Calendar.parse(fmt, date); };

  if (cdate)
    return retobj ? cdate : cdate->format_time();

  fmt = "%Y-%M-%D%*[T ]%h:%m:%s";

  date = replace(date, "Z", "");

  catch { cdate = Calendar.parse(fmt+"%z", date); };

  if (cdate)
    return retobj ? cdate : cdate->format_time();

  catch { cdate = Calendar.parse(fmt, date); };

  if (cdate)
    return retobj ? cdate : cdate->format_time();

  catch { cdate = Calendar.parse("%Y-%M-%D", date); };

  if (cdate)
    return retobj ? cdate : cdate->format_time();

  report_notice("Unknown date format: %s", date);

  return date;
} // }}}

//------------------------------------------------------------------------------

#if constant(roxen)

TAGDOCUMENTATION;
#ifdef manual

#define CWRAP(name, value)                                       \
"<tt>&lt;channel&gt;&lt;" + name + "&gt;"                        \
+ replace(value, ({ "&","<",">" }), ({ "&amp;","&lt;","&gt;" })) \
+ "&lt;/" + name + "&gt;&lt;/channel&gt;</tt>"

#define IWRAP(name, value)                                       \
"<tt>&lt;item&gt;&lt;" + name + "&gt;"                           \
+ replace(value, ({ "&","<",">" }), ({ "&amp;","&lt;","&gt;" })) \
+ "&lt;/" + name + "&gt;&lt;/item&gt;</tt>"

#define PRE(value) "<pre>"                                         \
+ replace(value, ({ "&","<",">" }), ({ "&amp;","&lt;","&gt;" })) + "</pre>"

constant tagdoc = ([
"rss-writer" : ({ #"
  <desc type='cont'>
    <p><short>Creates an RSS channel</short></p>
<ex-box><rss-writer title='Comapny news' description='Latest news from comany'
            link='&roxen.server;' image='&roxen.server;assets/logo.png'
>
  <emit source='site-news' path='/news/*/*.xml' unique-paths=''
        order-by='publish' maxrows='10'
  >
    <add-item title='&_.title;' date='&_.publish' link='&_.path;'>
      <insert file='&_.path;?__xsl=read-preamble.xsl' />
    </add-item>
  </emit>
</rss-writer></ex-box>
  </desc>

  <attr name='title' value='string' required=''>
    <p>The title of the RSS feed, i.e<br/>" +
    CWRAP("title", "News feed from our company") + #"</p>
  </attr>

  <attr name='description' value='string' required=''>
    <p>The description of the RSS feed, i.e<br/>" +
    CWRAP("description", "Latest news from our company") + #"</p>
  </attr>

  <attr name='image' value='string' optional='1'>
    <p>Path to the image to display in the feed, i.e<br/>" +
    CWRAP("image", "&roxen.server;assets/company-logo.png") + #"</p>
  </attr>

  <attr name='link' value='string' optional='1'>
    <p>A link to the main site or section the feed relates to, i.e<br/>" +
    CWRAP("link", "&roxen.server;") + #"</p>
  </attr>

  <attr name='encoding' value='string' optional='1' default='iso-8859-1'>
    <p>The encoding to use for the feed</p>
  </attr>

  <attr name='version' value='float' optional='1' default='2.0'>
    <p>The version of the RSS feed. NOTE! There will be no validation checks
       so it really doesn't matter if this value is 2.0 or 0.9 or what ever.
       It's just for display ;)</p>
  </attr>", ([

  // Sub tag
  "add-item" : ({ #"
    <desc type='both'>
      <p><short>Adds an RSS item to the channel. If used as a container the
      description of the item should be the content.</short></p>
    </desc>
    
    <attr name='title' value='string' required=''>
      <p>The title of the RSS item, i.e<br/>" +
      IWRAP("title", "New product available") + #"</p>
    </attr>
    
    <attr name='link' value='string' required=''>
      <p>The link to the news item, i.e<br/>" +
      IWRAP("link", "&roxen.server;path/to/item/") + #"</p>
    </attr>
    
    <attr name='date' value='string' required=''>
      <p>The publish date of the item. This will generate a 
         <tt>&lt;pubDate/&gt;</tt> node with a valid RSS date, i.e<br/>" +
	 IWRAP("pubDate", "Sun, 05 Oct 2008 13:45:16 GMT") + #"</p>
    </attr>

    <attr name='description' value='string'>
      <p>If <tag>add-item</tag> is used as a tag the description node will get
      its value from this attribute, i.e<br/>" +
      IWRAP("description", "Erlier to day we released a new...") + #"</p>
    </attr>" })
  ])
})
]);
#endif /* manual */
#endif /* constant(roxen) */

