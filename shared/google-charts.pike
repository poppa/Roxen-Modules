// This is a Roxen® module
// Author: Pontus Östlund <pontus@poppa.se>
//
// Tab width:    8
// Indent width: 2

#include <module.h>
inherit "module";

constant thread_safe = 1;
//constant module_unique = 1;
constant module_type = MODULE_TAG;
constant module_name = "Poppa Tags: Google Charts";
constant module_doc  = "This module provides tags for generating charts "
                       "with Google Chart";

import WS.Google;

#define GC_DEBUG

#ifdef GC_DEBUG
# define TRACE(X...) report_debug(X)
#else
# define TRACE(X...) 0
#endif

#define TRIM(X) String.trim_all_whites((X))

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus �stlund <pontus@poppa.se>");
} // }}}

void start(int when, Configuration _conf) {}

class TagGoogleChart // {{{
{
  inherit RXML.Tag;

  constant name = "google-chart";

  //! Types of charts supported
  multiset valid_types = (< "line", "bar", "pie" >);

  //! The type attribute id needed
  mapping(string:RXML.Type) req_arg_types = ([
    "type" : RXML.t_text(RXML.PEnt)
  ]);

  //! Optional arguments
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

    //! Y-axis object
    Chart.Axis yaxis;
    
    //! X-axis object
    Chart.Axis xaxis;

    //! Callbacks for sub tags
    mapping(string:function) subtags = ([
      "xaxis" : _xaxis,
      "yaxis" : _yaxis,
      "grid"  : _grid
    ]);
    
    //! Callbacks for sub container tags
    mapping(string:function) subcont = ([
      "data" : _data
    ]);

    //! Callback for @tt{<xaxis/>@}
    string _xaxis(string tag, mapping args, mapping extra)
    {
      TRACE("+ Got XAxis: %O\n", args);
      xaxis = Chart.Axis("x");
      
      if (args->start && args->stop)
	xaxis->set_range(args->start, args->stop, args->interval||10);
      
      if (args->labels)
	xaxis->set_labels(map(args->labels/",", String.trim_all_whites));

      return "";
    }
    
    //! Callback for @tt{<yaxis/>@}
    string _yaxis(string tag, mapping args, mapping extra)
    {
      TRACE("+ Got YAxis: %O\n", args);
      yaxis = Chart.Axis("y");

      if (args->start && args->stop)
	yaxis->set_range(args->start, args->stop, args->interval||10);

      if (args->labels)
	yaxis->set_labels(map(args->labels/",", String.trim_all_whites));

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
    
    //! Callback for @tt{<data></data>@}
    string _data(string tag, mapping args, string data, mapping extra)
    {
      string sep = args->separator||",";
      array(array(string)) lines = map(TRIM(data)/(args->rowseparator||"\n"), 
	lambda (string s) {
	  return map(TRIM(s)/sep, String.trim_all_whites);
	}
      );

      array(string) colors = args->color && map(args->color/",", fix_color);
      array(string) legends = args->legend &&
                              map(args->legend/",", String.trim_all_whites);

      int i = 0;
      foreach (lines, array(string) line) {
	Chart.Data d = Chart.Data(@line);

	if (args->min && args->max)
	  d->set_scale((int)args->min, (int)args->max);
	
	if (legends && has_index(legends, i))
	  d->set_legend( legends[i], args["legend-position"] );

	if (colors && has_index(colors, i))
	  d->set_color( colors[i] );

	if (!dataset) dataset = d;
	else dataset += d;
	
	i++;
      }

      TRACE("Datset: %O\n", dataset);

      return "";
    }

    array do_return(RequestID id)
    {
      if (!( valid_types[args->type] )) {
	RXML.parse_error("Bad type argument. Must be one of %s",
                         String.implode_nicely((array)valid_types, "or"));
      }

      TRACE("\n\n>>> Make %s chart\n", args->type);

      int    iwidth   = (int)(args->width);
      int    iheight  = (int)(args->height);
      string bg_color = fix_color(args->bgcolor||"ffffff");
      string color    = fix_color(args->color||"333333");
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

      if (args->title)
	chart->set_title(args->title, args["title-size"], 
                         fix_color( args["title-color"] ));

      if (args->type == "bar") {
	array(int) barparams = ({
	  (int)(args["bar-width"]||10),
	  (int)(args["bar-space"]||1),
	  (int)(args["group-space"]||10)
	});

	TRACE("Bar params: %O\n", barparams);

	chart->set_bar_params(@barparams);
      }

      dataset = 0;

      if (sizeof(TRIM(content)))
	parse_html(content, subtags, subcont, args);

      if ( grid && (< "bar", "line" >)[args->type] )
	chart->set_grid(grid);

      if (xaxis) chart->add_axis(xaxis);
      if (yaxis) chart->add_axis(yaxis);

      if (!dataset)
	RXML.parse_error("Missing required subtag \"data\"!");

      TRACE("Chart: %O\n", chart->render_url(dataset));

      result = sprintf(
	"<img src='%s' alt='%s' title='' width='%d' height='%d' />",
	chart->render_url(dataset), args->title||"", iwidth, iheight
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