<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:import href="/cms-common.xsl" />

  <xsl:template match="twitter-component">
    <div id="twitter">
      <nocache>
	<!-- Assuming consumer key and secret is set in module settings -->
	<twitter>
	  <if variable="_.is-authenticated = 0">
	    <!-- Callback from Twitter -->
	    <if variable="form.oauth_token" and="" Variable="_.request-token-key">
	      <twitter-get-access-token />
	      <redirect to="&page.self;" />
	    </if>
	    <elseif variable="form.do-login">
	      <set variable="var.auth-url"><twitter-get-auth-url /></set>
	      <redirect to="&var.auth-url:none;" />
	    </elseif>
	    <else>
	      <a href="&page.self;?do-login=1">Login via Twitter</a>
	    </else>
	  </if>
	  <else>
	    <xsl:call-template name="do-twitter" />
	  </else>
	</twitter>
      </nocache>
    </div>
  </xsl:template>

  <xsl:template name="do-twitter">
    <set variable="var.url" value="http://twitter.com" />
    <define tag="says">
      <p class="says">
	<span>Said on</span>
	<xsl:text> </xsl:text>
	<span class="date">
	  <date iso-time="&twitter.status.created_at;" strftime="%R, %B %e"/>
	</span>
	<xsl:text> </xsl:text>
	<span class="text">&twitter.status.text;</span>
      </p>
    </define>

    <cond>
      <case variable="form.do = followers">
	<h1>My friends</h1>
	<emit source="twitter-call" url="&var.url;/friends/ids.xml" cache="3600">
	  <emit source="twitter-call" url="&var.url;/users/show.xml"
		user_id="&_.id;" cache="12000" scope="twitter">
	    <div class="user">
	      <img src="&_.profile_image_url;" />
	      <h3>&_.name; <small>(&_.screen_name;)</small></h3>
	      <says/>
	    </div>
	  </emit>
	  <else>
	    <p>User of id &_.id; was not found!</p>
	  </else>
	</emit>
	<else>
	  No followers
	</else>
      </case>
      <case variable="form.do = logout">
	<twitter-logout />
	<redirect to="&page.self;" />
      </case>
      <default>
	<xsl:call-template name="twitter-credentials" />
      </default>
    </cond>
  </xsl:template>

  <xsl:template name="twitter-credentials">
    <h1>This is me</h1>
    <emit source="twitter-verify-credentials" scope="twitter">
      <div class="user">
	<img src="&_.profile_image_url;" />
	<h3>&_.name; <span class="default">from</span> &_.location;</h3>
	<says/>
      </div>
    </emit>
    <else>
      <p>Empty result</p>
    </else>
  </xsl:template>

</xsl:stylesheet>