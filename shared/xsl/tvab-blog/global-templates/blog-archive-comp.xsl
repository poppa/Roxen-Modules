<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="tvab-blog-archive-component-enable" rxml:type="checkbox"
	     rxml:group="Component enable"
	     rxml:doc="Enable the TVAB blog archive component"
	     select="1"/>

  <xsl:param name="tvab-blog-archive-component-variants" rxml:type="text"
	     rxml:group="Component variants"
	     rxml:doc="Variants for the TVAB blog archive component"
	     select="'0:Helt arkiv&#10;1:Årsarkiv&#10;2:Månadsarkiv&#10;3:Enkelt arkiv'"/>

  <rxml:variable-dependency name="offset" />

  <!-- View all entries of all times -->
  <xsl:template match="tvab-blog-archive-component[variant = 0]"><!-- {{{ -->
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">
	<xsl:call-template name="draw-tvab-blog-archive">
	  <xsl:with-param name="limit" select="$blog-view-per-page" />
	</xsl:call-template>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template><!-- }}} -->

  <!-- Yearly view -->
  <xsl:template match="tvab-blog-archive-component[variant = 1]"><!-- {{{ -->
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">
	<xsl:call-template name="draw-tvab-blog-archive">
	  <xsl:with-param name="limit" select="$blog-view-per-page" />
	</xsl:call-template>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template><!-- }}} -->

  <!-- Monthly view -->
  <xsl:template match="tvab-blog-archive-component[variant = 2]"><!-- {{{ -->
    <!-- Show all entries for monthly views, they can't be that too many -->
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">
	<xsl:call-template name="draw-tvab-blog-archive">
	  <xsl:with-param name="limit" select="0" />
	</xsl:call-template>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template><!-- }}} -->

  <!-- Simple view -->
  <xsl:template match="tvab-blog-archive-component[variant=3]">
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">
	<xsl:call-template name="simple-blog-archive" />
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- Draw the archive -->
  <xsl:template name="draw-tvab-blog-archive"><!-- {{{ -->
    <xsl:param name="limit" select="0" />
    <xsl:param name="path" select="false()" />
    <xsl:param name="force-no-navigation" select="false()" />

    <xsl:param name="_path">
      <xsl:choose>
	<xsl:when test="$path">
	  <xsl:value-of select="$path" />
	</xsl:when>
	<xsl:otherwise>&page.dir;*</xsl:otherwise>
      </xsl:choose>
    </xsl:param>

    <xsl:variable name="next-offset">
      <xsl:choose>
        <xsl:when test="rxml:variable('offset')">
	  <xsl:value-of select="rxml:variable('offset') + 1" />
	</xsl:when>
	<xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="prev-offset">
      <xsl:choose>
	<xsl:when test="rxml:variable('offset')">
	  <xsl:value-of select="rxml:variable('offset') - 1" />
	</xsl:when>
	<xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="start">
      <xsl:choose>
	<xsl:when test="rxml:variable('offset')">
	  <xsl:value-of select="rxml:variable('offset')*$limit" />
	</xsl:when>
	<xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <noindex>
      <div class="latest">
	<emit source="tvab-blog" path="{$_path}" maxrows="{$limit}" start="{$start}">
	  <insert file="&_.path;?__xsl=latest.xsl" />
	  <delimiter><div class="divider"><xsl:text> </xsl:text></div></delimiter>
	</emit>
	<else>
	  <div class="notify">
	    <p>Inga blogposter</p>
	  </div>
	</else>
      </div>

      <xsl:if test="$limit &gt; 0 and not($force-no-navigation)">
	<set variable="var.total-entries"><tvab-blog-num-pages path="{$_path}" /></set>
	<p>
	  <nocache>
	    <if variable="var.total-entries &gt; {$start}" and=""
		expr="{$limit}*{$next-offset} &lt; &var.total-entries;">
	      <a class="older-entries" href="&page.self;?offset={$next-offset}"><span>&laquo; Äldre artiklar</span></a> <xsl:text> </xsl:text>
	    </if>
	    <if expr="{$start} &gt; 0">
	      <a class="newer-entries" href="&page.self;?offset={$prev-offset}"><span>Nyare artiklar &raquo;</span></a>
	    </if>
	  </nocache>
	</p>
      </xsl:if>
    </noindex>
  </xsl:template><!-- }}} -->

  <!-- Draw a simple archive view: [Month name] [year] -->
  <xsl:template name="simple-blog-archive"><!-- {{{ -->
    <xsl:param name="path" select="$blog-root" />
    <dl>
      <dt>Arkiv</dt>
      <emit source="tvab-blog" path="{$path}*" group-by="month">
	<sscanf format="%d-%d" variables="var.y,var.m">&_.visible_from;</sscanf>
	<dd>
	  <set variable="var.arch-path" value="{$path}&var.y;/&var.m;/" />
	  <a href="&var.arch-path;" style="padding-left:0">
	    <if variable="page.path = &var.arch-path;*">
	      <strong><date strftime="%B %Y" iso-time="&_.visible_from;" lang="{$blog-date-lang}" /></strong>
	    </if>
	    <else>
	      <date strftime="%B %Y" iso-time="&_.visible_from;" lang="{$blog-date-lang}" />
	    </else>
	  </a>
	</dd>
      </emit>
    </dl>
  </xsl:template><!-- }}} -->

</xsl:stylesheet>
