<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template match="header-component[variant=1]">
    <div class="header-component">
      <xsl:call-template name="roxen-edit-box">
	<xsl:with-param name="content">
	  <!-- If no title is given in the component, use the metadata value
	       for this page. -->
	  <xsl:variable name="title">
	    <xsl:choose>
	      <xsl:when test="string-length(title)">
		<xsl:value-of select="title"/>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:value-of select="rxml:metadata()/title"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </xsl:variable>
	  <h1>
	    <xsl:value-of select="$title"/>
	    <xsl:if test="string-length(subtitle)">
	      <br/><small><xsl:value-of select="subtitle"/></small>
	    </xsl:if>
	  </h1>
	  <xsl:if test="//tvab-blog-entry-component">
	    <div id="previous-and-next"><p><nocache>
	      <emit source="tvab-blog-prev-next" path="&page.path;" root="{$blog-root}*">
		<if variable="_.order = next">
		  <if variable="var.has-prev"><span>&bull;</span><xsl:text> </xsl:text></if>
		  <a class="next" href="&_.path;" title="Nästa artikel">&_.title; &raquo;</a>
		</if>
		<else>
		  <a class="previous" href="&_.path;" title="Föregående artikel">&laquo; &_.title;</a>
		  <xsl:text> </xsl:text>
		  <set variable="var.has-prev" value="1" />
		</else>
	      </emit></nocache></p>
	    </div>
	  </xsl:if>
	</xsl:with-param>
      </xsl:call-template>
    </div>
  </xsl:template>

</xsl:stylesheet>
