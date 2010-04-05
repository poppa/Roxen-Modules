<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:import href="/cms-common.xsl" />
  
  <xsl:template match="page-components">
    <xsl:apply-templates select="*[name() != 'footer-component']">
      <xsl:with-param name="content-width" select="$content-width" />
    </xsl:apply-templates>
    <nocache>
      <xsl:call-template name="openid-form" />
    </nocache>
    <xsl:apply-templates select="*[name() = 'footer-component']">
      <xsl:with-param name="content-width" select="$content-width" />
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template name="openid-form">
    <if variable="form.__logout">
      <openid-logout />
      <redirect to="&page.self;" />
    </if>

    <if not="" openid="" authenticated="">
      <ul>
	<li><a href="&page.self;?op=google">Sign in with Google</a></li>
	<li><a href="&page.self;?op=yahoo">Sign in with Yahoo</a></li>
      </ul>
      or by your own selected provider
      <vform method="get">
	<label>
	  <span>Your OpenID address</span>
	  <vinput type="string" name="op" />
	</label>
	<input type="submit" value="Sign in" />
      </vform>
      <if variable="form.op">
	<openid-login-url operator="&form.op;"/>
	<else>
	  <p>Unable to find login URL for provider <strong>&form.op;</strong></p>
	</else>
      </if>
      <elseif openid="" op-callback="">
	<openid-verify-response />
	<then>
	  <redirect to="&page.self;" />
	</then>
	<else>
	  Verification failed!
	</else>
      </elseif>
    </if>
    <else>
      <p><a href="&page.self;?__logout=1">Log out</a></p>
      <emit source="openid">
	<emit source="values" from-scope="_" sort="index">
	  &_.index;: &_.value;<br/>
	</emit>
      </emit>
    </else>
  </xsl:template>
</xsl:stylesheet>