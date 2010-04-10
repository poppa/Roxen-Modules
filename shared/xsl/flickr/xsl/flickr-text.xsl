<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:import href="xsl/flickr-common.xsl" />
  
  <xsl:template match="photoset">
    <h2><xsl:value-of select="title" /></h2>
    <xsl:if test="string-length(description)">
      <p><xsl:value-of select="description" /></p>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
