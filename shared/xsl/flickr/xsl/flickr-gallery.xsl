<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:import href="xsl/flickr-common.xsl" />

  <!-- List of photos -->
  <xsl:template match="photos" name="photo-gallery">
    <table class="gallery">
      <xsl:text disable-output-escaping="yes"><![CDATA[<tr>]]></xsl:text>
      <set variable="var.i" value="0" />
      <xsl:for-each select="photo">
	<if expr="!(var.i % 3)">
	  <if variable="var.i &gt; 0">
	    <xsl:text disable-output-escaping="yes"><![CDATA[</tr>]]></xsl:text>
	  </if>
	  <xsl:text disable-output-escaping="yes"><![CDATA[<tr>]]></xsl:text>
	</if>
	<flickr-method name="flickr.photos.getInfo" photo_id="{@id}" secret="{@secret}" 
		       throw-error="0" variable="var.xml"
	/>
	<then>
	  <td class="photo">
	    <xsltransform xsl="xsl/flickr-gallery.xsl" preparse="yes">&var.xml:none;</xsltransform>
	  </td>
	</then>
	<else>
	  <td class="error">Error...</td>
	</else>
	<inc variable="var.i" />
      </xsl:for-each>
      <if variable="var.i &gt; 0">
	<xsl:text disable-output-escaping="yes"><![CDATA[</tr>]]></xsl:text>
      </if>
    </table>
  </xsl:template>

  <xsl:template match="photo">
    <!--<pre><wash-html><xsl:copy-of select="." /></wash-html></pre>-->
    <xsl:variable name="src"><xsl:call-template name="photo-src" /></xsl:variable>
    <xsl:variable name="photoer">
      <xsl:choose>
	<xsl:when test="string-length(owner/@realname)">
	  <xsl:value-of select="owner/@realname" />
	</xsl:when>
	<xsl:otherwise>
	  <xsl:value-of select="owner/@username" />
	</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <span class="flickr-go">Click to view Flickr page</span>
    <a href="{urls/url[@type = 'photopage']}">
      <span class="block image">
	<cimg src="{$src}" alt="{title}" max-width="180" max-height="140" jpeg-quality="90" title="" />
      </span>
      <span class="block caption">By <strong><xsl:value-of select="$photoer" /></strong><br/>
      Uploaded <date unix-time="{dates/@posted}" lang="en" brief=""/><br/>
      <xsl:value-of select="comments" /> comments
      </span>
    </a>
  </xsl:template>

</xsl:stylesheet>
