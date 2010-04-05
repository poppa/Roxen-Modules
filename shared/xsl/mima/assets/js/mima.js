if (!window.console) window.console = { log: function() {} };

var Mima = 
{ 
  Root: null,
  FixRadios: function(form)
  {
    $(form).find('input[type=radio]').each(function(i, el) {
      if (!el.checked) {
      	var f = $('<input type="hidden" name="' + el.name + '" value="n" />');
      	el.name = "__discart";
      	$(el).after(f);
      }
    });
  },

  wget: function(endpoint, params, callback)
  {
    var ep = new URI(endpoint);
    ep.variables['__xsl'] = 'ajax.xsl';
    var p = Mima.Root + 'index.xml' + ep.toString();
    $.ajax({
      url: p,
      data: params,
      success: function(data) {
      	if (callback) callback(data);
      }
    });
  },

  UserSelect: function(data)
  {
    data = eval(data);
    if (!data.length)
      return;

    var ufield = $('#username');
    var ffield = $('#fullname');
    var efield = $('#email');

    if (data.length == 1) {
      data = data[0];
      ufield.val(data.name);
      ffield.val(data.fullname);
      return;
    }

    var s = $('<div class="dynamic-select"></div>');
    
    for (var i = 0; i < data.length; i++) {
      var d = data[i];
      var a = '<a name="{0}" fullname="{1}" email="{2}"><span>{1}</span></a>';
      a = $(String.format(a, d.name, d.fullname, d.email||""));
      a.click(function() {
      	ufield.val(this.name);
      	ffield.val($(this).attr('fullname'));
      	efield.val($(this).attr('email'));
      });

      s.append(a);
    }
    var pos = ufield.position();
    s.css({
      top: pos.top + ufield.height() + 5,
      left: pos.left
    });

    $(document.body).click(function(e) {
      if (!$(e.target).is(s))
      	s.remove();
    }).append(s);
  }
};

var $ID = function(id) { return $("#" + id); };

var trace = function(message) // {{{
{
  if (typeof message == 'string')
    for (var i = 0; i < arguments.length; i++)
      message = message.replace("{" + i + "}", arguments[i+1]);

  console.log(message);
}; // }}}

String.format = function(format) // {{{
{
  for (var i = 0; i < arguments.length; i++) {
    var re = new RegExp("\\\{" + i + "\\\}", "g");
    format = format.replace(re, arguments[i+1]);
  }

  return format;
}; // }}}

var Form = // {{{ 
{
  Input: // {{{
  {
    Clear: function(input, defaultValue)
    {
      if (input.value == defaultValue)
	input.value = "";
    },
    
    Reset: function(input, defaultValue)
    {
      if (input.value.length == 0)
	input.value = defaultValue;
    },
    
    Focus: function(which)
    {
      
    }
  }, // }}}

  ChecboxToggle: function(enable, disable)
  {
    if (enable)
      $(enable).each(function(i,e){ $(e).attr('disabled', false); });
    if (disable)
      $(disable).each(function(i,e){ $(e).attr('disabled', true); });
  },

  Error: // {{{
  {
    errors: [],
    form: null,
    Append: function(id, message)
    {
      if (!Form.Error.form)
      	Form.Error.form = this.findForm(document.getElementById(id));

      var h = "<div class='form-error'>" +
              "<a href='javascript:void(0)'" +
              " onclick='document.location=\"#{0}\";$(\"#{0}\").focus();'>" +
              "{1}</a></div>";

      Form.Error.errors.push($(String.format(h, id, message)));
      $('#' + id).addClass('error');
    },
    
    Print: function()
    {
      var form = $(this.form);
      var wrap = $("<div class='form-errors'><p>Some errors occured!</p></div>");
      $(this.errors).each(function(i, el) { wrap.append(el); });

      wrap.insertBefore(form);
    },
    
    findForm: function(child)
    {
      var p = child;
      while ((p = p.parentNode) != null)
      	if (p.nodeName == 'FORM')
	  return p;
    }
  } // }}}
}; // }}}

function require(url) // {{{
{
  $('head').append($('<script type="text/javascript" src="'+url+'"></script>'));
} // }}}

jQuery.fn.extend({ // {{{
  lessAndMore: function(settings)
  {
    _owner = this;

    var lm = $("<div class='" + (settings.moreClass||"") + "'>" +
               "<a href='javascript:void(0)'><span>" +
               (settings.moreText||"More info") + "</span></a></div>");
    lm.find('a').click(function() {
      if ((_owner).css('display') == 'none') {
        this.className = settings.lessClass||"";
        $(this).find('span').text(settings.lessText);
      }
      else {
        this.className = settings.moreClass||"";
        $(this).find('span').text(settings.moreText);
      }

      _owner.slideToggle('fast');
      return false;
    });

    $(this).css('display','none');
    lm.insertBefore($(this));
    var padder = $("<div style='height:10px;'></div>");
    padder.insertAfter($(this));

    my = {
      owner: _owner,
      conf: settings
    };
  },

  helpLabel: function(settings)
  {
    var label = function(elem)
    {
      //trace(this);
      var my = this;
      this.img = $('<img src="' + settings.img + '" />');
      this.img.css({
	'margin-left' : 4,
	'margin-bottom' : -3,
	'display' : 'inline-block',
	'position' : 'relative',
	'float' : 'none'
      });
      this.img.mouseover(function() {
	my.ele.toggle('fast');
      });
      this.img.mouseout(function() {
	my.ele.toggle('fast');
      });
      this.ele = $(elem);
      this.ele.removeClass('help');
      this.ele.addClass(settings['class']);
      this.img.insertBefore(this.ele);
      var pos = this.img.position();
      this.ele.css({
	'display'   : 'none',
	'position'  : 'absolute',
	'z-index'   : 10000,
	'left'      : pos.left + this.img.width() + 10,
	'top'       : pos.top - 8
      });
    };

    for (var i = 0; i < this.length; i++)
      new label(this[i]);
  },

  typeListen: function(callback, delay)
  {
    var typeListener = function(obj, callback, delay)
    {
      var my = this;
      this.obj = $(obj);
      this.cb = callback;
      this.time = 0;
      this.delay = delay||500;

      this.obj.keypress(function(e) 
      {
      	if (my.time) clearInterval(my.time);
      	//trace(e.which + " | " + e.charCode);
      	switch (e.charCode)
      	{
	  case  0: // non-char
	  case 32: // space
	    // 46 is delete key.
	    // This can be backspace for instance
	    if (e.keyCode == 46 || e.which != 0 && e.which != e.charCode) 
	      break;

	    return;
      	}

      	my.time = setTimeout(function() {
	  callback(my.obj);
      	}, my.delay);
      });
    };

    if (this.length > 0)
      new typeListener(this[0], callback, delay);
  }
}); // }}}

var DynamicInput = function(element) // {{{
{
  var my = this;
  this.el = $(element);
  this.container = this.el.parent();
  this.target = this.el.prev();
  this.cwidth = this.container.width()-20;

  this.input = function()
  {
    var ip = $('<input type="text" style="display:inline;margin:0;' +
               'padding:1px 2px" />');

    ip.css('width', '97%');
    ip.val(this.el.text());
    ip.blur(function() {
      if (this.value.length == 0) {
	alert("This field can not be empty");
	ip.focus();
	return;
      }
      my.el.text(this.value);
      my.target.val(this.value);
      my.el.css('display','inline');
      $(this).remove();
    });
    this.el.css('display', 'none');
    this.container.append(ip);
    ip.focus();
  };

  this.el.click(function() {
    my.input();
  });
}; // }}}

var TypeListener = function(field)
{
  this.field = $("#" + field);
  
};

// When DOM is ready
$(function() {
  $('table.dnd').tableDnD({
    onDragClass: 'drag',
    onDrop: function(tbl, row) {
      $(row).removeClass('dragging');
      var rows = tbl.tBodies[0].rows;
      for (var i = 0; i < rows.length; i++)
      	$(rows[i].cells[0]).find('input[class=order]').val(i);
    },
    onDragStart: function(tbl, row) {
      $(row).addClass('dragging');
    }
  });

  $('span.dynamic-input').each(function(i, el) {
    new DynamicInput(el);
  });

  $('a.select-all-cb').each(function(i, el) {
    el.toggleState = false;
    $(el).click(function() {
      var my = this;
      var f = this;
      while (f = f.parentNode)
      	if (f.nodeName == 'FORM')
      	  break;

      $(f).find('input[type=checkbox]').each(function(i, cb) {
      	if (!my.toggleState)
      	  cb.checked = true;
      	else
      	  cb.checked = false;
      });
      this.toggleState = !this.toggleState;
      return false;
    });
  });

  if (Form.Error.form)
    Form.Error.Print();
  
  $('.help').helpLabel({
    'img'   : Mima.Root + 'assets/img/icons/info_16.png',
    'class' : 'the-help'
  });

  $('div.less-more-files').lessAndMore({ lessClass: 'less',
                                         moreClass: 'more',
                                         moreText:  'Show files',
                                         lessText:  'Hide files' });
  $('div.less-and-more').lessAndMore({ lessClass: 'less',
                                       moreClass: 'more',
                                       moreText:  'More information',
                                       lessText:  'Less information' });
});
