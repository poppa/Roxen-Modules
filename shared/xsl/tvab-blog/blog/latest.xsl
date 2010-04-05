<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:import href="cms-components.xsl" />
  <xsl:import href="blog.config.xsl" />

  <xsl:output method="xml"
              media-type="text/html"
	      omit-xml-declaration="yes"
	      indent="yes"
	      doctype-public=""
	      doctype-system=""
  />

  <rxml:variable-dependency name="category-file" />

  <xsl:template match="/">
    <xsl:call-template name="blog-rxml-tags" />
    <div class="content">
      <h2>
	<a href="&page.path;" rel="&page.path;" title="Permalink for: &page.title;"><span>&page.title;</span></a>
      </h2>
      <div class="body">
	<xsl:apply-templates>
	  <xsl:with-param name="content-width" select="$content-width" />
	</xsl:apply-templates>
      </div>
      <div class="footer">
	<set variable="var.pdate"><get-publish-date/></set>
	<p>Skapad <em><date brief="" lang="{$blog-date-lang}" iso-time="&var.pdate;"
	/></em> av <em>&page.author;</em> under <emit source="category" file="{$blog-category-file}" ref="&page.path;">
	    <a href="{$blog-category-path}?node=&_.node;">
	      <em>&_.name;</em>
	    </a><delimiter>, </delimiter>
	  </emit>
	  <else>
	    <em>ingen kategori</em>
	  </else>
	  &bull; <a href="&page.path;" class="permlink">Permalink</a>
	</p>
      </div>
    </div>
  </xsl:template>

  <xsl:template match="page-components">
    <xsl:variable name="pcs" select="*[name() = 'picture-component']" />
    <xsl:apply-templates select="$pcs[1]">
      <xsl:with-param name="content-width" select="$content-width" />
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="footer-component|header-component" />

</xsl:stylesheet>
