<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:import href="cms-components.xsl" />

  <xsl:output method="xml"
              media-type="text/html"
	      omit-xml-declaration="yes"
	      indent="yes"
	      doctype-public=""
	      doctype-system=""
  />

  <rxml:variable-dependency name="category-file" />

  <xsl:template match="/">
    <xsl:call-template name="rxml-tags" />
    <div class="excerpt">
      <h2>
	<a href="&page.path;" rel="&page.path;" title="Permanent länk till: &page.title;"><span>&page.title;</span></a>
      </h2>
      <div class="body">
	<xsl:apply-templates>
	  <xsl:with-param name="content-width" select="$content-width" />
	</xsl:apply-templates>
      </div>
      <div class="footer">
	<xsl:call-template name="blog-entry-footer">
	  <xsl:with-param name="read-more" select="true()" />
	</xsl:call-template>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="page-components">
    <xsl:choose>
      <xsl:when test="$blog-full-excerpts = 'on'">
	<xsl:apply-templates>
	  <xsl:with-param name="content-width" select="$content-width" />
	</xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
	<xsl:variable name="pcs" select="*[name() = 'picture-component']" />
	<xsl:apply-templates select="$pcs[1]">
	  <xsl:with-param name="content-width" select="$content-width" />
	</xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="footer-component|header-component" />

</xsl:stylesheet>
