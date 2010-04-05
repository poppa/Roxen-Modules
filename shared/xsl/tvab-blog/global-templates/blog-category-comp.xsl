<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  
  <xsl:param name="tvab-blog-category-component-enable" rxml:type="checkbox"
	     rxml:group="Component enable"
	     rxml:doc="Enable the TVAB blog category component"
	     select="1"/>

  <xsl:param name="tvab-blog-category-component-variants" rxml:type="text"
	     rxml:group="Component variants"
	     rxml:doc="Variants for the TVAB blog category component"
	     select="'0:Utförlig&#10;1:Enkel'"/>

  <rxml:variable-dependency name="node" />

  <xsl:template match="tvab-blog-category-component[variant=0]">
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">
	<xsl:call-template name="draw-blog-categories" />
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="tvab-blog-category-component[variant=1]">
    <xsl:call-template name="roxen-edit-box">
      <xsl:with-param name="content">
	<xsl:call-template name="draw-blog-categories">
	  <xsl:with-param name="type" select="'simple'" />
	</xsl:call-template>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="draw-blog-categories"><!-- {{{ -->
    <xsl:param name="type" select="'false()'" />
    <xsl:choose>
      <xsl:when test="$type = 'simple'">
	<dl>
	  <dt><a href="{$blog-category-path}">Kategorier</a></dt>
	  <xsl:choose>
	  <!-- nocache not needed for actual blog entries -->
	  <xsl:when test="//tvab-blog-entry-component">
	    <emit source='category' file="{$blog-category-file}" category="" node=""
		  sort="name">
	      <dd>
		<a style="padding-left:0" href="{$blog-category-path}?node=&_.node;">&_.name; (<count-category-items file="{$blog-category-file}" node="&_.node;" />)</a>
	      </dd>
	    </emit>
	  </xsl:when>
	  <xsl:otherwise>
	    <cache shared="yes" minutes="2">
	      <emit source='category' file="{$blog-category-file}" category="" node=""
		    sort="name">
		<dd>
		  <a style="padding-left:0" href="{$blog-category-path}?node=&_.node;">&_.name; (<count-category-items file="{$blog-category-file}" node="&_.node;" />)</a>
		</dd>
	      </emit>
	    </cache>
	  </xsl:otherwise>
	  </xsl:choose>
	</dl>
      </xsl:when>
      <xsl:otherwise>
	<xsl:choose>
	  <xsl:when test="rxml:variable('node')">
	    <emit source="category" file="{$blog-category-file}" node="{rxml:variable('node')}">
	      <div class="latest">
		<h2>&_.name;</h2>
		<set variable="var.refs" value="" />
		<emit source="category" file="{$blog-category-file}" node="&_.node;" document="">
		  <append variable="var.refs" value="&_.ref;" />
		  <append variable="var.refs"><delimiter>,</delimiter></append>
		</emit>
		<then>
		  <emit source="site-news" path="&var.refs;" split="," order-by="publish"
		        unique-paths=""> 
		    <insert file="&_.path;?__xsl=latest.xsl" />
		    <delimiter><div class="divider"><xsl:text> </xsl:text></div></delimiter>
		  </emit>
		</then>
		<else>
		  <br/>
		  <div class="notify">
		    <p><strong>Denna kategori har inga artiklar än!</strong></p>
		  </div>
		</else>
	      </div>
	    </emit>
	  </xsl:when>
	  <xsl:otherwise>
	    <dl>
	      <emit source='category' file="{$blog-category-file}" category="" node=""
		    sort="name">
		<dt>
		  <h2>
		    <a href="&page.dir;?node=&_.node;">&_.name; (<count-category-items file="{$blog-category-file}" node="&_.node;" />)</a>
		  </h2>
		</dt>
	      </emit>
	    </dl>      
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template><!-- }}} -->

</xsl:stylesheet>
