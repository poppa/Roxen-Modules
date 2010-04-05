<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:import href="ancestor-or-self::assets/mima.xsl" />

  <xsl:output method="xml"
	      media-type="text/html"
	      doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
	      doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
	      indent="yes" />

  <xsl:template match="/"><!-- {{{ -->
    <!-- Initialize Wiki engine -->
    <!--<wiki-init root="{$mima-root}index.xml/wiki/" />-->

    <define variable="var.mima-page-contents" preparse="yes">
      <mima template-file="/mima/assets/mima-content-compiler.xsl"
	    rxml-file="/mima/assets/mima.xml"
	    mima-base="{$mima-root}index.xml/"
	    wiki-root="{$mima-root}index.xml/wiki/"
	    svn-repository-uri="{$mima-repository-uri}"
	    identifier="&page.path;" />
    </define>
    <html xmlns="http://www.w3.org/1999/xhtml" dir="ltr" lang="en-GB">
      <head>
	<title><nocache>&var.mima-page-title;</nocache></title>
	<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
	<link rel="stylesheet" type="text/css" href="{$mima-root}assets/css/mima.css" /><xsl:text>&#13;</xsl:text>
	<!--<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.js"><xsl:text> </xsl:text></script><xsl:text>&#13;</xsl:text>-->
	<script type="text/javascript" src="{$mima-root}assets/js/jquery.js"><xsl:text> </xsl:text></script><xsl:text>&#13;</xsl:text>
	<script type="text/javascript" src="{$mima-root}assets/js/jquery.tablednd.js"><xsl:text> </xsl:text></script><xsl:text>&#13;</xsl:text>
	<mima-mountpoint variable="var.mima-mp" />
	<script type="text/javascript" src="{$mima-root}assets/js/uri.js"><xsl:text> </xsl:text></script><xsl:text>&#13;</xsl:text>
	<script type="text/javascript" src="{$mima-root}assets/js/mima.js"><xsl:text> </xsl:text></script><xsl:text>&#13;</xsl:text>
	<safe-js>
	  Mima.Root = '<xsl:value-of select="$mima-root" />';
	</safe-js>
      </head>
      <body>
	<xsl:call-template name="mima-header" />
	<div id="mima"><nocache>&var.mima-page-contents:none;</nocache></div>
	<xsl:call-template name="mima-footer" />
      </body>
    </html>
  </xsl:template><!-- }}} -->

  <xsl:template name="mima-header"><!-- {{{ -->
    <div id="mima-header">
      <h1>
	<a href="{$mima-root}">
	  <span>Mima</span>
	</a>
      </h1>
      <div id="navigation">
	<if variable="user.is-authenticated">
	  <div id="user">
	    <nocache>
	      <if variable="user.is-authenticated = 1">
		<span>Logged in as</span> &user.fullname;
	      </if>
	      <else>
		<span>Not logged in: </span><a href="{$mima-root}index.xml/login">Login</a>
	      </else>
	    </nocache>
	  </div>
	</if>
	<ul>
	  <nocache><xsl:call-template name="mima-render-nav" /></nocache>
	</ul>
      </div>
      <div class="clear"><xsl:text> </xsl:text></div>
    </div>
  </xsl:template><!-- }}} -->

  <xsl:template name="mima-footer"><!-- {{{ -->
    <div id="mima-footer">
      <div class="left">
	<ul>
	  <xsl:call-template name="mima-render-nav" />
	</ul>
	<div class="clear"><xsl:text> </xsl:text></div>
	<p><small>Crafted with <abbr title="Extensible Hyper Text Markup Language">XHTML</abbr>,
	<abbr title="Cascading Style Sheets">CSS</abbr> and standards in mind.<br />
	Check if this document is valid <abbr title="World Wide Web Consortium">W3C</abbr>
	<xsl:text> </xsl:text>
	<a href="http://validator.w3.org/check?uri=referer">XHTML 1.0</a> 
	and that the CSS is valid <a href="#">CSS 3</a>.</small></p>
      </div>
      <div class="right">
	<a href="#">
	  <imgs src="{$mima-root}assets/img/tvab.png" alt="Tekniska Verken" title="" />
	</a>
	<xsl:text> </xsl:text>
	<a href="#">
	  <imgs src="{$mima-root}assets/img/roxen-32.png" alt="Roxen CMS" title="" />
	</a>
      </div>
      <div class="clear"><xsl:text> </xsl:text></div>
    </div>
  </xsl:template><!-- }}} -->

  <xsl:template name="mima-render-nav"><!-- {{{ -->
    <xsl:for-each 
      select="document(concat($mima-root, 'assets/navigation.xml'))/navigation/item"
    >
      <set variable="var.class" value="normal" />
      <set variable="var.display" value="1" />
      <if sizeof="page.pathinfo &gt; 1">
	<if match="&page.pathinfo; is {path}*" and="" Match="{path} != ">
	  <set variable="var.class" value="selected" />
	</if>
      </if>
      <else>
	<if match="{path} = ">
	  <set variable="var.class" value="selected" />
	</if>
      </else>
      <xsl:if test="@if">
	<xsl:choose>
	  <xsl:when test="@if = 'admin'">
	    <if ppoint="mima-admin" write=""/>
	    <else>
	      <set variable="var.display" value="0"/>
	    </else>
	  </xsl:when>
	  <xsl:when test="@if = 'source-enabled'">
	    <xsl:if test="string-length($mima-repository-uri) = 0">
	      <set variable="var.display" value="0"/>
	    </xsl:if>
	  </xsl:when>
	</xsl:choose>
      </xsl:if>
      <if variable="var.display = 1">
	<li class="&var.class;">
	  <a href="{$mima-root}index.xml{path}">
	    <span><xsl:value-of select="title" /></span>
	  </a>
	</li>
      </if>
    </xsl:for-each>
  </xsl:template><!-- }}} -->

</xsl:stylesheet>
