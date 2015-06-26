#charset utf-8

#include <module.h>
inherit "roxen-module://shared-component-code";

import Sitebuilder.Editor;
import Parser.XML.Tree;

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)     _STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("sitebuilder",X,Y)


constant module_name = "TVAB Editor Component: Tablify";
// constant module_doc = "To be provided";

class TablifyComponentPlugin
{
  inherit AbstractComponentPlugin;

  string get_component_name()
  {
    return LOCALE(0, "Tablify");
  }

  string get_component_tag()
  {
    return "tablify-component";
  }

  array(string) get_component_fields()
  {
    return ({ "variant",
              "file",
              "data",
              "caption",
              "cellseparator",
              "rowseparator",
              "interactive",
              "titlerow",
              "sortcol",
              "squeeze",
              "align",
              "type",
              "linkify",
              "abspath",
              "rowtitles",
              "html" });
  }

  mapping(int:string) get_component_variants()
  {
    return ([]);
  }

  mapping(string:string) get_component_defaults()
  {
    return ([ "interactive" : "no",
              "titlerow"    : "no",
              "sortcol"     : "0",
              "squeeze"     : "no",
              "linkify"     : "no",
              "rowtitles"   : "no",
              "html"        : "no" ]);
  }

  multiset(string) get_unquoted_fields()
  {
    return (< "data" >);
  }
}

class TablifyComponentInstance
{
  inherit AbstractComponentInstance;

  string render_editor(string var_prefix, RequestID id)
  {
    string data = get_data_data(var_prefix, "data", get_field("data"),
                                get_field("rowseparator"), id);
    string res =
      render_field("file",
                   ([ "title"   : LOCALE(0, "Fil"),
                      "type"    : "file",
                      "size"    : "60",
                      "name"    : var_prefix + "file" ]), id) +
      render_field("data",
                   ([ "title"   : LOCALE(0, "Data"),
                      "type"    : "text",
                      "rows"    : "20",
                      "cols"    : "90",
                      "value"   : data,
                      "name"    : var_prefix + "data" ]), id) +
      render_field("caption",
                   ([ "title"   : LOCALE(0, "Tabellrubrik"),
                      "type"    : "string",
                      "size"    : "60",
                      "name"    : var_prefix + "caption" ]), id) +
      render_field("align",
                   ([ "title"   : LOCALE(0, "Justeringsregel"),
                      "type"    : "string",
                      "size"    : "60",
                      "name"    : var_prefix + "align" ]), id) +
      render_field("type",
                   ([ "title"   : LOCALE(0, "Typregler"),
                      "type"    : "string",
                      "size"    : "60",
                      "name"    : var_prefix + "type" ]), id) +
      render_field("rowseparator",
                   ([ "title"   : LOCALE(0, "Radavgränsare (tom = radbrytning)"),
                      "type"    : "string",
                      "size"    : "2",
                      "name"    : var_prefix + "rowseparator" ]), id) +
      render_field("cellseparator",
                   ([ "title"   : LOCALE(0, "Cellavgränsare (tom = tabb)"),
                      "type"    : "string",
                      "size"    : "2",
                      "name"    : var_prefix + "cellseparator" ]), id) +
      render_field("sortcol",
                   ([ "title"   : LOCALE(0, "Sortera efter kolumn (0 = Ingen sortering)"),
                      "type"    : "int",
                      "size"    : "2",
                      "name"    : var_prefix + "sortcol" ]), id) +
      render_field("titlerow",
                   ([ "title"   : LOCALE(0, "Celltitlar"),
                      "type"    : "select",
                      "options" : ([ "no" : "Nej", "yes" : "Ja" ]),
                      "name"    : var_prefix + "titlerow" ]), id) +
      render_field("rowtitles",
                   ([ "title"   : LOCALE(0, "Radtitlar"),
                      "type"    : "select",
                      "options" : ([ "no" : "Nej", "yes" : "Ja" ]),
                      "name"    : var_prefix + "rowtitles" ]), id) +
      render_field("interactive",
                   ([ "title"   : LOCALE(0, "Interaktiv sortering"),
                      "type"    : "select",
                      "options" : ([ "no" : "Nej", "yes" : "Ja" ]),
                      "name"    : var_prefix + "interactive" ]), id) +
      render_field("squeeze",
                   ([ "title"   : LOCALE(0, "Slå ihop tomma celler"),
                      "type"    : "select",
                      "options" : ([ "no" : "Nej", "yes" : "Ja" ]),
                      "name"    : var_prefix + "squeeze" ]), id) +
      render_field("html",
                   ([ "title"   : LOCALE(0, "Tillåt HTML"),
                      "type"    : "select",
                      "options" : ([ "no" : "Nej", "yes" : "Ja" ]),
                      "name"    : var_prefix + "html" ]), id) +
      render_field("linkify",
                   ([ "title"   : LOCALE(0, "Gör webbadresser klickbara"),
                      "type"    : "select",
                      "options" : ([ "no" : "Nej", "yes" : "Ja" ]),
                      "name"    : var_prefix + "linkify" ]), id);

    return res;
  }

  string get_tag_data(string t, mapping a, string d, mapping r)
  {
    if (sizeof(d)) r->data = d;
    return "";
  }

  string get_data_data(string var_prefix, string field, string xml, string rs,
                       RequestID id)
  {
    if (!sizeof(xml)) return "";

    mapping align = ([]);
    xml = parse_html(xml, ([]), ([ "align" : get_tag_data ]), align);
    xml = Roxen.html_decode_string(xml);
    if (align->data) {
      if (!rs || rs == "") rs = "\n";
      xml = "<align>" + align->data + "</align>" + rs + xml;
    }

    mapping type = ([]);
    xml = parse_html(xml, ([]), ([ "type" : get_tag_data ]), type);
    xml = Roxen.html_decode_string(xml);
    if (type->data) {
      if (!rs || rs == "") rs = "\n";
      xml = "<type>" + align->data + "</type>" + rs + xml;
    }

    return xml;
  }

  string get_data_from_form(string var_prefix, string field, RequestID id)
  {
    string data = id->variables[var_prefix + field];
    if (!sizeof(data)) return "";

    mapping align = ([]);
    data = parse_html(data, ([]), ([ "align" : get_tag_data ]), align);
    data = Roxen.html_encode_string(data);
    if (align->data) {
      string sep = id->variables[var_prefix + "rowseparator"];
      if (!sep || sep == "") sep = "\n";
      data = "<align>" + align->data + "</align>" + sep + data;
    }

    mapping type = ([]);
    data = parse_html(data, ([]), ([ "type" : get_tag_data ]), type);
    data = Roxen.html_encode_string(data);
    if (type->data) {
      string sep = id->variables[var_prefix + "rowseparator"];
      if (!sep || sep == "") sep = "\n";
      data = "<type>" + align->data + "</type>" + sep + data;
    }

    return data;
  }

  void save_variables(string var_prefix, RequestID id)
  {
    string data    = get_data_from_form(var_prefix, "data", id);
    string abspath = id->variables[var_prefix + "abspath"];
    string file    = id->variables[var_prefix + "file"];
    if (sizeof(file) && !has_prefix(file, "/"))
      file = combine_path("/" + id->misc->sbobj->dirpath, file);

    set_field( "abspath",       abspath||"off"                              );
    set_field( "file",          file                                        );
    set_field( "caption",       id->variables[var_prefix + "caption"]       );
    set_field( "align",         id->variables[var_prefix + "align"]         );
    set_field( "type",          id->variables[var_prefix + "type"]          );
    set_field( "data",          data                                        );
    set_field( "rowseparator",  id->variables[var_prefix + "rowseparator"]  );
    set_field( "cellseparator", id->variables[var_prefix + "cellseparator"] );
    set_field( "sortcol",       id->variables[var_prefix + "sortcol"]       );
    set_field( "titlerow",      id->variables[var_prefix + "titlerow"]      );
    set_field( "interactive",   id->variables[var_prefix + "interactive"]   );
    set_field( "squeeze",       id->variables[var_prefix + "squeeze"]       );
    set_field( "linkify",       id->variables[var_prefix + "linkify"]       );
    set_field( "html",          id->variables[var_prefix + "html"]          );
    set_field( "rowtitles",     id->variables[var_prefix + "rowtitles"]     );
  }
}
