<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <!-- Tickets -->
  <xsl:template name="mima-admin-tickets"><!-- {{{ -->
    <h2 class="no-top-margin">Ticket types</h2>
    <xsl:call-template name="mima-admin-field-table">
      <xsl:with-param name="group" select="'ticket-type'" />
    </xsl:call-template>
  </xsl:template><!-- }}} -->

  <!-- Priorities -->
  <xsl:template name="mima-admin-priorities"><!-- {{{ -->
    <h2 class="no-top-margin">Ticket priorities</h2>
    <xsl:call-template name="mima-admin-field-table">
      <xsl:with-param name="group" select="'ticket-priority'" />
    </xsl:call-template>
  </xsl:template><!-- }}} -->

  <!-- Resolutions -->
  <xsl:template name="mima-admin-resolutions"><!-- {{{ -->
    <h2 class="no-top-margin">Ticket resolutions</h2>
    <xsl:call-template name="mima-admin-field-table">
      <xsl:with-param name="group" select="'ticket-resolution'" />
    </xsl:call-template>
  </xsl:template><!-- }}} -->

  <!-- Main form -->
  <xsl:template name="mima-admin-field-table"><!-- {{{ -->
    <xsl:param name="group" />

    <div style="width:450px; float:left">
      <if variable="form.apply">
	<mima-update-fields group="{$group}" />
      </if>
      <elseif variable="form.delete">
	<if sizeof="form.selected &gt; 0">
	  <mima-delete-field id="&form.selected;" />
	</if>
      </elseif>
      <form action="&mima.self;" method="post" onsubmit="Mima.FixRadios(this)">
	<table cellspacing="0" cellpadding="0" class="dnd" id="dtable-{$group}">
	  <thead>
	    <tr class="nodrop nodrag">
	      <th class="center squeeze"><a href="javascript:void(0)" class="select-all-cb">#</a></th>
	      <th style="width:50%">Index</th>
	      <th style="width:50%">Value</th>
	      <th class="center squeeze last">Default</th>
	    </tr>
	  </thead>
	  <tbody>
	    <emit source="mima-field" group="{$group}">
	      <tr id="field-&_.id;">
		<td class="center">
		  <input type="checkbox" name="selected" value="&_.id;" />
		  <input type="hidden" class="order" name="order" value="&_.order;" />
		  <input type="hidden" name="id" value="&_.id;" />
		</td>
		<td>
		  <input type="hidden" name="index" value="&_.index;" />
		  <span class="dynamic-input">&_.index;</span>
		</td>
		<td>
		  <input type="hidden" name="value" value="&_.value;" />
		  <span class="dynamic-input">&_.value;</span>
		</td>
		<td class="center last">
		  <if variable="_.default = y">
		    <input type="radio" name="default" value="y" checked="checked" />
		  </if>
		  <else>
		    <input type="radio" name="default" value="y" />
		  </else>
		</td>
	      </tr>
	    </emit>
	  </tbody>
	</table>
	<br/>
	<input type="submit" name="apply" value="Apply changes" id="btn-apply-{$group}" />
	<xsl:text> </xsl:text>
	<input type="submit" name="delete" value="Delete selected" id="btn-delete-{$group}"/>
      </form>
    </div>
    <div style="width:210px;float:right">
      <vform action="&mima.self;">
	<fieldset>
	  <legend>Add</legend>
	  <label>
	    <span>Index</span>
	    <mima-input type="string" name="nindex" minlength="2" style="width:180px">
	      Add an index
	    </mima-input>
	  </label>
	  <br/>
	  <label>
	    <span>Value</span>
	    <mima-input type="string" name="nvalue" minlength="2" style="width:180px">
	      Add a value
	    </mima-input>
	  </label>
	  <br/>
	  <label class="inline-group">
	    <default value="&form.ndefault;">
	      <input type="checkbox" name="ndefault" value="y"/>
	    </default>
	    <span>Set as default</span>
	  </label>
	  <br/><br/>
	  <input type="submit" name="add" value="Add" />
	</fieldset>
      </vform>
      <then>
	<mima-add-field index="&form.nindex;" value="&form.nvalue;"
	                default="&form.ndefault;" group="{$group}" 
	/>
	<then>
	  <redirect to="&mima.self;" />
	</then>
	<else>
	  <notify>
	    <p><strong>Error:</strong> &mima.error;</p>
	  </notify>
	</else>
      </then>
    </div>
    <div class="clear"><xsl:text> </xsl:text></div>
  </xsl:template><!-- }}} -->

  <!-- User management -->

  <xsl:template name="mima-list-users"><!-- {{{ -->
    <h2 class="no-top-margin">Users</h2>
    <emit source="mima-user">
      <if variable="_.counter = 1">
	<ttag name="table" cellspacing="0" cellpadding="0"/>
	<thead>
	  <th class="right" style="width:30px">id</th>
	  <th>Username</th>
	  <th>Fullname</th>
	  <th>E-mail</th>
	  <th class="last" style="width:16px">&#160;</th>
	</thead>
	<ttag name="tbody" />
      </if>
      <if expr="&_.counter; % 2">
	<set variable="var.cls" value="odd" />
      </if>
      <else>
	<set variable="var.cls" value="even" />
      </else>
      <tr class="&var.cls;">
	<td class="right">&_.id;</td>
	<td><a href="&mima.self;/edit/&_.id;">&_.username;</a></td>
	<td>&_.fullname;</td>
	<td>&_.email;</td>
	<td class="last">
	  <a href="&mima.self;/remove/&_.id;" class="icon delete"
	     onclick="return confirm('Remove user &_.fullname;?')">
	    <span>Remove</span>
	  </a>
	</td>
      </tr>
    </emit>
    <then>
      <ttag name="tbody" close="" />
      <ttag name="table" close="" />
    </then>
    <else>
      <notify>No users added yet</notify>
    </else>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="mima-remove-user"><!-- {{{ -->
    <sscanf format="%*{{%*s/%}}%d" variables="var.uid">&mima.self;</sscanf>
    <h2 class="no-top-margin">Remove user</h2>
    <mima-delete-user id="&var.uid;" />
    <then>
      <redirect to="{$mima-root}index.xml/admin/users" />
    </then>
    <else>
      <notify><p>Failed to delete user!</p></notify>
    </else>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="mima-edit-user"><!-- {{{ -->
    <h2 class="no-top-margin">Edit user</h2>
    <sscanf format="%*{{%*s/%}}%d" variables="var.uid">&mima.self;</sscanf>
    <emit source="mima-user" id="&var.uid;" scope="parent">
      <copy-scope from="_" to="mima" />
      <xsl:call-template name="mima-user-form" />
      <then>
	<mima-edit-user id="&form.id;" username="&form.username;"
	                fullname="&form.fullname;" email="&form.email;"
	/>
	<then>
	  User was updated OK
	</then>
	<else>
	  <notify><p>Failed to update user</p></notify>
	</else>
      </then>
    </emit>
    <else>
      <notify><p>There's no user with id <code>&var.uid;</code></p></notify>
    </else>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="mima-add-user"><!-- {{{ -->
    <h2 class="no-top-margin">Add user</h2>
    <xsl:call-template name="mima-user-form" />
    <then>
      <mima-add-user username="&form.username;" fullname="&form.fullname;"
		     email="&form.email;"
      />
      <then>
	<strong>The user was added OK</strong>
      </then>
      <else>
	<notify><p>Failed to add user</p></notify>
      </else>
    </then>
  </xsl:template><!-- }}} -->

  <xsl:template name="mima-user-form"><!-- {{{ -->
    <vform action="&mima.self;" hide-if-verified="">
      <if variable="mima.id">
	<input type="hidden" name="id" value="&mima.id;" />
      </if>
      <label>
	<span>User name <span class="help">Start typing the name and a list of 
	users matching will popup. Note that this is internal Roxen users</span></span>
	<mima-input id="username" type="string" name="username" minlength="2"
	            value="&mima.username;">
	  Please add a username
	</mima-input>
	<safe-js>
	  $('#username').typeListen(function(inp) {
	    inp = $(inp);
	    var val = inp.val();
	    if (val.length > 2) {
	      Mima.wget('/ajax/user-search', { filter : val }, function(data) {
		Mima.UserSelect(data);
	      });
	    }
	  }, 600);
	</safe-js>
      </label>
      <br/>
      <label>
	<span>User fullname</span>
	<mima-input type="string" id="fullname" name="fullname" minlength="4"
	            value="&mima.fullname;">
	  Please add the user's full name
	</mima-input>
      </label>
      <br/>
      <label>
	<span>User email</span>
	<mima-input type="email" id="email" disable-domain-check="" name="email"
	            value="&mima.email;">
	  Please add an email address
	</mima-input>
      </label>
      <br/>
      <if variable="mima.id">
	<input type="submit" name="send" value="Update user" />
      </if>
      <else>
	<input type="submit" name="send" value="Add user" />
      </else>
    </vform>  
  </xsl:template><!-- }}} -->
  
</xsl:stylesheet>
