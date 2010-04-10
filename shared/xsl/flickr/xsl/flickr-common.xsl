<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml" media-type="text/html" indent="yes"
              omit-xml-declaration="yes" doctype-system=""
              doctype-public="" />

  <xsl:template match="/">
    <xsl:apply-templates />
  </xsl:template>

  <!-- Root of a successful query -->
  <xsl:template match="rsp[@stat='ok']">
    <xsl:apply-templates />
  </xsl:template>

  <xsl:template name="photo-src">
    <xsl:value-of 
	select="concat('http://farm', @farm, '.static.flickr.com/', @server, '/',
                       @id, '_', @secret, '.jpg')"
    />
  </xsl:template>

  <xsl:template match="rsp[@stat='fail']">
    <div class="error">
      <p><xsl:value-of select="err/@msg" /> (<xsl:value-of select="err/@code" />)</p>
    </div>
  </xsl:template>
  
</xsl:stylesheet>
