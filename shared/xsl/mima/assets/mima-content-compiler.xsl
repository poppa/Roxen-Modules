<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:import href="ancestor-or-self::assets/mima.xsl" />
  <xsl:import href="ancestor-or-self::assets/xsl/projects.xsl" />
  <xsl:import href="ancestor-or-self::assets/xsl/tickets.xsl" />
  <xsl:import href="ancestor-or-self::assets/xsl/admin.xsl" />
  <xsl:import href="ancestor-or-self::assets/xsl/source-browser.xsl" />
  <xsl:import href="ancestor-or-self::assets/xsl/misc.xsl" />
  <xsl:import href="ancestor-or-self::assets/xsl/wiki.xsl" />

  <xsl:output method="xml"
              media-type="text/html"
              omit-xml-declaration="yes"
              doctype-public=""
              doctype-system=""
              indent="yes" />

  <xsl:template match="/"><!-- {{{ -->
    <!-- Define some common RXML helpers -->

    <define container="notify" preparse=""><!-- {{{ -->
      <div class="notify"><contents/></div>
    </define><!-- }}} -->

    <define tag="not-null"><!-- {{{ -->
      <attrib name="value" />
      <if variable="_.value = 0">&#160;</if>
      <elseif variable="_.value = ">&#160;</elseif>
      <else>&_.value;</else>
    </define><!-- }}} -->

    <set variable="var._inputs" value="0" />
    <define container="mima-input"><!-- {{{ -->
      <if variable="_.id">
	<set variable="var.fid" value="&_.id;" />
      </if>
      <else>
	<set variable="var.fid" value="mima-input-&var._inputs;" />
      </else>
      <set variable="var.cont"><trim><contents/></trim></set>
      <vinput id="&var.fid;" ::="&_.rest-args;">
	<safe-js>Form.Error.Append('&var.fid;', '<trim>&var.cont:html;</trim>')</safe-js>
      </vinput>
      <inc variable="var._inputs" />
    </define><!-- }}} -->

    <define container="mima-field-select"><!-- {{{ -->
      <attrib name="name" />
      <attrib name="check" />
      <attrib name="group" />

      <if variable="form.&_.name;">
	<set variable="var.postback"><insert variable="&_.name;" scope="form" /></set>
      </if>

      <select name="&mima-field-select.name;" ::="&_.rest-args;">
	<emit source="mima-field" group="&_.group;">
	  <if variable="var.postback = ?*">
	    <if variable="var.postback = &_.id;">
	      <option value="&_.id;" selected="selected">&_.value;</option>
	    </if>
	    <else>
	      <option value="&_.id;">&_.value;</option>
	    </else>
	  </if>
	  <else>
	    <if variable="mima-field-select.check = ?*">
	      <if variable="_.id = &mima-field-select.check;">
		<option value="&_.id;" selected="selected">&_.value;</option>
	      </if>
	      <else>
		<option value="&_.id;">&_.value;</option>
	      </else>
	    </if>
	    <else>
	      <if variable="_.default = y">
		<option value="&_.id;" selected="selected">&_.value;</option>
	      </if>
	      <else>
		<option value="&_.id;">&_.value;</option>
	      </else>
	    </else>
	  </else>
	</emit>
      </select>
    </define><!-- }}} -->

    <define tag="mima-cancel"><!-- {{{ -->
      <attrib name="href">&mima.parent-dir;</attrib>
      <attrib name="value">Cancel</attrib>
      <input type="button" value="&_.value;" 
             onclick="document.location.href='&_.href;'" ::="&_.rest-args;" />
    </define><!-- }}} -->

    <define tag="ttag"><!-- {{{ -->
      <attrib name="name" />
      <attrib name="close">0</attrib>
      <if variable="_.close != 0">
	<set variable="var.t" value="&lt;/&_.name;&gt;" />
      </if>
      <else>
	<set variable="var.t" value="&lt;&_.name; &_.rest-args;&gt;" />
      </else>
      &var.t:none;
      <unset variable="var.t" />
    </define><!-- }}} -->
    
    <nocache>
      <if variable="user.username = 0">
	<set variable="user.username" value="{$mima-anon-user}" />
      </if>
    </nocache>

    <xsl:apply-templates />
  </xsl:template><!-- }}} -->

  <xsl:template match="mima-ajax"><!-- {{{ -->
    <xsl:choose>
      <xsl:when test="path = 'user-search'">
	<xsl:call-template name="mima-search-internal-users" />
      </xsl:when>
    </xsl:choose>
  </xsl:template><!-- }}} -->
  
  <xsl:template match="mima-source-browser"><!-- {{{ -->
    <h2 class="bread-crumb">
      <a href="{$mima-root}index.xml/browser">root</a>
      <xsl:call-template name="print-bread-crumb">
	<xsl:with-param name="path" select="path" />
	<xsl:with-param name="base" select="'/browser'" />
      </xsl:call-template>
    </h2>

    <xsl:choose>
      <xsl:when test="type = 'changeset'">
	<xsl:call-template name="mima-repository-changeset" />
      </xsl:when>
      <xsl:otherwise>
	<xsl:call-template name="mima-repository-ls" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template><!-- }}} -->

  <xsl:template name="print-bread-crumb"><!-- {{{ -->
    <xsl:param name="path" />
    <xsl:param name="base" />
    <set variable="var.acc" value="{$mima-root}index.xml{$base}" />
    <emit source="values" values="{$path}" split="/" rowinfo="var.rows">
      <if sizeof="_.value &gt; 0">
	<append variable="var.acc" value="/&_.value;" />
	<span>/</span>
	<a href="&var.acc;">&_.value;</a>
      </if>
    </emit>
  </xsl:template><!-- }}} -->
  
  <xsl:template match="mima-admin"><!-- {{{ -->
    <mima-title value="Admin" />
    <xsl:variable name="admin.path" select="concat('/admin', path)" />
    <xsl:variable name="admin-menu"><!-- {{{ -->
      <m>
	<item>
	  <name>Projects</name>
	  <path>/admin/projects</path>
	  <item>
	    <name>Add new</name>
	    <path>/admin/projects/create</path>
	  </item>
	</item>
	<item>
	  <name>Users</name>
	  <path>/admin/users</path>
	  <item>
	    <name>Add new</name>
	    <path>/admin/users/add</path>
	  </item>
	</item>
	<item>
	  <name>Ticket types</name>
	  <path>/admin/tickets</path>
	</item>
	<item>
	  <name>Ticket priorities</name>
	  <path>/admin/priorities</path>
	</item>
	<item>
	  <name>Ticket resolutions</name>
	  <path>/admin/resolutions</path>
	</item>
      </m>
    </xsl:variable><!-- }}} -->

    <div class="inline-menu">
      <h1 class="no-top-margin">Admin</h1>
      <ul>
	<xsl:apply-templates select="rxml:node-set($admin-menu)/m/item"
	                     mode="insite-menu"
	>
	  <xsl:with-param name="base-path" select="'/admin'" />
	  <xsl:with-param name="current-path" select="$admin.path" />
	</xsl:apply-templates>
      </ul>
    </div>

    <div class="inline-content">
      <xsl:choose>
	<!-- Create project -->
	<xsl:when test="path = '/projects/create'">
	  <xsl:call-template name="mima-project-create" />
	</xsl:when>

	<!-- Add member
	     TODO: Is this neccessary? -->
	<xsl:when test="path = '/users/add'">
	  <xsl:call-template name="mima-add-user" />
	</xsl:when>

	<!-- Edit member -->
	<xsl:when test="starts-with(path, '/users/edit')">
	  <xsl:call-template name="mima-edit-user" />
	</xsl:when>

	<!-- Remove member -->
	<xsl:when test="starts-with(path, '/users/remove')">
	  <xsl:call-template name="mima-remove-user" />
	</xsl:when>

	<!-- Member start
	     TODO: Is this neccessary? -->
	<xsl:when test="path = '/users'">
	  <xsl:call-template name="mima-list-users" />
	</xsl:when>

	<!-- Ticket types -->
	<xsl:when test="path = '/tickets'">
	  <xsl:call-template name="mima-admin-tickets" />
	</xsl:when>

	<!-- Ticket priorites -->
	<xsl:when test="path = '/priorities'">
	  <xsl:call-template name="mima-admin-priorities" />
	</xsl:when>

	<!-- Ticket resolutions -->
	<xsl:when test="path = '/resolutions'">
	  <xsl:call-template name="mima-admin-resolutions" />
	</xsl:when>

	<!-- Default view: Projects -->
	<xsl:otherwise>
	  <h2 class="no-top-margin">Projects</h2>
	  <xsl:call-template name="mima-admin-project-list" />
	</xsl:otherwise>
      </xsl:choose>
    </div>
    <div class="clear"><xsl:text> </xsl:text></div>
  </xsl:template><!-- }}} -->

  <xsl:template match="mima-login"><!-- {{{ -->
    <if variable="user.is-authenticated = 1">
      <redirect to ="{$mima-root}" />
    </if>
    <mima-title value="Login" />
    <h1 class="no-top-margin">Login to Mima</h1>
    <vform action="&mima.self;">
      <fieldset class="hidden">
	<label>
	  <span>Username</span>
	  <mima-input type="string" name="username" minlength="2">
	    The username can't be empty
	  </mima-input>
	</label>
	<br/>
	<label>
	  <span>Password</span>
	  <mima-input type="password" name="password" minlength="4">
	    The password must contain at least four characters
	  </mima-input>
	</label>
	<br/><br/>
	<input type="submit" name="send" value="Login" />
	<if variable="form.send">
	  <ac-cookie-auth username_variable="username" password_variable="password"
			  path="{$mima-root}" ok_var="ok"/>
	  <if not="" variable="form.ok">
	    <verify-fail />
	    <safe-js>
	      Form.Error.Append('mima-input-0', 'Wrong username or password!');
	    </safe-js>
	  </if>
	</if>
      </fieldset>
    </vform>
    <then>
      <redirect to="{$mima-root}" />
    </then>
  </xsl:template><!-- }}} -->

  <xsl:template match="mima-ticket"><!-- {{{ -->
    <xsl:choose>
      <xsl:when test="type = 'new'">
	<h1 class="no-top-margin">Tickets</h1>
	<xsl:call-template name="mima-new-ticket" />
      </xsl:when>
      <xsl:when test="type = 'view' and id">
	<h1 class="no-top-margin">Ticket</h1>
	<xsl:call-template name="mima-view-ticket" />
      </xsl:when>
      <xsl:otherwise>
	<mima-title value="Tickets" />
	<h1 class="no-top-margin">Tickets</h1>
	<xsl:call-template name="mima-tickets" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template><!-- }}} -->

  <xsl:template match="mima-wiki"><!-- {{{ -->
    <xsl:call-template name="wiki-run" />
  </xsl:template><!-- }}} -->
  
  <xsl:template match="mima-home-page"><!-- {{{ -->
    <mima-title value="Welcome to Mima" />
    <h1 class="no-top-margin">Welcome to Mima</h1>
    <a href="{$mima-root}index.xml/ticket/new">
      <span>File a bug report</span>
    </a>
  </xsl:template><!-- }}} -->

</xsl:stylesheet>
