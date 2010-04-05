<?xml version='1.0' encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template name="mima-new-ticket"><!-- {{{ -->
    <mima-title value="Create a new ticket" />
    <h2>Create a new ticket</h2>
    <if variable="form.ok = 1">
      <notify>
	<p>Thank you for your report</p>
      </notify>
    </if>

    <vform action="&mima.self;" id="ticket-form">
      <xsl:call-template name="mima-ticket-property-form" />
      <br/>
      <input type="submit" name="send" value="Submit ticket" />
      <xsl:text> </xsl:text>
      <mima-cancel/>
    </vform>
    <then>
      <mima-add-ticket summary="&form.summary;" reporter="&form.reporter;"
                       text="&form.text;"
                       project-id="&form.project-id;" owner="&form.owner;"
                       type="&form.type;"
                       priority="&form.priority;"
      />
      <then>
	<redirect to="&mima.self;?ok=1" />
      </then>
    </then>
  </xsl:template><!-- }}} -->

  <xsl:template name="mima-ticket-property-form"><!-- {{{ -->
    <xsl:param name="update" select="false()" />
    <xsl:param name="legend" select="true()" />

    <fieldset class="rows">
      <xsl:if test="$legend = true()">
	<legend>Properties</legend>
      </xsl:if>
      <label>
	<span><strong>Summary</strong><xsl:text> </xsl:text><small class="help">Here you write a short summary of the issue</small></span>
	<mima-input name="summary" type="string" maxlength="255" value="&mima.summary;" minlength="8">
	  Please write a summary of the issue.
	</mima-input>
      </label>

      <br/>

      <label>
	<span><strong>Reporter</strong></span>
	<if variable="mima.username">
	  <set variable="var.reporter" value="&mima.username;" />
	</if>
	<else>
	  <set variable="var.reporter" value="&user.username;" />
	</else>
	<mima-input type="string" name="reporter" minlength="2" value="&var.reporter;">
	  Please fill in the Reporter field.
	</mima-input>
      </label>

      <br/>

      <xsl:if test="$update = false()">
	  <label style="float:left">
	    <span><strong>Description</strong><xsl:text> </xsl:text><small class="help">Here you explain the issue in depth</small></span>
	  </label>
	  <div style="float:left; width: 430px">
	    <mima-input type="text" name="text" class="editor" minlength="10">
	      Please give a description of the issue.
	    </mima-input>
	  </div>
	  <div class="clear"><xsl:text> </xsl:text></div>
	  <br/>
	<br/>
      </xsl:if>

      <xsl:if test="$update = true()">
	<if ppoint="mima-admin" write="">
	  <label style="float:left">
	    <span><strong>Description</strong><xsl:text> </xsl:text><small class="help">Here you explain the issue in depth</small></span>
	  </label>
	  <div style="float:left; width: 430px">
	    <mima-input type="text" name="text" class="editor" value="&mima.text;" minlength="10">
	      Please give a description of the issue.
	    </mima-input>
	  </div>
	  <div class="clear"><xsl:text> </xsl:text></div>
	  <br/>
	</if>
      </xsl:if>

      <label class="side-by-side">
	<span>Connect to project</span>
	<if variable="form.project-id">
	  <set variable="mima.project_id" value="&form.project-id;" />
	</if>
	<default name="project-id" value="&mima.project_id;">
	  <select name="project-id">
	    <optgroup label="Select a project ...">
	      <option value="0">None</option>
	      <emit source="mima-project" identifier="&mima.identifier;">
		<option value="&_.id;">&_.name;</option>
	      </emit>
	    </optgroup>
	  </select>
	</default>
      </label>

      <label class="side-by-side">
	<span>Assign to user</span>
	<if variable="form.owner">
	  <set variable="mima.owner" value="&form.owner;" />
	</if>
	<default name="owner" value="&mima.owner;">
	  <select name="owner">
	    <optgroup label="Select user ...">
	      <option value="0">Any</option>
	      <emit source="mima-user">
		<option class="real-value" value="&_.username;">&_.fullname;</option>
	      </emit>
	    </optgroup>
	  </select>
	</default>
      </label>

      <br class="clear"/>

      <label class="side-by-side">
	<span>Type</span>
	<mima-field-select name="type" group="ticket-type" check="&mima.type_id;" />
      </label>

      <label class="side-by-side">
	<span>Priority</span>
	<mima-field-select name="priority" group="ticket-priority" check="&mima.priority_id;"/>
      </label>
      
      <br/>
    </fieldset>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="mima-ticket-action-form"><!-- {{{ -->
    <fieldset>
      <legend>Actions</legend>
      <if not="" variable="form.action">
	<if variable="_.resolution_id = 0">
	  <if variable="_.accepted = y">
	    <set variable="form.action" value="1" />
	  </if>
	  <else>
	    <set variable="form.action" value="0" />
	  </else>
	  <set variable="form.resolution" value="0" />
	</if>
	<else>
	  <set variable="form.action" value="1" />
	</else>
      </if>

      <if variable="_.owner = &user.username;" and="" 
          Variable="_.accepted = y">
	<set variable="var.accept-args" value="disabled='disabled'" />
      </if>

      <set variable="var.trs" value="'#trs'" />
      <set variable="var.tow" value="'#tow'" />
      
      <default value="&form.action;">
        <table cellspacing="0" cellpadding="0" class="simple">
	  <tr>
	    <td style="width:5px">
	      <input type="radio" name="action" value="0" id="a1"
	             onchange="Form.ChecboxToggle(null, [&var.trs:none;])" 
	      />
	    </td>
	    <td><label for="a1">Leave as new</label></td>
	  </tr>
	  <tr>
	    <td>
	      <input type="radio" name="action" value="1" id="a2"
	             onchange="Form.ChecboxToggle([&var.trs:none;])" 
	      />
	    </td>
	    <td style="width:80px"><label for="a2">Resolve as</label></td>
	    <td>
	      <if variable="form.action = 1">
		<mima-field-select name="resolution" id="trs"
		                   group="ticket-resolution"
		                   check="&mima.resolution_id;"
		                   style="width:150px;padding:0" />
	      </if>
	      <else>
		<mima-field-select name="resolution" id="trs"
		                   group="ticket-resolution"
		                   check="&mima.resolution_id;"
		      style="width:150px;padding:0" disabled="disabled"/>
	      </else>
	    </td>
	  </tr>
	  <tr>
	    <td><input type="radio" name="action" value="2" id="a4"
	               ::="&var.accept-args;"
	         onchange="Form.ChecboxToggle(null, [&var.trs:none;])" />
	    </td>
	    <td><label for="a4">Accept</label></td>
	  </tr>
        </table>
      </default>
    </fieldset>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="mima-view-ticket"><!-- {{{ -->
    <if variable="form.ok">
      <notify ok=""><p>The ticket was updated</p></notify>
    </if>
    <vform action="&mima.self;">
      <emit source="mima-ticket" identifier="&mima.identifier;" id="{id}">
	<copy-scope from="_" to="mima" />
	<mima-title value="Ticket: &_.summary:html;"/>
	<div class="common-content-wrapper">
	  <div class="ticket-ticket">
	    <div class="ticket-header">
	      <h2>&_.summary;</h2>
	      <div class="dates">
		<span>Opened <date type="string" iso-time="&_.date_created;" /></span><br/>
		<if variable="_.date_edited = 0">
		  <span>Never modified</span>
		</if>
		<else>
		  <span>Last modified <date type="string" iso-time="&_.date_edited;" /></span>
		</else>
	      </div>
	      <div class="clear"><xsl:text> </xsl:text></div>
	    </div>
	    <div class="ticket-description">
	      <div class="left">
		<dl class="columns">
		  <dt>Project:</dt>
		  <dd>
		    <if variable="_.project_id = 0">Any</if>
		    <else>&_.project_name;</else>
		  </dd>
		</dl>
		<dl class="columns">
		  <dt>Reporter:</dt>
		  <dd>&_.reporter;</dd>
		</dl>
		<dl class="columns">
		  <dt>Priority:</dt>
		  <dd><mima-field-value id="&_.priority_id;"/></dd>
		</dl>
	      </div>
	      <div class="right">
		<dl class="columns">
		  <dt>Owner:</dt>
		  <dd>
		    <if variable="_.owner = 0">Unassigned</if>
		    <else>&_.owner;</else>
		  </dd>
		</dl>
		<dl class="columns">
		  <dt>Type:</dt>
		  <dd><mima-field-value id="&_.type_id;" /></dd>
		</dl>
		<dl class="columns">
		  <dt>Status:</dt>
		  <dd>
		    <mima-field-value id="&_.resolution_id;" />
		    <else>
		      <if variable="_.accepted = n">New</if>
		      <else>Accepted</else>
		    </else>
		  </dd>
		</dl>
	      </div>
	      <div class="clear"><xsl:text> </xsl:text></div>
	      <div class="divider"><xsl:text> </xsl:text></div>
	      <p><strong>Description:</strong></p>
	      <wiki-text>&_.text:none;</wiki-text>
	    </div>
	  </div>
	  <if ppoint="mima-admin" write="">
	    <div id="ticket-properties">
	      <xsl:call-template name="mima-ticket-property-form">
		<xsl:with-param name="update" select="true()" />
	      </xsl:call-template>
	    </div>
	    <div id="ticket-actions">
	      <xsl:call-template name="mima-ticket-action-form" />
	    </div>
	    <br/>
	    <input type="submit" name="send" value="Submit changes" />
	  </if>
	  <!--
	  <input type="submit" name="preview" value="Preview changes" />
	  <xsl:text> </xsl:text>
	  -->
	</div>
      </emit>
      <else>
	<notify>
	  <p>There's no ticket with id <strong><em><xsl:value-of select="id" /></em></strong></p>
	</notify>
      </else>
    </vform>
    <then>
      <unset variable="form.__state" />
      <unset variable="form.__sb_edit_area" />
      <unset variable="form.send" />
      <if variable="form.action = 2">
	<set variable="form.accepted" value="y" />
      </if>
      <unset variable="form.action" />
      <set variable="var.args" value=""/>
      <emit source="values" from-scope="form">
	<append variable="var.args" value=' &_.index;="&_.value:html;"' />
      </emit>
      <mima-update-ticket id="{id}" ::="&var.args;" />
      <then>
	<!--<redirect to="&mima.self;?ok=1" />-->
	<safe-js>document.location.replace('&mima.self;?ok=1');</safe-js>
      </then>
      <else>
	<notify><p>Failed to update ticket!</p></notify>
      </else>
    </then>
  </xsl:template><!-- }}} -->
  
  <xsl:template name="mima-tickets"><!-- {{{ -->
    <emit source="mima-ticket" identifier="&mima.identifier;">
      <if variable="_.counter = 1">
	<ttag name="table" cellspacing="0" cellpadding="0" />
	<thead>
	  <tr>
	    <th>Ticket</th>
	    <th>Summary</th>
	    <th>Project</th>
	    <th>Type</th>
	    <th>Owner</th>
	    <th>Status</th>
	    <th class="last">Created</th>
	  </tr>
	</thead>
	<tag name="tbody"/>
      </if>
      <tr>
	<td><a href="&mima.self;/view/&_.id;">&_.id;</a></td>
	<td><a href="&mima.self;/view/&_.id;">&_.summary;</a></td>
	<td>
	  <if variable="_.project_name != 0">&_.project_name;</if>
	  <else>Any</else>
	</td>
	<td><mima-field-value id="&_.type_id;" /></td>
	<td>
	  <if variable="_.owner = 0">Unassigned</if>
	  <else>&_.owner;</else>
	</td>
	<td>
	  <mima-field-value id="&_.resolution_id;" />
	  <else>
	    <if variable="_.accepted = n">New</if>
	    <else>Accepted</else>
	  </else>
	</td>
	<td class="last">
	  <date iso-time="&_.date_created;" strftime="%Y-%m-%d %R" />
	</td>
      </tr>
    </emit>
    <then>
      <ttag name="tbody" close="" />
      <ttag name="table" close="" />
    </then>
    <else>
      <notify>
	<p>No tickets yet!</p>
      </notify>
    </else>
  </xsl:template><!-- }}} -->
  
</xsl:stylesheet>
