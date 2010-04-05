<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:import href="/cms-common.xsl" />
  
  <xsl:param name="content-width" select="480" />
  
  <xsl:template match="page-components">
    <xsl:call-template name="rxml-tags" />
    <xsl:apply-templates>
      <xsl:with-param name="content-width" select="$content-width" />
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template name="extra-content-column">
    <h2>Blogginfo</h2>

    <div class="blog-rss">
      <a href="/blogg/blog.rss{$blog-root}">Prenumerera på denna blogg via RSS</a>
    </div>

    <xsl:if test="//tvab-blog-entry-component">
      <xsl:call-template name="blog-related-tags" />
      <xsl:call-template name="blog-page-tags" />
    </xsl:if>

    <nocache>
      <xsl:call-template name="simple-blog-archive" />
    </nocache>

    <xsl:call-template name="draw-blog-categories">
      <xsl:with-param name="type" select="'simple'" />
    </xsl:call-template>

    <xsl:call-template name="draw-simple-blog-tags">
      <xsl:with-param name="cloud" select="true()"/>
    </xsl:call-template>

    <dl>
      <dt>Senaste kommentarer</dt>
      <nocache>
	<emit source="comments" path="{$blog-root}*" maxrows="5" sort="-date">
	  <dd>
	    <a href="&_.path;#comment-&_.id;">
	      <span class="date">Av</span> &_.author; <date date="" type="iso" iso-time="&_.date;"/>
	      <xsl:text> </xsl:text>
	      <span class="date">till</span> &_.page-title;
	    </a>
	  </dd>
	</emit>
	<else>
	  <dd><span class="date">Inga kommentarer</span></dd>
	</else>
      </nocache>
    </dl>
    
  </xsl:template>

</xsl:stylesheet>


