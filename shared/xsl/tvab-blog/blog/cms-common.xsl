<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:import href="/cms-common.xsl" />
  <xsl:import href="blog.config.xsl" />
  
  <xsl:template match="page-components">
    <xsl:call-template name="blog-rxml-tags" />
    <xsl:apply-templates>
      <xsl:with-param name="content-width" select="$content-width" />
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template name="banner-frame">
    <td id="banners">
      <h2 class="small-info" style="text-align: right">Blogginfo</h2>
      
      <div class="blog-rss">
	<a href="/blogg/rss.xml{$blog-root}">Prenumerera via RSS</a>
      </div>
      
      <if variable="page.path = {$blog-root}*/*/*/index.xml">
      	<xsl:call-template name="blog-related-tags" />
	<xsl:call-template name="blog-page-tags" />
      </if>
      <xsl:call-template name="simple-blog-archive" />
      <xsl:call-template name="draw-blog-categories">
	<xsl:with-param name="type" select="'simple'" />
      </xsl:call-template>
      <xsl:call-template name="draw-simple-blog-tags"/>
    </td>
  </xsl:template>

</xsl:stylesheet>
