<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <!-- Menu renderer -->
  <xsl:template match="item" mode="insite-menu"><!-- {{{ -->
    <xsl:param name="base-path" />
    <xsl:param name="current-path" />
    <xsl:variable name="is-selected"
                  select="($current-path = $base-path and position() = 1) or
                          ($current-path != $base-path and
                           starts-with($current-path, path))"
    />
    <li>
      <xsl:choose>
	<xsl:when test="$is-selected">
	  <xsl:attribute name="class">selected</xsl:attribute>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:attribute name="class">normal</xsl:attribute>
	</xsl:otherwise>
      </xsl:choose>
      <a href="{$mima-root}index.xml{path}"><xsl:value-of select="name" /></a>
      <xsl:if test="$is-selected and item">
	<ul>
	  <xsl:apply-templates select="item" mode="insite-menu">
	    <xsl:with-param name="base-path" select="$base-path" />
	    <xsl:with-param name="current-path" select="$current-path" />
	  </xsl:apply-templates>
	</ul>
      </xsl:if>
    </li>
  </xsl:template><!-- }}} -->

  <xsl:template name="mima-search-internal-users"><!-- {{{ -->
    [<emit source="mima-user-search" find="&form.filter;">
      { name:'&_.name:pike;',fullname:'&_.fullname:pike;',id:&_.id;,email:'&_.email;' }<delimiter>,</delimiter>
    </emit>]
  </xsl:template><!-- }}} -->
  
</xsl:stylesheet>
