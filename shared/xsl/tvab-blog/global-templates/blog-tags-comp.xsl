<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="tvab-blog-tag-component-enable" rxml:type="checkbox"
	     rxml:group="Component enable"
	     rxml:doc="Enable the TVAB blog tag component"
	     select="1"/>

  <xsl:param name="tvab-blog-tag-component-variants" rxml:type="text"
	     rxml:group="Component variants"
	     rxml:doc="Variants for the TVAB blog tag component"
	     select="'0:Komplett&#10;1:Enkel&#10;2:Moln (enkel)'"/>

  <rxml:variable-dependency name="tag" />

  <xsl:template match="tvab-blog-tag-component[variant=0]">
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">  
	<xsl:call-template name="draw-blog-tags" />
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tvab-blog-tag-component[variant=1]">
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">  
	<xsl:call-template name="draw-simple-blog-tags" />
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
    <xsl:template match="tvab-blog-tag-component[variant=2]">
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">  
	<xsl:call-template name="draw-simple-blog-tags">
	  <xsl:with-param name="cloud" select="true()" />
	</xsl:call-template>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- Outputs all blog related tags as a tagcloud. If a given tag is selected
       all entries under that tag will be listed -->
  <xsl:template name="draw-blog-tags"><!-- {{{ -->
    <nocache>
      <emit source="tvab-blog-tags" path="{$blog-root}*" cloud="">
	<set variable="var.size" expr="&_.number;-1" />
	<if variable="var.size &gt; 9">
	  <set variable="var.size" value="9" />
	</if>
	<if variable="_.tag = {rxml:variable('tag')}">
	  <a style="font-size:1.&var.size;em;" href="&page.self;?tag=&_.tag;">
	    <strong>&_.tag;</strong>
	  </a>
	</if>
	<else>
	  <a style="font-size:1.&var.size;em;" href="&page.self;?tag=&_.tag;">&_.tag;</a>
	</else>
	<delimiter>, </delimiter>
      </emit>
      <then>
	<div class="divider dotted"><xsl:text> </xsl:text></div>
	<xsl:if test="rxml:variable('tag')">
	  <div class="latest">
	    <emit source="tvab-blog-tags" path="{$blog-root}*" 
		  tag="{rxml:variable('tag')}">
	      <insert file="&_.path;?__xsl=latest.xsl" />
	      <delimiter><div class="divider"><xsl:text> </xsl:text></div></delimiter>
	    </emit>
	    <else>
	      <div class="notify">
		<p>Inga artiklar hittades för <strong><xsl:value-of select="rxml:variable('tag')" /></strong></p>
	      </div>
	    </else>
	  </div>
	</xsl:if>
      </then>
    </nocache>
  </xsl:template><!-- }}} -->
  
  <!-- Draws all blog related tags as comma separated list. -->
  <xsl:template name="draw-simple-blog-tags"><!-- {{{ -->
    <xsl:param name="cloud" select="false()" />
    <dl>
      <dt><a href="{$blog-tags-path}">Bloggens etiketter</a></dt>
      <dd class="inline">
	<cache minutes="2" shared="yes">
	  <emit source="tvab-blog-tags" path="{$blog-root}*">
	    <xsl:if test="$cloud != false()">
	      <xsl:attribute name="cloud"></xsl:attribute>
	      <set variable="var.size" expr="&_.number;-1" />
	      <if variable="var.size &gt; 9">
		<set variable="var.size" value="9" />
	      </if>
	      <set variable="var.style" value="style='font-size:1.&var.size;em'" />
	    </xsl:if>
	    <a href="{$blog-tags-path}?tag=&_.tag;" ::="&var.style;">&_.tag;</a>
	    <delimiter>, </delimiter>
	  </emit>
	</cache>
      </dd>
    </dl>
  </xsl:template><!-- }}} -->
  
  <!-- Draws all tags for the current page -->
  <xsl:template name="blog-page-tags"><!-- {{{ -->
    <if sizeof="page.keywords &gt; 0">
      <dl>
	<dt>Sidans etiketter</dt>
	<dd class="inline">
	  <emit source="values" variable="page.keywords" split=",">
	    <set variable="var.v"><trim>&_.value;</trim></set>
	    <a href="{$blog-tags-path}?tag=&var.v;">&var.v;</a>
	    <delimiter>, </delimiter>
	  </emit>
	</dd>
      </dl>
    </if>
  </xsl:template><!-- }}} -->
  
  <!-- Draws related pages to the current one based on that they share 
       tags (or keywords if you like). -->
  <xsl:template name="blog-related-tags"><!-- {{{ -->
    <if sizeof="page.keywords &gt; 0">
      <nocache>
	<set variable="var.data" value="" />
	<emit source='tvab-blog-tags' tag='&page.keywords;' 
	      path='{$blog-root}*' not-path="&page.path;">
	  <append variable="var.data" value="&_.title;#@" />
	  <append variable="var.data" value="&_.path;#@" />
	  <append variable="var.data" value="&_.visible_from;" />
	  <append variable="var.data"><delimiter>#§</delimiter></append>
	</emit>
	<then>
	  <dl>
	    <dt>Relaterade artiklar</dt>
	    <emit source="values" variable="var.data" split="#§">
	      <sscanf format="%s#@%s#@%s" scope="var" variables="t,p,v">&_.value;</sscanf>
	      <dd>
		<a href="&var.p;">
		  <span>&var.t;</span>
		  <xsl:text> </xsl:text>
		  <small>
		    <span class="date"><date strftime="%Y-%m-%d" iso-time="&var.v;" /></span>
		  </small>
		</a>
	      </dd>
	    </emit>
	  </dl>
	</then>
      </nocache>
    </if>
  </xsl:template><!-- }}} -->

</xsl:stylesheet>
