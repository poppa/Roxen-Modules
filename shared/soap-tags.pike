#include <module.h>
#include <config.h>
inherit "module";

import Standards.SimpleSOAP;

//#define SOAP_DEBUG

#ifdef SOAP_DEBUG
# define TRACE(X...) report_debug("SOAP: %s", sprintf(X))
#else
# define TRACE(X...)
#endif

constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "TVAB Tags: SOAP";
constant module_doc  = "Provides tags to make SOAP calls";

Configuration conf;

void create(Configuration _conf) // {{{
{
  set_module_creator("Pontus Östlund <spam@poppa.se>");
} // }}}

void start(int when, Configuration _conf) // {{{
{
  conf = _conf;
} // }}}

class TagSoap
{
  inherit RXML.Tag;
  constant name = "soap";

  mapping(string:RXML.Type) req_arg_types = ([
    "wsdl-url"  : RXML.t_text(RXML.PXml),
    "operation" : RXML.t_text(RXML.PXml)
  ]);

  array(Param) soap_params;

  class TagSoapResult
  {
    inherit RXML.Tag;
    constant name = "soap-result";

    class Frame
    {
      inherit RXML.Frame;
      array(mixed) ret;
      mapping(string:mixed) vars;
      int i, counter, last;

      array do_enter(RequestID id)
      {
        if (!(RXML_CONTEXT->misc->soap))
          RXML.parse_error("Missing context RXML->misc->soap.\n");

        ret = RXML_CONTEXT->misc->soap->response||({});
	last = sizeof(ret);
        counter = 0;
        i = 0;
        return 0;
      }

      int do_iterate(RequestID id)
      {
        if (i >= last)
          return 0;

	if (!mappingp( ret[i] ))
	  vars = ([ "value" : ret[i++] ]);
	else
	  vars = ret[i++];

	foreach (vars; string key; mixed value) {
	  if (objectp(value)) {
	    if (Standards.SimpleSOAP.is_date_object(value))
	      value = value->format_time();
	    else if (catch(value = value->cast("string")))
	      TRACE("No cast method in object\n");

	    vars[key] = value;
	  }
	}

        vars["counter"] = ++counter;
        return 1;
      }

      array do_process(RequestID id)
      {
	if (content != RXML.Nil)
	  result = Roxen.parse_rxml(content||"", id);
        return 0;
      }

      array do_return(RequestID id)
      {
        if (content == RXML.nil)
	  result = "";

        return 0;
      }
    }
  }
  
  // Just for catching the tags. They are parsed in the main frame
  class TagSoapParam
  {
    inherit RXML.Tag;
    constant name = "soap-param";
    class Frame
    {
      inherit RXML.Frame;
      array do_return(RequestID id) {}
    }
  }

  RXML.TagSet internal = RXML.TagSet(
    this_module(), "TagSoap", ({ TagSoapResult(), TagSoapParam() })
  );

  class Frame // TagSoap frame
  {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    int do_iterate;

    array do_enter(RequestID id)
    {
      if (RXML_CONTEXT->misc->soap)
        parse_error("<%s> can not be nested.\n", name);

      soap_params = ({});
      do_iterate = 1;

      mapping tags  = ([ "soap-param" : soap_param_cb ]);
      mapping conts = ([ "soap-param" : soap_param_cb ]);

      parse_html(content, tags, conts, 1, id);

      Client cli = Client();
      Response res;
      if (mixed e = catch(res = cli->invoke(args["wsdl-url"], args->operation, 
	                                    soap_params)))
      {
	RXML.parse_error("%s\n", describe_error(e));
      }

      if (!res)
	RXML.parse_error("Error calling SOAP service!");

      if (res->is_fault()) {
	RXML.parse_error("SOAP error: %s\n",
                         res->get_fault()->get_string()||"unknown");
      }

      string result_collect;
      parse_html(content, ([ "soap-result" :
	lambda (string tag, mapping attr, string cont) {
	  if (attr->name)
	    result_collect = attr->name;
	}
      ]),([]), 1);

      array ret;
      if (result_collect)
	ret = res->get_named_items(result_collect);
      else
	ret = values(res->get_result());

      RXML_CONTEXT->misc->soap = ([
	"response" : ret
      ]);
    }

    array do_return(RequestID id)
    {
      result = content;
      m_delete(RXML_CONTEXT->misc, "soap");
      return 0;
    }

    string soap_param_cb(string tag, mapping m, string cont, int what,
                         RequestID id)
    {
      if (!m->name)
	RXML.parse_error("%s: Missing required attribute \"name\"", tag);

      soap_params += ({ Param(m->name, Roxen.parse_rxml(m->value||cont, id)) });
      return cont;
    }
  }
}