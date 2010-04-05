<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template name="title-meta"/>

  <xsl:template match="blog-entry-list" name="blog-entry-list"><!-- {{{ -->
    <nocache>
      <xsl:call-template name="draw-tvab-blog-archive">
	<xsl:with-param name="path" select="concat($blog-root,'*')" />
	<xsl:with-param name="limit" select="5" />
	<xsl:with-param name="force-no-navigation" select="true()" />
      </xsl:call-template>
    </nocache>
  </xsl:template><!-- }}} -->

  <xsl:template name="blog-rxml-tags"><!-- {{{ -->
    <if not="" variable="var.blog-rxml-init">
      <define tag="get-publish-date" trimwhites="">
	<attrib name="path"/>
	<if variable="_.path = ?*">
	  <set variable="var.path" value="&_.path;" />
	</if>
	<else>
	  <set variable="var.path" value="&page.path;" />
	</else>
	<emit source="site-news" path="&var.path;" unique-paths="">&_.publish;</emit><else>0</else>
      </define>

      <define tag="count-category-items" trimwhites="">
	<attrib name="node" />
	<attrib name="file" />
	<emit source="category" file="&_.file;" node="&_.node;" document="">
	  <set variable="var.cnt" value="&_.counter;" />
	</emit>
	<else>
	  <set variable="var.cnt" value="0" />
	</else>&var.cnt;</define>

      <set variable="var.blog-rxml-init" value="1" />
    </if>
  </xsl:template><!-- }}} -->
  
</xsl:stylesheet>
