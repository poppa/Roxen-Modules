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
  
  <!-- List of photosets -->
  <xsl:template match="photosets">
    <xsl:apply-templates />
  </xsl:template>
  
  <!-- Photoset -->
  <xsl:template match="photoset">
    <div class="photoset">
      <div class="photo">
	<flickr-method name="flickr.photos.getInfo" 
	               photo_id="{@primary}" secret="{@secret}"
	               throw-error="0" variable="var.xml"
	               cache="6000"
	/>
	<then>
	  <xsltransform xsl="flickr.xsl" preparse="yes">&var.xml:none;</xsltransform>
	</then>
	<else>
	  Bummer!
	</else>
      </div>
      <h2><xsl:value-of select="title" /></h2>
      <xsl:if test="string-length(description)">
	<p><xsl:value-of select="description" /></p>
      </xsl:if>
    </div>
  </xsl:template>

  <!-- List of photos -->
  <xsl:template match="photos">
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
	    <xsltransform xsl="flickr.xsl" preparse="yes">&var.xml:none;</xsltransform>
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
