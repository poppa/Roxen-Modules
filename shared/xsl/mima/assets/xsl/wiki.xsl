<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template name="wiki-run">
    <!-- Create page -->
    <if variable="form.wiki-create">
      <emit source="wiki-page" word="{path}"/>
      <then><redirect to="&mima.self;" /></then>
      <else>
	<h2 class="no-top-margin">Create wiki article</h2>
	<xsl:call-template name="wiki-form" />
	<then>
	  <wiki-create-page word="&form.word;" ambigous-word="&form.ambigous-word;"
			    body="&form.body;" author="&user.fullname;"
			    username="&user.username;" title="&form.title;"
			    parent="&form.parent;" keyword="&form.keyword;"
	  />
	  <notify-ok>
	    <p><strong>The Wiki article was created!</strong><br/>
	    You will now be redirected to it...</p>
	  </notify-ok>
	  <safe-js>
	    setTimeout(function() {
	      document.location.replace('&mima.self;');
	    }, 3000);
	  </safe-js>
	</then>
      </else>
    </if>
    <!-- Edit page -->
    <elseif variable="form.edit">
      <emit source="wiki-page" word="{path}">
	<mima-title value="Edit &_.title;" />
	<copy-scope from="_" to="var" />
	<xsl:call-template name="wiki-form" />
	<then>
	  <wiki-update-page word="&form.word;" ambigous-word="&form.ambigous-word;"
			    body="&form.body;" author="&user.fullname;"
			    username="&user.username;" title="&form.title;"
			    parent="&form.parent;" id="&form.id;"
			    keyword="&form.keyword;" reason="&form.reason;"
	  />
	  <then>
	    <notify-ok>
	      <p><strong>The Wiki article was updated OK!</strong><br/>
	      You will now be redirected back to it...</p>
	    </notify-ok>
	    <safe-js>
	      setTimeout(function() {
		document.location.replace('&mima.self;');
	      }, 3000);
	    </safe-js>
	  </then>
	</then>
	<xsl:call-template name="wiki-footer" />
      </emit>
      <else>
	<redirect to="&mima.self;" />
      </else>
    </elseif>
    <!-- View history -->
    <elseif variable="form.history">
      <div id="wiki-content">
	<emit source="wiki-page" word="{path}">
	  <mima-title value="Hitstory of &_.title;" />
	  <!-- Diff view -->
	  <if variable="form.action = compare">
	    <h2 class="no-top-margin">
	      Changes between <span class="gray">Revision &form.rev-old;</span> and
	      <span class="gray">Revision &form.rev;</span> of <span class="gray">&_.title;</span>
	    </h2>
	    <p>
	      <a href="&mima.self;?history=1&amp;rev=&form.rev;&amp;rev-old=&form.rev-old;">Back to history</a>
	    </p>
	    <emit source="wiki-diff" word="{path}" 
		  rev="&form.rev;" 
		  old-rev="&form.rev-old;"
		  added="var.added" removed="var.removed">
	      <if variable="_.counter = 1">
		<ttag name="div" class="source-view" />
		<ttag name="div" />
		<h3 style="margin: 5px">Content</h3>
		<p style="margin: 0 0 7px 5px">Lines added: &var.added;<br/>
		   Lines removed: &var.removed;</p>
		<ttag name="ol" class="code diff" />
	      </if>
	      <if variable="_.type = reference">
		<li class="normal">&_.line;</li>
	      </if>
	      <elseif variable="_.type = added">
		<li class="added">&_.line;</li>
	      </elseif>
	      <elseif variable="_.type = removed">
		<li class="removed">&_.line;</li>
	      </elseif>
	      <elseif variable="_.type = line">
		<li class="diff">&_.line;</li>
	      </elseif>
	    </emit>
	    <then>
	      <ttag name="ol" close="" />
	      <ttag name="div" close="" />
	      <ttag name="div" close="" />
	    </then>
	    <else>
	      <notify>
		<p>Unable to compare revisions</p>
	      </notify>
	    </else>
	    <p>
	      <a href="&mima.self;?history=1&amp;rev=&form.rev;&amp;rev-old=&form.rev-old;">Back to history</a>
	    </p>
	  </if>
	  <!-- Revision list -->
	  <else>
	    <h2 class="no-top-margin">History for <span class="gray">&_.title;</span></h2>
	    <form action="&mima.self;" method="get">
	      <input type="hidden" name="history" value="1" />
	      <input type="hidden" name="action" value="compare" />
	      <p>
		<input type="submit" name="do" value="View differencies" />
	      </p>
	      <table cellspacing="0" cellpadding="0">
		<thead>
		  <tr>
		    <th colspan="2">&#160;</th>
		    <th style="width:20px">Rev.</th>
		    <th>Author</th>
		    <th class="last">Comment</th>
		  </tr>
		</thead>
		<tbody>
		  <emit source="wiki-history" word="{path}">
		    <if not="" variable="form.rev">
		      <set variable="form.rev" value="&_.revision;" />
		    </if>
		    <elseif not="" variable="form.rev-old">
		      <set variable="form.rev-old" value="&_.revision;" />
		    </elseif>
		    <tr>
		      <td style="width:10px">
			<default value="&form.rev-old;">
			  <input type="radio" name="rev-old" value="&_.revision;" />
			</default>
		      </td>
		      <td style="width:10px">
			<default value="&form.rev;">
			  <input type="radio" name="rev" value="&_.revision;" />
			</default>
		      </td>
		      <td style="text-align:right">&_.revision;</td>
		      <td>&_.author;</td>
		      <td class="last"><not-null value="&_.reason;"/></td>
		    </tr>
		  </emit>
		</tbody>
	      </table>
	      <p>
		<input type="submit" name="do" value="View differencies" />
	      </p>
	    </form>
	  </else>
	  <xsl:call-template name="wiki-footer" />
	</emit>
	<else>
	  <redirect to="&mima.self;" />
	</else>
      </div>
    </elseif>
    <!-- Display page -->
    <else>
      <emit source="wiki-page" word="{path}">
	<mima-title value="&_.title;" />
	<div id="wiki-content">
	  <h1 class="no-top-margin">&_.title;</h1>
	  <if sizeof="_.keyword &gt; 0">
	    <div class="metadata">
	      <p>Keywords: 
		<emit source="values" variable="_.keyword" split=",">
		  <if variable="_.value = &form.keyword;">
		    <a href="&mima.self;?keyword=&_.value;"><strong>&_.value;</strong></a>
		  </if>
		  <else>
		    <a href="&mima.self;?keyword=&_.value;">&_.value;</a>
		  </else>
		  <delimiter>, </delimiter>
		</emit>
	      </p>
	      <if variable="form.keyword">
		<emit source="wiki-keyword" word="{path}" keyword="&form.keyword;">
		  <if variable="_.counter = 1">
		    <ttag name="p" />
		    <strong>Related articles: </strong> 
		  </if>
		  <a href="{$mima-root}index.xml/wiki/&_.word;">&_.title;</a>
		  <delimiter>, </delimiter>
		</emit>
		<then>
		  <ttag name="p" close="" />
		</then>
		<else>
		  <notify>
		    <p>There's no other Wiki articles with keyword <strong>&form.keyword;</strong></p>
		  </notify>
		</else>
	      </if>
	    </div>
	  </if>
	  <wiki-text>&_.body:none;</wiki-text>
	</div>
	<xsl:call-template name="wiki-footer" />
      </emit>
      <else>
	<xsl:variable name="word">
	  <xsl:choose>
	    <xsl:when test="string-length(path) = 0">WikiHome</xsl:when>
	    <xsl:otherwise><xsl:value-of select="path" /></xsl:otherwise>
	  </xsl:choose>
	</xsl:variable>
	<notify>
	  <p>No page is created for <code><xsl:value-of select="$word" /></code> yet!</p>
	  <p><a href="&mima.self;?wiki-create=1">Create</a></p>
	</notify>
      </else>
    </else>
  </xsl:template>
  
  <xsl:template name="wiki-footer">
    <div id="wiki-footer">
      <if variable="form.edit">
	<set variable="var.edit-select" value=" class='selected'" />
      </if>
      <elseif variable="form.history">
	<set variable="var.history-select" value=" class='selected'" />
      </elseif>
      <else>
	<set variable="var.article-select" value=" class='selected'" />
      </else>
      <div class="action">
	<ul>
	  <li ::="&var.article-select;"><a href="&mima.self;">Article</a></li>
	  <li ::="&var.edit-select;"><a href="&mima.self;?edit=1">Edit</a></li>
	  <li ::="&var.history-select;"><a href="&mima.self;?history=1">History</a></li>
	</ul>
      </div>
      <div class="info">
       <p>&_.author; <date iso-time="&_.date;" type="string" />, revision &_.revision;</p>
      </div>
      <div class="clear"><xsl:text> </xsl:text></div>
    </div>
  </xsl:template>

  <xsl:template name="wiki-form">
    <if variable="form.__reload">
      <h1 class="no-top-margin">&form.title;</h1>
      <wiki-text>&form.body:none;</wiki-text>
      <br/>
    </if>
    <vform action="&mima.self;" hide-if-verified="">
      <if variable="form.wiki-create">
	<input type="hidden" name="wiki-create" value="1" />
	<set variable="var.word" value="{path}" />
	<set variable="var.title" value="{path}" />
      </if>
      <elseif variable="form.edit">
	<input type="hidden" name="edit" value="1" />
	<input type="hidden" name="id" value="&var.id;" />
      </elseif>

      <fieldset>
	<legend>Wiki page</legend>
	<input type="hidden" name="word" value="{path}" />
	<label>
	  <span>Wiki word</span>
	  <input type="text" name="_word" value="&var.word;" disabled="disabled"/>
	</label>
	<label>
	  <span>Title</span>
	  <mima-input type="string" value="&var.title;" name="title" minlength="2">
	    Please give a title
	  </mima-input>
	</label>
	<label>
	  <span>Keywords <small>comma separated list</small></span>
	  <if variable="var.keyword = 0">
	    <set variable="var.keyword" value="" />
	  </if>
	  <mima-input type="string" value="&var.keyword;" name="keyword" />
	</label>
	<label>
	  <span>Article</span>
	  <mima-input type="text" value="&var.body;" name="body" minlength="10" 
	              style="height:450px;width:100%">
	    This article is too short. At least 10 characters please!
	  </mima-input>
	</label>
	<div class="less-and-more">
	  <xsl:call-template name="wiki-help" />
	</div>
	<if variable="form.edit">
	  <label>
	    <span>Reason <small>Why did you edit this page?</small></span>
	    <mima-input type="string" name="reason" />
	  </label>
	</if>
      </fieldset>
      <!--<input type="submit" name="preview" value="Preview" />-->
      <reload name="preview" value="Preview" />
      <xsl:text> </xsl:text>
      <input type="Submit" name="send" value="Save" />
    </vform>
  </xsl:template>

  <xsl:template name="wiki-help">
    <h2>Text formatting</h2>
    <div style="float:left;width:48%">
      <code>**bold**</code><br/>
      <code>//italic//</code><br/>
      <code>**//bold italic//**</code><br/>
      <code>^^superscript^^</code><br/>
      <code>__subscript__</code><br/>
      <code>`monospace`</code>
    </div>
    <div style="float:right;width:48%">
      <strong>bold</strong><br/>
      <em>italic</em><br/>
      <strong><em>bold italic</em></strong><br/>
      <sup>superscript</sup> like m<sup>3</sup><br/>
      <sub>subscript</sub> like co<sub>2</sub><br/>
      <code>monospace</code>
    </div>
    <div class="clear"><xsl:text> </xsl:text></div>
    <h2>Headings</h2>
    <p>Headings are created by preceeding the text with one or more = (equal sign).
    The number of equal signs will determine the header level.</p>
    <p>
      <code>= Header level 1</code><br/>
      <code>== Header level 2</code><br/>
      <code>=== Header level 3</code>
    </p>
    <p>and so on</p>
  </xsl:template>

</xsl:stylesheet>
