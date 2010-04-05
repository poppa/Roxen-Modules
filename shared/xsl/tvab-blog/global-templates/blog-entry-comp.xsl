<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:param name="tvab-blog-entry-component-enable" rxml:type="checkbox"
	     rxml:group="Component enable"
	     rxml:doc="Enable the TVAB blog entry component"
	     select="1"/>

  <xsl:param name="tvab-blog-entry-component-variants" rxml:type="text"
	     rxml:group="Component variants"
	     rxml:doc="Variants for the TVAB blog entry component"
	     select="'0:Standard'"/>

  <xsl:template match="tvab-blog-entry-component[variant='0']">
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">
	<xsl:choose>
	  <xsl:when test="render-in-editor">
	    <table>
	      <tr>
		<td style="background:#ccc;padding: 0 20px">
		  <p>Detta är en blogpost.<br/>
		  <strong>OBS!</strong> Denna komponent är nödvänding för
		  att denna sida ska räknas som en bloggpost!</p>
		</td>
	      </tr>
	    </table>
	  </xsl:when>
	</xsl:choose>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
</xsl:stylesheet>
