<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:import href="ancestor-or-self::assets/mima.xsl" />

  <xsl:output method="xml" media-type="text/html" indent="no" omit-xml-declaration="yes" />

  <xsl:template match="/"><trim>
    <mima template-file="assets/mima-content-compiler.xsl"
	  rxml-file="assets/mima.xml"
	  svn-repository-uri="{$mima-repository-uri}"
	  identifier="&page.path;" 
    />
  </trim></xsl:template>
</xsl:stylesheet>
