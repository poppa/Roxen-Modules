<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <rxml:variable-dependency name="unsubscribe" />

  <xsl:template name="form-missing-field">
    <xsl:param name="form-field" />
    <xsl:param name="text" />
    <span class="error"><xsl:value-of select="$text" /></span>
  </xsl:template>
  
  <xsl:template name="comments">
    <if variable="form.do = delete">
      <if comment-admin-permission="&page.path;" id="&form.id;">
	<comment-delete id="&form.id;" />
	<redirect to="&page.path;" />
      </if>
    </if>
    <hr style="display:none" />
    <noindex>
      <h2 id="comments">Kommentarer
	<small id="to-comment-form"><a href="#comment-form">Skriv en kommentar</a></small>
	<xsl:text>&nbsp; &nbsp;</xsl:text>
	<small>
	  <a title="Prenumerera på denna sidas kommentarer"
	     href="{$blog-base}comments.rss&page.path;"
	     class="rss-16">Prenumerera</a>
	</small>
      </h2>

      <xsl:if test="rxml:variable('unsubscribe')">
	<br/>
	<comments-unsubscribe hash="{rxml:variable('unsubscribe')}" />
	<then>
	  <div class="notify">
	    <p>Du har avslutat e-postmeddelanden vid nya kommentarer till denna sida.</p>
	  </div>
	</then>
	<else>
	  <div class="notify">
	    <p>Kunde inte avsluta prenumerationen.<br/>
	       Du kan kontakta webbansvarig - se sidfoten för denna sida - 
	       om du vill avsluta prenumerationen.</p>
	  </div>
	</else>
      </xsl:if>
    </noindex>
    <ol class="comments">
      <emit source="comments">
	<if expr="_.counter % 2">
	  <set variable="var.class" value="odd" />
	</if>
	<else>
	  <set variable="var.class" value="even" />
	</else>
	<if variable="_.owner = y">
	  <set variable="var.class" value="author" />
	</if>
	<set variable="var.gravatar"><gravatar size="36" default-image="http://&roxen.domain;/blogg/assets/user.png" email="&_.email;" /></set>
	<li class="&var.class;" id="comment-&_.id;" style="background-image: url(&var.gravatar:none;)">
	  <div class="header">
	    <if sizeof="_.url &gt; 0">
	      <a title="User's web site: &_.url;" href="&_.url;">&_.author;</a>
	    </if>
	    <else>
	      <h3>&_.author;</h3>
	    </else>
	    <xsl:text> </xsl:text>
	    <span>skrev</span>
	    <xsl:text> </xsl:text>
	    <em class="date"><date iso-time="&_.date;" brief="" lang="{$blog-date-lang}" /></em>
	    &nbsp; &nbsp;
	    <small><a href="&page.self;#comment-&_.id;">Permalänk</a></small>
	    <br class="clear"/>
	  </div>
	  <div class="body">
	    <strip-tags nopara="code" paragraphify="" linkify="" 
			keep-containers="strong,em" nl2br=""
			remove-illegal-xml-chars="">&_.body:none;</strip-tags>
	    <if variable="user.is-toolbar = 1">
	      <if comment-admin-permission="" id="&_.id;">
		<noindex>
		  <p class="tools">
		    <a href="javascript: if(confirm('Är du säker på att du vill radera denna kommentar')) top.location.href = '&page.path;?do=delete&amp;id=&_.id;';"
		    >Radera</a> |
		    <a href="&page.self;?do=edit&amp;id=&_.id;#comment-form">Redigera</a>
		  </p>
		</noindex>
	      </if>
	    </if>
	  </div>
	</li>
      </emit>
      <else>
	<noindex>
	  <li class="empty"><p>Det finns inga kommentarer till denna artikel ännu.</p></li>
	</noindex>
      </else>
    </ol>
    <xsl:call-template name="comment-form" />
  </xsl:template>


  <xsl:template name="comment-form">
    <set variable="var.is-blog-author" value="0" />
    <noindex>
      <vform action="&page.self;#comment-form" method="post" hide-if-verified="">
	<fieldset id="comment-form">
	  <roxen-automatic-charset-variable/>
	  <set variable="var.edit-mode" value="0" />
	  <if variable="form.do = edit">
	    <set variable="var.edit-mode" value="1" />
	    <emit source="comment" id="&form.id;">
	      <if comment-admin-permission="" id="&form.id;">
		<input type="hidden" name="do" value="edit" />
		<input type="hidden" name="id" value="&_.id;" />
		<copy-scope from="_" to="var" />
	      </if>
	      <else>
		<xsl:call-template name="common-form-vars" />
	      </else>
	    </emit>
	  </if>
	  <else>
	    <xsl:call-template name="common-form-vars" />
	    <if variable="user.is-authenticated = 0">
	      <verify-approve submit="send" />
	    </if>
	  </else>

	  <!-- If the visitor has commented the current article we unlock the
	       send notification lock. -->
	  <comment-set-mailstatus path="&page.path;" status="0" email="&var.email;" />

	  <script type="text/javascript"><xsl:text> </xsl:text></script>
	  <noscript>
	    <div class="notify">
	      <p>Du måste ha <strong>JavaScript</strong> aktiverat för att skicka en kommentar!</p>
	    </div>
	  </noscript>

	  <if sizeof="form.comment &gt; 0">
	    <force-session-id />
	    <if variable="form.sessid != &client.session;">
	      <verify-fail />
	      <div class="notify">
		<p><strong>&form.sessid;</strong></p>
		<p>Det verkar som att du har skickat kommentaren på ett otillåtet sätt!</p>
	      </div>
	    </if>
	  </if>

	  <input type="hidden" name="path" value="&page.path;" />
	  <input type="hidden" name="sessid" id="sessid" value="0" />
<!--
	  <set variable="var.days-left"><comment-form-expires type="days" /></set>
-->
	  <label>
	    <span>Ditt namn <small>obligatorisk</small></span>
	    <if variable="user.is-authenticated = 1" and="" Variable="var.edit-mode = 0">
	      <input type="hidden" name="author" value="&var.author;" />
	      <input type="text" size="40" name="fake-author" value="&var.author;" disabled="disabled"/>
	    </if>
	    <else>
	      <vinput type="string" name="author" value="&var.author;" id="cauthor" minlength="2">
		<xsl:call-template name="form-missing-field">
		  <xsl:with-param name="form-field" select="'cauthor'" />
		  <xsl:with-param name="text" select="'Var god ange ditt namn'" />
		</xsl:call-template>
	      </vinput>
	    </else>
	  </label>
	  <br/>
	  <label>
	    <span>E-post <small>obligatorisk</small></span>
	    <if variable="var.is-blog-author = 1" and="" sizeof="var.email &gt; 0">
	      <input type="hidden" name="email" value="&var.email;" />
	      <input type="text" size="40" name="fake-email" value="&var.email;" disabled="disabled" />
	    </if>
	    <else>
	      <vinput type="email" name="email" value="&var.email;" id="cemail">
		<xsl:call-template name="form-missing-field">
		  <xsl:with-param name="form-field" select="'cemail'" />
		  <xsl:with-param name="text" select="'Var god ange din e-postadress'" />
		</xsl:call-template>
	      </vinput>
	    </else><xsl:text> </xsl:text> <small style="color:#555">Kommer inte att visas</small>
	  </label>
	  <br/>
	  <label>
	    <span>Din kommentar <small>obligatorisk</small></span>
	    <vinput type="text" name="comment" id="ccomment" value="&var.body;" 
		    rows="10" cols="40" minlength="2" style="width:437px;height:150px">
	      <xsl:call-template name="form-missing-field">
		<xsl:with-param name="form-field" select="'ccomment'" />
		<xsl:with-param name="text" select="'Var god skriv något'" />
	      </xsl:call-template>
	    </vinput>
	  </label>

	  <if variable="var.is-blog-author = 0">
	    <br />
	    <label>
	      <default variable="form.remember">
		<input type="checkbox" name="remember" /> Kom ihåg mig
	      </default>
	    </label>
	    <if variable="user.is-authenticated = 1">
	      &nbsp; &nbsp; <xsl:text> </xsl:text>
	      <label>
		<default variable="form.notify">
		  <input type="checkbox" name="notify" /> Skicka meddelande vid svar
		</default>
	      </label>
	    </if>
	    <else>
	      <if variable="var.edit-mode = 0">
		<p style="margin-bottom:0"><approve-form /></p>
	      </if>
	    </else>
	  </if>
	  <br/><br/>
	  <input type="submit" name="send" value="Skicka kommentar" class="btn" />
	  <if variable="form.do = edit">
	    <xsl:text> </xsl:text>
	    <input type="button" class="btn" 
		   onclick="document.location.href = '&page.self;'" 
		   value="Avbryt" />
	  </if>
	</fieldset>
      </vform>
      <then>
	<if variable="form.remember">
	  <set-cookie name="TvabBlogCmt" value="&form.author;¤#&form.email;"
		      persistent="" path="{$blog-root}" 
	  />
	</if>
	<if variable="form.do = edit">
	  <comment-update id="&form.id;">&form.comment;</comment-update>
	  <then>
	    <redirect to="&page.path;#comment-&form.id;" />
	  </then>
	  <else>
	    <div class="notify"><strong>Kunde inte uppdatera kommentaren</strong></div>
	  </else>
	</if>
	<else>
<define variable="var.mail-template" preparse="">
Hej [receiver]!

[commenter] har lämnat en kommentar till artikeln "&page.title;" som du också har kommenterat.
Läs kommentaren genom att följa länken nedan:

<trim right="" char="/">&roxen.server;</trim>[url]#comment-[id]

Det kan ha kommit fler kommentarer sedan detta e-brev skickades.

Om du inte längre vill få meddelande om nya kommentarer till denna artikel kan
du klicka på länken nedan.

<trim right="" char="/">&roxen.server;</trim>[url]?unsubscribe=[hash]

# Ha en trevlig dag önskar Tekniska Verken's mejlrobot!
# OBS! Detta mejl skapades automatiskt och går inte att svara på.
</define>
	  <comment-add email="&form.email;"
		       author="&form.author;"
		       url="&form.url;"
		       mail-template="&var.mail-template;"
		       mail-subject='Ny kommentar till "&page.title;" på Tekniska Verken'
		       insert-id="var.comment-id">&form.comment;</comment-add>
	  <then>
	    <xsl:if test="string-length($blog-authors)">
<define variable="var.notify-template" preparse="" trimwhites="">
Hallå!

En ny kommentar har anlänt till artikeln "&page.title;"

----
&form.author; (&form.email;)

&form.comment:none;
----

Gå till kommentaren:
<trim right="" char="/">&roxen.server;</trim>&page.path;#comment-&var.comment-id;

Stay black!
</define>
	      <if variable="page.author-name != &user.username;">
		<emit source="tvab-blog-author">
		  <if variable="_.username = &page.author-name;">
		    <set variable="var.notify-email" value="&_.email;" />
		  </if>
		</emit>
		<then>
		  <if variable="var.notify-email">
		    <email to="&var.notify-email;"
			   from="no-reply@tekniskaverken.se"
			   subject="Ny kommentar till &page.title;">&var.notify-template;</email>
		  </if>
		</then>
	      </if>
	    </xsl:if>
	    <redirect to="&page.path;#comment-&var.comment-id;" />
	  </then>
	  <else>
	    <div class="notify">
	      <strong>Ooop! Kunde inte spara kommentaren</strong>
	    </div>
	  </else>
	</else>
      </then>
    </noindex>
  </xsl:template>

  <xsl:template name="common-form-vars">
    <if cookie="TvabBlogCmt">
      <sscanf format="%s¤#%s" variables="author,email" scope="var">&cookie.TvabBlogCmt;</sscanf>
    </if>
    <if variable="user.is-authenticated = 1">
      <set variable="var.author" value="&user.fullname;" />
      <emit source="tvab-blog-author" path="{$blog-root}" username="&user.username;">
	<set variable="var.email" value="&_.email;" />
	<set variable="var.is-blog-author" value="1" />
      </emit>
    </if>
    <input type="hidden" name="do" value="addnew" />
  </xsl:template>

</xsl:stylesheet>
