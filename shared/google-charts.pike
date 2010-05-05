/* -*- Mode: Pike; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
//! @b{Google Charts@}
//!
//! Copyright © 2010, Pontus Östlund - @url{www.poppa.se@}
//!
//! @pre{@b{License GNU GPL version 3@}
//!
//! google-charts.pike is free software: you can redistribute it and/or 
//! modify it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! google-charts.pike is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with google-charts.pike. If not, see 
//! <@url{http://www.gnu.org/licenses/@}>.
//! @}

#include <module.h>
inherit "module";

constant thread_safe   = 1;
constant module_unique = 1;
constant module_type   = MODULE_TAG;
constant module_name   = "TVAB Tags: Google Charts";
constant module_doc    = "This module provides tags for generating charts "
                         "with Google Chart";

import WS.Google;

//#define GC_DEBUG

#ifdef GC_DEBUG
# define TRACE(X...) report_debug(X)
#else
# define TRACE(X...) 0
#endif

#define TRIM(X) String.trim_all_whites((X))

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus &Ouml;stlund <pontus@poppa.se>");
} // }}}

void start(int when, Configuration _conf) {}

//! These attributes shall be removed from the @tt{<google-char />@} args.
//! What's left will be passed as attributes to the generated @tt{<img/>@} tag.
constant google_attributes = (<
  "type",
  "subtype",
  "bgcolor",
  "color",
  "title-color"
  "title-size",
  "bar-width",
  "bar-space",
  "bar-group-space",
  "group-space"
>);

class TagGoogleChart // {{{
{
  inherit RXML.Tag;

  constant name = "google-chart";

  multiset valid_types = (< "line", "bar", "pie" >);

  mapping(string:RXML.Type) req_arg_types = ([
    "type" : RXML.t_text(RXML.PEnt)
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "width"           : RXML.t_text(RXML.PEnt),
    "height"          : RXML.t_text(RXML.PEnt),
    "bgcolor"         : RXML.t_text(RXML.PEnt),
    "color"           : RXML.t_text(RXML.PEnt),
    "title"           : RXML.t_text(RXML.PEnt),
    "title-color"     : RXML.t_text(RXML.PEnt),
    "title-size"      : RXML.t_text(RXML.PEnt),
    "bar-width"       : RXML.t_text(RXML.PEnt),
    "bar-space"       : RXML.t_text(RXML.PEnt),
    "bar-group-space" : RXML.t_text(RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;

    //! Chart data set
    Chart.Data dataset;

    //! Chart grid
    Chart.Grid grid;

    array(mapping(string:mapping|Chart.Axis)) axes;

    //! Callbacks for sub tags
    mapping(string:function) subtags = ([
      "xaxis" : _axis,
      "yaxis" : _axis,
      "grid"  : _grid
    ]);
    
    //! Callbacks for sub container tags
    mapping(string:function) subcont = ([
      "data" : _data
    ]);

    //! Callback for @tt{<xaxis/>@} and @tt{<yaxis/>@}
    string _axis(string tag, mapping args, mapping extra)
    {
      TRACE("+ Got %O: %O\n", tag, args);
      string defpos = tag == "xaxis" ? "x" : "y";
      Chart.Axis tmp = Chart.Axis(args->position||defpos);

      if (args->start && args->stop)
	tmp->set_range(args->start, args->stop, args->interval||10);

      if (args->labels) {
	tmp->set_labels(map(args->labels/(args->split||","), 
	                    String.trim_all_whites));
      }

      axes += ({ ([ "args" : args, "axis" : tmp ]) });

      return "";
    }

    //! Callback for @tt{<grid/>@}
    string _grid(string tag, mapping args, mapping extra)
    {
      TRACE("+ Got Grid: %O\n", args);
      grid = Chart.Grid((int)args->xstep, (int)args->ystep, (int)args->length, 
                        (int)args->space);
      return "";
    }

    Chart.Axis get_axis_by_id(string id)
    {
      TRACE("Axes: %O\n", axes);
      foreach (axes, mapping ax)
	if (ax->args->id && ax->args->id == id)
	  return ax->axis;

      return 0;
    }
    
    //! Callback for @tt{<data></data>@}
    string _data(string tag, mapping args, string data, mapping extra)
    {
      string sep = args->separator||",";
      array(array(string)) lines = map(TRIM(data)/(args->rowseparator||"\n"),
	lambda (string s) {
	  return map(TRIM(s)/sep, String.trim_all_whites);
	}
      );

      if (args->form && args->form == "columns") {
	array(int) ind = ({});

	int amax = 0;
	int len;

	// Here we need to level out the arrays so that each sub array is
	// equally long. First we find the longest array and save that number
	// of indices in "amax". Then we loop over the array again and zero
	// fill every array that's shorter than "amax". If not equally long
	// Array.columns will throw an "Array out of index exception".

	foreach (lines, array line)
	  if ((len = sizeof(line)) > amax)
	    amax = len;

	for (int j = 0; j < sizeof(lines); j++) {
	  array line = lines[j];
	  if (sizeof(line) < amax)
	    for (int i = amax; i > 0; i--)
	      lines[j] += ({ "0" });
	}

	for (int i; i < amax; i++)
	  ind += ({ i });

	lines = Array.columns(lines, ind);
      }

      array(string) colors = args->color && map(args->color/",", 
                                                String.trim_all_whites);
      array(string) legends = args->legend && map(args->legend/",",
                                                  String.trim_all_whites);

      if (legends && sizeof(legends) && args->form && args->form == "columns")
	lines = lines[1..];

      int i = 0;
      foreach (lines, array(string) line) {
	Chart.Data d = Chart.Data(@line);

	if (args->min && args->max)
	  d->set_scale((int)args->min, (int)args->max);
	else if ( string s = args["ceil-to-nearest"] ) {
	  [float minval, float maxval] = d->get_min_max();
	  minval = 0; //round_to_nearest(minval, 100);
	  maxval = Chart.ceil_to_nearest(maxval, (int)s);
	  d->set_scale(0, maxval);
	}

	if (legends && has_index(legends, i))
	  d->set_legend( legends[i], args["legend-position"] );

	if (colors && has_index(colors, i)) {
	  TRACE("Set color %O for index %d\n", colors[i], i);
	  d->set_color( colors[i] );
	}
	else
	  TRACE("No color for index %d\n", i);

	if (!dataset) dataset = d;
	else dataset += d;

	i++;
      }

      TRACE("Datset: %O\n", dataset);

      return "";
    }

    void set_auto_range(Chart.Axis axis, mapping args)
    {
      [float mi, float ma] = dataset->get_min_max();
      TRACE("MAX VAL: %O\n", ma);
      int base = 10000000;
      switch (sizeof((string)(int)ma))
      {
	case 7: base = 1000000; break;
	case 6: base =  100000; break;
	case 5: base =   10000; break;
	case 4: base =    1000; break;
	case 3: base =     100; break;
	case 2: base =      10; break;
	case 1: base =       1; break;
      }

      if (args->base)
	base = (int)args->base;

      axis->set_range(0, (int)ma, base);
    }

    array do_return(RequestID id)
    {
      if (!( valid_types[args->type] )) {
	RXML.parse_error("Bad type argument. Must be one of %s",
                         String.implode_nicely((array)valid_types, "or"));
      }

      TRACE(">>> Make %s chart\n", args->type);

      //! Reset globals since we don't want them cached
      dataset = 0;
      grid    = 0;
      axes    = ({});

      int    iwidth   = (int)(args->width);
      int    iheight  = (int)(args->height);
      string bg_color = (args->bgcolor||"ffffff");
      string color    = (args->color||"333333");
      string subtype  = args->subtype;

      Chart.Base chart;

      switch (args->type)
      {
	case "line":
	  // Default subtype: Chart.Line.LINES
	  chart = Chart.Line(subtype||"lc", iwidth, iheight);
	  break;

	case "bar":
	  // Default subtype: Chart.Bar.VERTICAL_STACK
	  chart = Chart.Bar(subtype||"bvs", iwidth, iheight);
	  break;

	case "pie":
	  // Default subtype: Chart.Pie.BASIC
	  chart = Chart.Pie(subtype||"p", iwidth, iheight);
	  break;

	default:
	  // Nothing
      }

      if (args->title) {
	chart->set_title(args->title, args["title-size"],
                         args["title-color"]);
      }

      if (args->type == "bar") {
	array(string) barparams = ({
	  (args["bar-width"]||"a"),
	  (args["bar-space"]||"1"),
	  (args["group-space"]||"10")
	});

	TRACE("Bar params: %O\n", barparams);

	chart->set_bar_params(@barparams);
      }

      dataset = 0;

      if (sizeof(TRIM(content)))
	parse_html(content, subtags, subcont, args);

      if (!dataset)
	RXML.parse_error("Missing required subtag \"data\"!");

      if (axes && sizeof(axes->args->auto - ({ 0 })) > 0) {
	foreach (axes, mapping ax)
	  if (ax->args->auto)
	    set_auto_range(ax->axis, ax->args);
      }

      if ( grid && (< "bar", "line" >)[args->type] )
	chart->set_grid(grid);

      foreach (axes||({}), mapping ax)
	chart->add_axis(ax->axis);

//    TRACE("Chart: %O\n", chart->render_url(dataset));

      mapping attr = ([]);

      foreach (args; string akey; string aval)
	if ( !google_attributes[akey] )
	  attr[akey] = (string)aval;

      if (!attr->alt)
	attr->alt = args->title||"Diagram";

      result = sprintf(
	"<img src='%s'%{ %s='%s'%} />",
	chart->render_url(dataset), (array)attr
      );

      return 0;
    }
  }
} // }}}

//! Fix colors: @tt{36a@} will become @tt{3366AA@}
//!
//! @param c
string fix_color(string c)
{
  if (!c || sizeof(c) < 3) 
    return "";

  if (c[0] == '#')
    c = c[1..];

  switch (sizeof(c))
  {
    case 3:
    case 4: // For transparency
      c = map( c/1, lambda(string s) { return s*2; } )*"";
      break;
  }

  return upper_case(c);
}