<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:import href="xsl/flickr-common.xsl" />
  <xsl:import href="xsl/flickr-gallery.xsl" />

  <!-- List of photosets -->
  <xsl:template match="photosets">
    <table class="photosets">
      <xsl:text disable-output-escaping="yes"><![CDATA[<tr>]]></xsl:text>
      <set variable="var.i" value="0" />
      <xsl:for-each select="photoset">
	<!-- Close/open tr -->
	<if expr="!(var.i % 3)">
	  <if variable="var.i &gt; 0">
	    <xsl:text disable-output-escaping="yes"><![CDATA[</tr>]]></xsl:text>
	  </if>
	  <xsl:text disable-output-escaping="yes"><![CDATA[<tr>]]></xsl:text>
	</if>
	
	<td>
	  <h2>
	    <a href="&page.self;?photoset={@id}">
	      <xsl:value-of select="title" /> &raquo;
	    </a>
	  </h2>
	  <div class="photo">
	    <flickr-method name="flickr.photos.getInfo" 
			   photo_id="{@primary}" secret="{@secret}"
			   throw-error="0" variable="var.xml"
			   cache="6000"
	    />
	    <then>
	      <!--<pre><wash-html>&var.xml:none;</wash-html></pre>-->
	      <xsltransform xsl="xsl/flickr-photosets.xsl" preparse="yes">&var.xml:none;</xsltransform>
	    </then>
	    <else>
	      Bummer!
	    </else>
	  </div>
	  <div class="caption">
	    <p>
	      <xsl:value-of select="@photos" /> photos
	      <xsl:if test="string-length(description)">
		| <span class="lighter"><xsl:value-of select="description" /></span>
	      </xsl:if>
	    </p>
	    <p><a href="&page.self;?photoset={@id}">View this photoset &raquo;</a></p>
	  </div>
	</td>
	<inc variable="var.i" />
      </xsl:for-each>
      <if variable="var.i &gt; 0">
	<xsl:text disable-output-escaping="yes"><![CDATA[</tr>]]></xsl:text>
      </if>
    </table>
  </xsl:template>

  <xsl:template match="photoset">
    <!--<pre><wash-html><xsl:copy-of select="." /></wash-html></pre>-->
    <flickr-method name="flickr.photosets.getInfo" photoset_id="{@id}" 
                   throw-error="0" variable="var.xml" cache="6000"
    />
    <then>
      <div class="gallery-description">
	<div class="text">
	  <xsltransform xsl="xsl/flickr-text.xsl" preparse="yes">&var.xml:none;</xsltransform>
	</div>
	<div class="back">
	  <a href="&page.self;">Back to galleries &raquo;</a>
	</div>
	<br class="clear" />
      </div>
      <xsl:call-template name="photo-gallery" />
      <xsl:if test="@pages &gt; 1">
	<div class="flickr-page-nav">
	  <div class="total"><span><xsl:value-of select="@total" /> items</span></div>
	  <div class="nav">
	    <xsl:call-template name="flickr-page-nav">
	      <xsl:with-param name="total" select="@total" />
	      <xsl:with-param name="per-page" select="9" />
	      <xsl:with-param name="page" select="@page" />
	    </xsl:call-template>
	  </div>
	  <br class="clear" />
	</div>
      </xsl:if>
    </then>
  </xsl:template>
  
  <xsl:template name="flickr-page-nav">
    <xsl:param name="total" />
    <xsl:param name="per-page" />
    <xsl:param name="page" />

    <xsl:variable name="pages" select="ceiling($total div $per-page)" />
    <xsl:variable name="prev" select="$page - 1" />
    <xsl:variable name="next" select="$page + 1" />
    
    <if match="{$prev} &lt; 1">
      <span class="nav-link">Prev</span>
    </if>
    <else>
      <a href="&page.self;?photoset=&form.photoset;&amp;page={$prev}">Prev</a>
    </else>
    
    <for from="1" to="{$pages}" variable="var.i">
      <if variable="var.i = {$page}">
	<span class="selected">&var.i;</span>
      </if>
      <else>
	<a href="&page.self;?photoset=&form.photoset;&amp;page=&var.i;">&var.i;</a>
      </else>
    </for>

    <if match="{$next} &gt; {$pages}">
      <span class="nav-link">Next</span>
    </if>
    <else>
      <a href="&page.self;?photoset=&form.photoset;&amp;page={$next}">Next</a>
    </else>
  </xsl:template>

  <xsl:template match="photo">
    <xsl:variable name="src"><xsl:call-template name="photo-src" /></xsl:variable>
    <cimg src="{$src}" alt="{title}" max-width="280" jpeg-quality="90" title="" format="jpeg" />
  </xsl:template>
  
</xsl:stylesheet>
