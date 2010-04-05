<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="tvab-blog-index-component-enable" rxml:type="checkbox"
	     rxml:group="Component enable"
	     rxml:doc="Enable the TVAB blog index component"
	     select="1"/>

  <xsl:param name="tvab-blog-index-component-variants" rxml:type="text"
	     rxml:group="Component variants"
	     rxml:doc="Variants for the TVAB blog index component"
	     select="'0:Standard'"/>

  <xsl:template match="tvab-blog-index-component[variant='0']">
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">
	<ul class="linklist">
	  <nocache>
	    <emit source="tvab-blog-index" sort="blog-title">
	      <xsl:if test="string-length(path)">
		<xsl:attribute name="path"><xsl:value-of select="path" /></xsl:attribute>
	      </xsl:if>
	      <li>
		<xsl:choose>
		  <xsl:when test="render-in-editor">
		    <u>
		      <strong>&_.blog-title;</strong>
		      <if sizeof="_.blog-description &gt; 0">
			<br/><span style="color:#333">&_.blog-description;</span>
		      </if>
		    </u>
		  </xsl:when>
		  <xsl:otherwise>
		    <a href="&_.blog-root;">
		      <strong>&_.blog-title;</strong>
		      <if sizeof="_.blog-description &gt; 0">
			<br/><span style="color:#333">&_.blog-description;</span>
		      </if>
		    </a>
		  </xsl:otherwise>
		</xsl:choose>
	      </li>
	    </emit>
	    <else>
	      <li class="empty">Det finns inga bloggar</li>
	    </else>
	  </nocache>
	</ul>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

</xsl:stylesheet>
