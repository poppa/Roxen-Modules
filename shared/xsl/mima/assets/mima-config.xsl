<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="mima-root" select="''"
             rxml:group="Mima: Paths"
             rxml:doc="The virutal path to the root of Mima"
             rxml:type="string" />

  <xsl:param name="mima-repository-uri" select="''"
             rxml:group="Mima: Paths"
             rxml:doc="The path to the Subverison repository to mirror"
             rxml:type="string" />

  <xsl:param name="mima-anon-user" select="'Anonymous'"
             rxml:group="Mima: Misc"
             rxml:doc="Name of non-authenticated user"
             rxml:type="string" />

</xsl:stylesheet>
