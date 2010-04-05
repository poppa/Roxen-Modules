<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template name="mima-repository-changeset"><!-- {{{ -->
    <mima-title value="Changeset: Revision {revision} for {path}"/>
    <set variable="var.ok" value="1" />
    <div class="file-header changeset">
      <div class="wrapper">
	<br/>
	<emit source="svn-log" revision="{revision}" path="{path}" verbose="">
	  <dl>
	    <dt>Date: </dt>
	    <dd><date format="string" iso-time="&_.date;" /></dd>
	  </dl>
	  <dl>
	    <dt>Author: </dt>
	    <dd>&_.author;</dd>
	  </dl>
	  <dl>
	    <dt>Message: </dt>
	    <dd><simple-wiki-format>&_.message;</simple-wiki-format></dd>
	  </dl>
	  <dl>
	    <dt>Files:</dt>
	    <dd>
	      <div class='less-more-files'>
		<ul class="filelist">
		  <emit source="values" variable="_.paths">
		    <li class="icon changed-&_.value.action;">
		      <a href="#">&_.value.path;</a>
		    </li>
		  </emit>
		</ul>
	      </div>
	    </dd>
	  </dl>
	  <div class="clear"><xsl:text> </xsl:text></div>
	</emit>
	<else>
	  <set variable="var.ok" value="0" />
	</else>
      </div>
    </div>
    <if variable="var.ok = 1">
      <!-- TODO: Unified diff. Make available through AJAX -->

      <!--
      <emit source="svn-diff" path="{path}">
	<div class="source-view">
	  <div>
	    <h3 style="margin: 5px 0 5px 5px;">&_.path;</h3>
	    <ol class="code diff">
	      <emit source="values" variable="_.value">
		<set variable="var.class" value="normal" />
		<if variable="_.value.type = +">
		  <set variable="var.class" value="added" />
		</if>
		<elseif variable="_.value.type = -">
		  <set variable="var.class" value="removed" />
		</elseif>
		<elseif variable="_.value.type = @">
		  <set variable="var.class" value="diff" />
		</elseif>
		<li class="&var.class;">&_.value.line;</li>
	      </emit>
	    </ol>
	  </div>
	</div>
      </emit>
      <else>
	<notify>
	  <p>This file has no previous revisions to compare it to!</p>
	</notify>
      </else>
      -->

      <emit source="svn-diff-table" path="{path}">
	<if variable="_.counter = 1">
	  <xsl:text disable-output-escaping="yes"><![CDATA[<table class='diff' cellspacing='0' cellpadding='0'>]]></xsl:text>
	  <tr>
	    <th class='ln'>&#160;</th>
	    <th class="diff">Old</th>
	    <th class='ln'>&#160;</th>
	    <th class="last diff">New</th>
	  </tr>
	</if>
	<tr>
	  <set variable="var.ln" value="ln" />
	  <if variable="_.old.type = break">
	    <set variable="var.ln" value="break" />
	  </if>
	  <td class="&var.ln;"><not-null value="&_.old.lineno;"/></td>
	  <td class="&_.old.type;">&_.old.line:none;</td>
	  <td class="&var.ln;"><not-null value="&_.new.lineno;"/></td>
	  <td class="&_.new.type; last">&_.new.line:none;</td>
	</tr>
      </emit>
      <then>
	<xsl:text disable-output-escaping="yes"><![CDATA[</table>]]></xsl:text>
      </then>
      <else>
	<notify>
	  <p>This file has no previous revisions to compare it to!</p>
	</notify>
      </else>
    </if>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="mima-repository-ls"><!-- {{{ -->
    <if svn-is-file="{path}">
      <mima-title value="File view: {path}"/>
      <emit source="svn-info" path="{path}">
	<div class="file-header">
	  <div class="wrapper">
	    <h3>Revision
	      <a href="&page.path;/browser/changeset/&_.revision;&_.internal-path;">&_.revision;</a>
	      <xsl:text> </xsl:text>
	      <span class="gray">by</span> 
	      <xsl:text> </xsl:text>
	      <span class="author">&_.author;</span>
	      <xsl:text> </xsl:text>
	      <span class="gray">at</span>
	      <xsl:text> </xsl:text>
	      <date type="string" iso-time="&_.date;" />
	    </h3>
	    <emit source="svn-log" revision="&_.revision;" path="{path}">
	      <wiki-text>&_.message;</wiki-text>
	      <delimiter><hr/></delimiter>
	    </emit>
	  </div>
	</div>
      </emit>
      <div class="source-view">
	<emit source="svn-cat" path="{path}" highlight="">
	  <cond>
	    <case variable="_.kind = binary">
	      Binary file
	    </case>
	    <case variable="_.kind = image">
	      <div class="rendered">
		<if variable="_.type = png">
		  <cimg data="&_.source:none;" format="&_.type;" true-alpha="1"/>
		</if>
		<else>
		  <cimg data="&_.source:none;" format="&_.type;"/>
		</else>
	      </div>
	    </case>
	    <case variable="_.kind = plaintext">
	      <div class="rendered">
		<wiki-text>&_.source:none;</wiki-text>
	      </div>
	      <br/>
	      <div class="code">
		<ol class="code">&_.colored-source:none;</ol>
	      </div>
	    </case>
	    <case variable="_.kind = source">
	      <if variable="_.type = html" or ="" match="&_.type; = htm">
		<div class="rendered">
		  &_.source:none;
		</div>
		<div class="clear"><xsl:text> </xsl:text></div><br class="clear" />
	      </if>
	      <div class="code">
		<ol class="code">&_.colored-source:none;</ol>
	      </div>
	    </case>
	  </cond>
	</emit>
	<else>
	  <notify>No such file!</notify>
	</else>
	<!--
	<set variable="var.contents"><svn-cat path="{path}" highlight=""/></set>
	<if variable="var.is-image = 1">
	  <if variable="var.img-type = png">
	    <cimg data="&var.contents:none;" format="&var.img-type;" true-alpha="1"/>
	  </if>
	  <else>
	    <cimg data="&var.contents:none;" format="&var.img-type;"/>
	  </else>
	</if>
	<elseif variable="var.is-binary = 1">
	  Binary file...
	</elseif>
	<elseif variable="var.is-plaintext = 1">
	  <h2>Formatted</h2>
	  <wiki-text>&var.contents:none;</wiki-text>
	  
	  <h2>Raw</h2>
	  <pre>&var.contents;</pre>
	</elseif>
	<else>
	  <div>
	    <ol class="code">&var.contents:none;</ol>
	  </div>
	</else>
	-->
      </div>
    </if>
    <else>
      <mima-title value="Source view: {path}"/>
      <if variable="form.sort">
	<set variable="var.sort" value="&form.sort;" />
      </if>
      <else>
	<set variable="var.sort" value="type" />
      </else>
      <table>
	<thead>
	  <tr>
	    <th class="icon"><a href="&page.path;/browser{path}">&nbsp;</a></th>
	    <th>Name</th>
	    <th class="right">Size</th>
	    <th class="right">Rev</th>
	    <th class="last">Info</th>
	  </tr>
	</thead>
	<tbody>
	  <if match="{path} is *?">
	    <set variable="var.parent"><svn-parent path="&mima.self;"/></set>
	    <tr class="parent">
	      <td colspan="7" class="last">
		<a href="&var.parent;" class="icon parent">
		  <span>../</span>
		</a>
	      </td>
	    </tr>
	  </if>
	  <emit source="svn-ls" sort="&var.sort;" path="{path}">
	    <if expr="&_.counter; % 2">
	      <set variable="var.cls" value="odd" />
	    </if>
	    <else>
	      <set variable="var.cls" value="even" />
	    </else>
	    <tr class="&var.cls;">
	      <td class="icon">
		<if variable="_.type = dir">
		  <imgs src="{$mima-root}assets/img/icons/folder_16.png" />
		</if>
		<else>
		  <imgs src="{$mima-root}assets/img/icons/document_16.png" />
		</else>
	      </td>
	      <td><a href="&page.path;/browser{path}/&_.name;">&_.name;</a></td>
	      <td class="right">
		<if variable="_.type = file">
		  <span class="filesize">&_.nicesize;</span>
		</if>
		<else>&nbsp;</else>
	      </td>
	      <td class="right">
		<a href="&page.path;/browser/changeset/&_.revision;{path}/&_.name;">&_.revision;</a>
	      </td>
	      <td class="last">
		<span class="date"><date type="string" iso-time="&_.date;"/></span>
		<xsl:text> </xsl:text>
		<span class="gray">by</span>
		<xsl:text> </xsl:text>
		<span class="author">&_.author;</span>
	      </td>
	    </tr>
	  </emit>
	</tbody>
      </table>
    </else>
  </xsl:template><!-- }}} -->

</xsl:stylesheet>
