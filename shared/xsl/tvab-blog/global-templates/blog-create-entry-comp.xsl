<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="tvab-blog-home-page-component-enable" rxml:type="checkbox"
	     rxml:group="Component enable"
	     rxml:doc="Enable the TVAB blog homepage component"
	     select="1"/>

  <xsl:param name="tvab-blog-home-page-component-variants" rxml:type="text"
	     rxml:group="Component variants"
	     rxml:doc="Variants for the TVAB blog homepage component"
	     select="'0:Standard'"/>

  <xsl:template match="tvab-blog-home-page-component[variant=0]">
    <if variable="user.is-toolbar = 1">
      <h2>Skapa ny bloggpost</h2>
      <xsl:call-template name="blog-create-entry" />
    </if>
    <else>
      <xsl:call-template name="draw-tvab-blog-archive">
	<xsl:with-param name="limit" select="$blog-view-per-page" />
      </xsl:call-template>
    </else>
  </xsl:template>

  <xsl:template name="blog-create-entry"><!-- {{{ -->
    <xsl:call-template name="helpers" />
    <if variable="form.unpublished">
      <xsl:call-template name="show-unpublished-files" />
    </if>
    <else>
      <xsl:call-template name="entry-form"/>
    </else>
  </xsl:template><!-- }}} -->

  <xsl:template name="entry-form"><!-- {{{ -->
    <p>
      <a class="read-more" href="&page.self;?unpublished=1">Visa opublicerade filer</a>
    </p>
    <nocache>
      <vform method="post" action="{$blog-root}index.xml" hide-if-verified="">
	<label for="ttl" style="display:inline">Sidans titel</label><xsl:text> </xsl:text><br/>
	<vinput type="string" name="page-title" id="ttl" minlength="2">
	  <div class="notify"><strong>Du måste ange en titel</strong></div>
	</vinput><xsl:text> </xsl:text>

	<xsl:call-template name="generate-category-struct" />

	<br/>

	<label style="display:inline">
	  <span style="display:inline">Nyckelord</span><xsl:text> </xsl:text>
	  <small style="color:#666">valfri</small>
	  <br/>
	  <vinput type="string" name="keywords" />
	</label>

	<br/>

	<label style="margin-top:15px;line-height:90%;display:block;">
	  <span style="display:inline">Annat publiceringsdatum</span><xsl:text> </xsl:text>
	  <small style="color:#666">valfri<br/>
	  Exempel: 2008-11-12, 2009-03-08 12:30</small><br/>
	  <vinput type="date" name="pubdate" optional="" id="pubdate">
	    <div class="notify"><strong>Not a valid date!</strong></div>
	  </vinput><xsl:text> </xsl:text><popcal field="pubdate" />
	</label>

	<br/>

	<input type="submit" class="btn" name="do" value="Skapa sidan" />
      </vform>
      <then><!-- {{{ -->
	<set variable="var.pubdate" value="0" />
	<if sizeof="form.pubdate &gt; 0">
	  <sscanf format="%4d-%2d-%2d %2d:%2d" scope="var" 
		  variables="yr,md,dg,hr,mn">&form.pubdate;</sscanf>
	  <set variable="var.month-str"><date iso-time="&form.pubdate;" lang="{$blog-date-lang}" type="string"  part="month" /></set>
	  <if sizeof="var.hr = 0">
	    <set variable="var.hr"><date part="hour" /></set>
	  </if>
	  <if sizeof="var.mn = 0">
	    <set variable="var.mn"><date part="minute" /></set>
	  </if>
	  <set variable="var.pubdate" value="&var.yr;-&var.md;-&var.dg;T&var.hr;:&var.mn;:00" />
	</if>
	<else>
	  <sscanf format="%4d-%2d-%2d"
		  scope="var"
		  variables="yr,md,dg"><date lang="{$blog-date-lang}" date="" type="iso" /></sscanf>
	  <set variable="var.month-str"><date lang="{$blog-date-lang}" type="string" part="month" /></set>
	</else>
	<catch>
	  <sb-edit-area>
	    <define container="sb-handle-error">
	      <sb-error><throw preparse="preparse">
		Ett "&_.type;"-fel uppstod under "&_.operation;" på filen
		"&_.sbobj;". Anledningen är: "&_.reason;".
	      </throw></sb-error>
	    </define>

	    <if not="" exists="&var.yr;">
	      <create-directory path="&var.yr;" /><sb-handle-error />
	      <create-archive-index path="&var.yr;"
				    title="&var.yr;"
				    type="year-index"
	      /><sb-handle-error />
	    </if>
	    <if not="" exists="&var.yr;/&var.md;">
	      <create-directory path="&var.yr;/&var.md;" /><sb-handle-error />
	      <create-archive-index path="&var.yr;/&var.md;"
				    title="&var.month-str;"
				    type="month-index"
				    header-title="&var.month-str; &var.yr;"
	      /><sb-handle-error />
	    </if>
	    <create-blog-file path="&var.yr;/&var.md;/"
			      title="&form.page-title;"
			      keywords="&form.keywords;"
			      pubdate="&var.pubdate;"
	    />
	  </sb-edit-area>
	</catch>
      </then><!-- }}} -->
    </nocache>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="show-unpublished-files"><!-- {{{ -->
    <cset variable="var.unp"><unpublished-files/></cset>
    <if sizeof="var.unp &gt; 10">
      <h3>Opublicerade/osynliga filer</h3>
      <table class="nice" cellspacing="0" cellpadding="0">
	<thead>
	  <tr class="header">
	    <th style="width:20px;text-align:right;padding-right:0px">Du</th>
	    <th style="width:10.5px;text-align:center">Sajt</th>
	    <th>Titel</th>
	  </tr>
	</thead>
	<tbody>&var.unp:none;</tbody>
      </table>
    </if>
    <else>
      <div class="notify-ok"><p><strong>Inga opublicerade filer</strong></p></div>
    </else>
    <p><a class="read-more" href="&page.self;">Visa formulär</a></p>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="generate-category-struct"><!-- {{{ -->
    <set variable="var.cats"><tvab-get-categories /></set>
    <if sizeof="var.cats &gt; 0">
      <div style='margin: 10px 0 5px 0;'>u
	Tilldela en eller flera kategorier till sidan (valfri)
      </div>
      &var.cats:none;
    </if>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="helpers"><!-- {{{ -->
    <define tag="create-directory"><!-- {{{ -->
      <attrib name="path" />
      <sb-new-dir dir="&_.path;" message="Katalogen skapad av blogg-admin" />
    </define><!-- }}} -->

    <define tag="normalize-path" trimwhites=""><!-- {{{ -->
      <attrib name="path" />
      <attrib name="title" />
      <attrib name="index">0</attrib>
      <attrib name="length">40</attrib>

      <set variable="var.path"><trim right="" char="/">&_.path;</trim></set>

      <set variable="var.ntitle"><valid-path-name length="&_.length;" path="&_.title;" /></set>
      <set variable="var.suffix" value="" />
      <if variable="_.index &gt; 0">
	<set variable="var.suffix" value="-&_.index;" />
      </if>
      <set variable="var.npath" value="&var.path;/&var.ntitle;&var.suffix;/" />
      <if exists="&var.npath;">
	<set variable="var.nindex" expr="&_.index; + 1" />
	<normalize-path path="&_.path;" title="&_.title;" index="&var.nindex;" 
	                length="&_.length;" />
      </if>
      <else>&var.npath;</else>
    </define><!-- }}} -->

    <!-- Create a new blog file -->
    <define tag="create-blog-file"><!-- {{{ -->
      <attrib name="path" />
      <attrib name="title" />
      <attrib name="keywords" />
      <attrib name="pubdate">0</attrib>

      <set variable="var.new-path"><normalize-path path="&_.path;" title="&_.title;" /></set>

      <create-directory path="&var.new-path;"/><sb-handle-error/>

      <set variable="var.newname" value="&var.new-path;/index.xml" />

      <sb-new-file file="&var.newname;"
		   content-type="sitebuilder/xml-page-editor"
      /><sb-handle-error />

      <sb-set-metadata file="&var.newname;" name="title">&_.title;</sb-set-metadata>
      <sb-set-metadata file="&var.newname;" name="template">cms-common.xsl</sb-set-metadata>
      <sb-set-metadata file="&var.newname;" name="keywords">&_.keywords;</sb-set-metadata>

      <if variable="_.pubdate != 0">
	<sb-set-external-visibility file="&var.newname;"
	                            from="&_.pubdate;"
				    to="infinity" />
      </if>

      <sb-category file="&var.newname;">
	<emit source="tvab-assigned-categories">
	  <category file='&_.file;' node='&_.node;' />
	</emit>
      </sb-category><sb-handle-error />

      <sb-set-content file="&var.newname;">
	<page-components>&#13;
	  <tvab-blog-entry-component>&#13;
	    <id><get-unique-component-id /></id>&#13;
	    <variant>0</variant>&#13;
	  </tvab-blog-entry-component>&#13;&#13;

	  <header-component>&#13;
	    <id><get-unique-component-id /></id>&#13;
	    <variant>1</variant>&#13;
	    <title></title>&#13;
	    <subtitle></subtitle>&#13;
	  </header-component>&#13;&#13;

	  <footer-component>&#13;
	    <id><get-unique-component-id /></id>&#13;
	    <variant>2</variant>&#13;
	    <revised></revised>&#13;
	    <author></author>&#13;
	  </footer-component>&#13;
	</page-components>
      </sb-set-content>
      <redirect to="&var.newname;?__toolbar=1" />
    </define><!-- }}} -->

    <define tag="create-archive-index"><!-- {{{ -->
      <attrib name="path" />
      <attrib name="type" />
      <attrib name="title" />
      <attrib name="header-title" />
      <set variable="var.newname" value="&_.path;/index.xml" />
      <sb-new-file file="&var.newname;"
		   content-type="sitebuilder/xml-page-editor"
      />

      <set variable="var.header-title" value="" />

      <cond>
	<case variable="_.type = year-index">
	  <set variable="var.variant" value="0" />
	  <define variable="var.content" preparse="yes">
	    <tvab-blog-archive-component>
	      <id><get-unique-component-id /></id>
	      <variant>0</variant>
	    </tvab-blog-archive-component>
	  </define>
	</case>
	<case variable="_.type = month-index">
	  <set variable="var.variant" value="1" />
	  <define variable="var.content" preparse="yes">
	    <tvab-blog-archive-component>
	      <id><get-unique-component-id /></id>
	      <variant>1</variant>
	    </tvab-blog-archive-component>
	  </define>
	</case>
      </cond>

      <sb-set-metadata file="&var.newname;" name="title">&_.title;</sb-set-metadata>
      <sb-set-metadata file="&var.newname;" name="template">cms-common.xsl</sb-set-metadata>
      <sb-set-content file="&var.newname;">
	<page-components>
	  <header-component>
	    <id><get-unique-component-id /></id>
	    <variant>&var.variant;</variant>
	    <title>&_.header-title;</title>
	    <subtitle></subtitle>
	  </header-component>

	  &var.content;

	  <footer-component>
	    <id><get-unique-component-id /></id>
	    <variant>0</variant>
	    <revised></revised>
	    <author></author>
	  </footer-component>
	</page-components>
      </sb-set-content>

      <sb-commit file="&var.newname;" message="Auto-committed by blog-admin" />
    </define><!-- }}} -->
    
    <!-- Find unpublished files -->
    <define tag="unpublished-files" trimwhites=""><!-- {{{ -->
      <attrib name="path">&page.dir;</attrib>
      <emit source="dir" path="&_.path;" dirs="" invisible="" notitle=""
	    sort="-dirname" scope="outer">
	<unpublished-files path="&_.path;" />
      </emit>
      <else>
	<emit source="dir" path="&_.path;" file="index.xml">
	  <set variable="var.is-visible" value="1" />
	  <if variable="_.visible-from != now">
	    <if time="&_.visible-from;" before="" inclusive="">
	      <set variable="var.is-visible" value="0" />
	    </if>
	  </if>
	  <if variable="_.visible-to != infinity">
	    <if time="&_.visible-to;" before="" inclusive="">
	      <set variable="var.is-visible" value="0" />
	    </if>
	  </if>
	  <if variable="_.user-status != none" or="" 
	      Variable="_.site-status != exists">
	    <set variable="var.is-visible" value="0" />
	  </if>
	  <if variable="var.is-visible = 0">
	    <tr>
	      <td style="text-align:center" colspan="2">
		<img style="margin-left:-12px" src="&_.status-img;" />
	      </td>
	      <td style="vertical-align: middle" class="last">
		<a href="&_.path;">
		  <span><strong>&_.title;</strong></span>
		  <xsl:text> </xsl:text>
		</a>
	      </td>
	    </tr>
	  </if>
	</emit>
      </else>
    </define><!-- }}} -->
  </xsl:template><!-- }}} -->

</xsl:stylesheet>
