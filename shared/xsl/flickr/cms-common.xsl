<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:import href="/cms-common.xsl" />

  <rxml:variable-dependency name="photoset" />
  <rxml:variable-dependency name="page" />
  
  <xsl:template match="page-components">
    <!-- Ugly hack. This shall of course be in the header tag -->
    <link rel="stylesheet" type="text/css" href="flickr.css" />
    <script type="text/javascript" src="flickr.js"><xsl:text> </xsl:text></script>

    <xsl:apply-templates select="*[name() != 'footer-component']" />
    <nocache><xsl:call-template name="flickr" /></nocache>
    <xsl:apply-templates select="*[name() = 'footer-component']" />
  </xsl:template>

  <xsl:template name="flickr">
    <flickr require-authentication="delete">
      <if variable="form.clear-cache">
	<flickr-clear-cache />
	<redirect to="&page.self;" />
      </if>
      <else>
	<div id="flickr-wrapper">
	  <xsl:call-template name="flickr-my-dynamic" />
	</div>
      </else>
    </flickr>
  </xsl:template>
  
  <xsl:template name="flickr-my-dynamic">
    <if variable="_.is-authenticated = 1">
      <if variable="form.__logout = 1">
	<flickr-logout />
	<redirect to="&page.self;" />
      </if>
      <p style="margin-top:0"><strong>Hello &_.fullname;</strong> | <a href="&page.self;?__logout=1">Log out</a></p>
      <xsl:choose>
	<xsl:when test="rxml:variable('photoset')">
	  <xsl:call-template name="flickr-my-photoset">
	    <xsl:with-param name="id" select="rxml:variable('photoset')" />
	  </xsl:call-template>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:call-template name="flickr-my-list" />
	</xsl:otherwise>
      </xsl:choose>
    </if>
    <else>
      <a href="&_.login-url;">Login to Flickr</a>
    </else>
  </xsl:template>

  <xsl:template name="flickr-my-photoset">
    <flickr-method name="flickr.photosets.getPhotos" throw-error="0" variable="var.xml"
                   photoset_id="&form.photoset;" per_page="9" 
                   cache="6000"
    >
      <xsl:if test="rxml:variable('page')">
	<xsl:attribute name="page"><xsl:value-of select="rxml:variable('page')" /></xsl:attribute>
      </xsl:if>
    </flickr-method>
    <then>
      <!--<pre>&var.xml;</pre>-->
      <xsltransform xsl="xsl/flickr-photosets.xsl" preparse="yes">&var.xml:none;</xsltransform>
    </then>
    <else>
      Bummer!
    </else>
  </xsl:template>

  <xsl:template name="flickr-my-list">
    <flickr-method name="flickr.photosets.getList" throw-error="0" variable="var.xml"
                   cache="6000"/>
    <then>
      <xsltransform xsl="xsl/flickr-photosets.xsl" preparse="yes">&var.xml:none;</xsltransform>
    </then>
    <else>
      <p>Bummer!</p>
    </else>
  </xsl:template>
  
  <xsl:template name="flickr-recent-public">
    <flickr-method name="flickr.photos.getRecent" per_page="15"
		   variable="var.xml" throw-error="0"
    />
    <then>
      <xsltransform xsl="flickr.xsl" preparse="yes">&var.xml:none;</xsltransform>
    </then>
    <else>
      <p>Bummer!</p>
    </else>
  </xsl:template>
  
</xsl:stylesheet>
