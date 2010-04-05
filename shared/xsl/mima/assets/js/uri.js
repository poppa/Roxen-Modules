/*! $Id: uri.js,v 1.3 2010/02/02 20:43:30 pontus Exp $ 
 *!
 *! URI class
 *! This is class for parsing, creating and manupulating a URI
 *!
 *! Copyright © 2009, Pontus Östlund <spam@poppa.se>
 *!
 *! License GNU GPL version 3
 *!
 *! URI.js is free software: you can redistribute it and/or modify
 *! it under the terms of the GNU General Public License as published by
 *! the Free Software Foundation, either version 3 of the License, or
 *! (at your option) any later version.
 *!
 *! URI.js is distributed in the hope that it will be useful,
 *! but WITHOUT ANY WARRANTY; without even the implied warranty of
 *! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *! GNU General Public License for more details.
 *!
 *! You should have received a copy of the GNU General Public License
 *! along with URI.js. If not, see <@url{http://www.gnu.org/licenses/@}>.
 *!
 *! ----------------------------------------------------------------------------
 *!
 *! Example of usage
 *!
 *! var uri = new URI("http://mydomain.com/some/path/");
 *!
 *! console.log(uri.scheme);     //> http
 *! console.log(uri.port);       //> 80
 *! console.log(uri.host);       //> mydomain.com
 *! console.log(uri.path);       //> /some/path/
 *! console.log(uri.toString()); //> http://mydomain.com/some/path/
 *!
 *! // Alter the domain
 *! uri.domain = "my.otherdomain.com";
 *! console.log(uri.toString()); //> http://my.otherdomain.com/some/path/
 *!
 *! uri.variables['articleID'] = 135;
 *! uri.variables['action'] = 'read';
 *! console.log(uri.toString());
 *! //> http://my.otherdomain.com/some/path/?articleID=135&action=read
 *!
 *! 
 *! NOTE! Don't use the "query" member directly if you intend to alter the 
 *! querystring. Use the member object "variables" and call the "queryString()"
 *! method if you want to access the altered querystring.
 */
var URI = function(uri)
{
  this.uri       = uri;  // private
  this.scheme    = null;
  this.host      = null;
  this.username  = null;
  this.password  = null;
  this.port      = 0;
  this.path      = null;
  this.query     = null; // private
  this.fragment  = null;
  this.variables = {};

  // Standard ports
  this.ports = {
    'ftp'    : 21,
    'ssh'    : 22,
    'telnet' : 23,
    'smtp'   : 25,
    'http'   : 80,
    'https'  : 443
  };

  var re = new RegExp("(?:([-+a-z0-9]+)://" + // Scheme
		      "((.[^:]*):?(.*)?@)?" + // Userinfo
		      "(.[^:/]*)"           + // Host
		      ":?([0-9]{1,6})?)?"   + // Port
		      "(/.[^?#]*)?"         + // Path
		      "[?]?(.[^#]*)?"       + // Query
		      "#?(.*)?", "i");        // Fragment
  var m;
  if (this.uri && (m = re.exec(this.uri))) {
    this.scheme   = m[1] && m[1].toLowerCase();
    this.username = m[3];
    this.password = m[4];
    this.host     = m[5] && m[5].toLowerCase();
    this.port     = m[6] && parseInt(m[6]) || 0;
    this.path     = m[7] || "/";
    this.query    = m[8];
    this.fragment = m[9];

    if (this.port == 0 && this.scheme)
      this.port = this.ports[this.scheme];

    if (this.query && this.query.length) {
      var q = this.query.split('&');
      for (var i = 0; i < q.length; i++) {
	var p = q[i].split('=');
	this.variables[decodeURIComponent(p[0])] = p.length > 1 ?
	                                           decodeURIComponent(p[1]) :
	                                           null;
      }
    }
  }
};

URI.prototype =
{
  queryString: function() {
    var tmp = [];
    for (var name in this.variables) {
      if (this.variables[name] != null) {
	tmp.push(encodeURIComponent(name) + "=" +
	         encodeURIComponent(this.variables[name]));
      }
    }
    return tmp.length && tmp.join("&") || null;
  },

  toString: function()
  {
    var s = "", q = null;
    if (this.scheme)                    s  = this.scheme + "://";
    if (this.username)                  s += this.username;
    if (this.username && this.password) s += ":";
    if (this.password)                  s += this.password;
    if (this.username)                  s += "@";
    if (this.host)                      s += this.host;
    if (!this.isDefaultPort())          s += ":" + this.port;
    if (this.path)                      s += this.path;
    if (q = this.queryString())         s += "?" + q;
    if (this.fragment)                  s += "#" + this.fragment;

    return s;
  },

  // Private
  isDefaultPort: function()
  {
    if (!this.port) return true;
    for (var scheme in this.ports) {
      if (scheme == this.scheme && this.port != this.ports[scheme])
	return false;
    }

    return true;
  }
};