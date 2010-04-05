<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:param name="blog-root" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="Path to the specific blog"
  />

  <xsl:param name="blog-title" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="The title of the blog"
  />

  <xsl:param name="blog-base" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="Base path to blog group - that is the directory containing one or more blogs"
  />

  <xsl:param name="blog-default-allow-comments" select="1"
             rxml:type="checkbox"
	     rxml:group="TVAB Blog"
	     rxml:doc="Allow comments per default"
  />

  <xsl:param name="blog-category-file" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="Path to the blog's category file"
  />

  <xsl:param name="blog-category-path" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="Path to the blog's category page"
  />

  <xsl:param name="blog-tags-path" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="Path to the blog's tag page"
  />

  <xsl:param name="blog-view-per-page" select="10"
             rxml:type="int"
	     rxml:group="TVAB Blog"
	     rxml:doc="Default number of entries to display on archive pages"
  />

  <xsl:param name="blog-comment-mail-receiver" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="Comma separated list of email addresses that should
	               receive notifications when new comments arrive"
  />

  <xsl:param name="blog-description" select="''"
             rxml:type="text"
	     rxml:group="TVAB Blog"
	     rxml:doc="Description of the blog"
  />

  <xsl:param name="blog-date-lang" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="Language to use in all date tags (i.e. 'sv' or 'en')"
  />

  <xsl:param name="blog-full-excerpts" select="0"
             rxml:type="checkbox"
	     rxml:group="TVAB Blog"
	     rxml:doc="Show full article on archive pages"
  />

  <xsl:param name="blog-authors" select="''"
             rxml:type="string"
	     rxml:group="TVAB Blog"
	     rxml:doc="Comma separated list of blog authors and their emails (username1:email,username2:email)"
  />

</xsl:stylesheet>
