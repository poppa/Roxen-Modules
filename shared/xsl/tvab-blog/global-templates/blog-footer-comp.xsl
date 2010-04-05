<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:param name="footer-component-variants" rxml:type="text"
	     rxml:group="Component variants"
	     rxml:doc="Variants for the Footer component"
	     select="'0:Standard&#10;1:With comments&#10;2:Blog'"/>

  <xsl:template match="footer-component[variant = 2]"><!-- {{{ -->
    <xsl:if test="render-in-editor">
      <xsl:call-template name="blog-rxml-tags" />
    </xsl:if>
    <noindex>
      <div class="blog-footer">
	<xsl:call-template name="blog-entry-footer" />
      </div>
    </noindex>
    <xsl:if test="not(render-in-editor)">
      <div id="page-comments">
	<nocache><xsl:call-template name="comments" /></nocache>
      </div>
    </xsl:if>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="blog-entry-footer">
    <xsl:param name="read-more" select="false()" />
    <set variable="var.iso-time"><get-publish-date/></set>
    <p>
      <if variable="var.iso-time = 0">
	Denna artikel är <em>opublicerad</em>
      </if>
      <else>
	Denna artikel skapades <em><date lang="{$blog-date-lang}" iso-time="&var.iso-time;" /></em>
      </else>
      av <em>&page.author;</em> och är kategoriserad i
      <emit source="category" file="{$blog-category-file}" ref="&page.path;">
	<a href="{$blog-category-path}?node=&_.node;">
	  <em>&_.name;</em>
	</a><delimiter>, </delimiter>
      </emit>
      <else>
	<em>ingen kategori</em>
      </else>

      <nocache>
	<set variable="var.cmts"><comments-count path="&page.path;" /></set>
	<if variable="var.cmts = 1">
	  <set variable="var.word" value="kommentar"/>
	</if>
	<else>
	  <set variable="var.word" value="kommentarer"/>
	</else>
	och har <a href="&page.path;#comments">&var.cmts; &var.word;</a>
      </nocache>
      <xsl:if test="$read-more">
	&bull; <a href="&page.path;" title="Läs mer om: &page.title;">Läs mer &raquo;</a>
      </xsl:if>
    </p>
  </xsl:template>

</xsl:stylesheet>
