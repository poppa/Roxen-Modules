<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template name="mima-project-form"><!-- {{{ -->
    <xsl:param name="action" />
    <vform action="&mima.self;">
      <fieldset class="hidden">
	<input type="hidden" name="action" value="{$action}" />
	<label>
	  <span>Name</span>
	  <mima-input type="string" name="name" minlength="4">
	    The project name needs to be at least four characters long
	  </mima-input>
	</label>
	<br/>
	<label>
	  <span>Description</span>
	  <mima-input type="text" name="description" minlength="10">
	    The project description must be at least ten characters long
	  </mima-input>
	</label>
	<br/>
	<if not="" variable="form.send">
	  <set variable="form.add-self" value="on" />
	</if>
	<default value="&form.add-self;">
	  <label class='inline-group'>
	    <input type="checkbox" name="add-self" />
	    <span>Add your self as member of the project</span>
	  </label>
	  <div class="clear"><xsl:text> </xsl:text></div>
	</default>
	<br/>
	<input type="submit" name="send" value="Create project" />
	<xsl:text> </xsl:text>
	<mima-cancel />
      </fieldset>
    </vform>
    <then>
      <mima-admin-project-create
        name="&form.name;"
	description="&form.description;"
	identifier="&mima.identifier;"
	add-current-user="&form.add-self;"
      />
      <then>Coolio</then>
      <else>
	<safe-js>
	  Form.Error.Append('mima-input-0', '&mima.error:html;');
	</safe-js>
      </else>
    </then>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="mima-project-create"><!-- {{{ -->
    <mima-title value="Create project" />
    <h2 class="no-top-margin">Create a new project</h2>
    <xsl:call-template name="mima-project-form">
      <xsl:with-param name="action" select="'new'" />
    </xsl:call-template>
  </xsl:template><!-- }}} -->

  <xsl:template name="mima-admin-project-list"><!-- {{{ -->
    <emit source="mima-project" identifier="&mima.identifier;">
      <p><strong>&_.name;</strong><br/>&_.description;</p>
    </emit>
  </xsl:template><!-- }}} -->
  
</xsl:stylesheet>
