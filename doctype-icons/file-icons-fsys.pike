/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.
*/

#include <config.h>
#include <module.h>
#include <stat.h>
inherit "module";

#define _ok RXML_CONTEXT->misc[" _ok"]

// #define FSI_DEBUG

#ifdef FSI_DEBUG
# define TRACE(X...) report_debug(X)
#else
# define TRACE(X...)
#endif

constant thread_safe = 1;
constant module_type = MODULE_LOCATION;
constant module_name = "Poppa Tags: File icon file system";
constant module_doc  = "";

Configuration conf;
private  string    mountpoint, localpath;
private  int(0..1) disabled = 0;
private  mapping   last_file;
constant           dir_stat = ({ 0777|S_IFDIR, -1, 10, 10, 10, 0, 0 });

void create(Configuration _conf)
{
  conf = _conf;
  set_module_creator("Pontus Östlund <poppanator@gmail.com>");

  defvar("location",
    Variable.Location(
      "/__internal/types/", VAR_INITIAL|VAR_NO_DEFAULT, "Mount point",
      "Where the module will be mounted in the site's virtual file system."
    )
  );
}

void start(int when, Configuration _conf)
{
  mountpoint = query("location");
  localpath = dirname(__FILE__);
}

string preslash(string p)
{
  if (p[0] != '/') p = "/" + p;
  return p;
}

string postslash(string p)
{
  if (p[-1] != '/') p += "/";
  return p;
}

string unpostslash(string p)
{
  if (p[-1] == '/') p = p[0..sizeof(p)-2];
  return p;
}

string unpreslash(string p)
{
  if (p[0] == '/') p = p[1..];
  return p;
}

// =============================================================================
//
//                           LOCATION_MODULE API
//
// =============================================================================

static array low_stat_file(string f, RequestID id)
{
  if (f == "/")  return dir_stat;

  if (has_value(f, "%"))
    return 0;

  string realfile = unpostslash(localpath) + f;

  if (!last_file || last_file->path != f) {
    if (Stdio.exist(realfile) && Stdio.is_file(realfile)) {
      Stdio.Stat fs = file_stat(realfile);
      last_file           = ([]);
      last_file->path     = f;
      last_file->mtime    = fs->mtime;
      //last_file->contents = Stdio.read_file(realfile);
      last_file->uid      = fs->uid;
      last_file->gid      = fs->gid;
      last_file->size     = Stdio.file_size(realfile);
    }
    else last_file = 0;
  }

  if (last_file && last_file->path == f) {
    return ({
      ({
        0777,
        last_file->size,
        time(),
        last_file->mtime + 1,
        last_file->mtime + 1,
        last_file->uid,
        last_file->gid,
      }),
      last_file
    });
  }

  if (Stdio.is_dir(realfile))
    return ({ dir_stat, 0 });

  return ({ 0, 0 });
}

Stat stat_file(string f, RequestID id)
{
  array s = low_stat_file(preslash(f), id);
  return s && s[0];
}

int|object|mapping find_file(string f, RequestID id)
{
  CACHE(0);
  f = get_image(replace(f, ".gif", ".png"));

  if(!f || !strlen(f))
    return -1;

  [array st, mapping d] = low_stat_file(preslash(f), id);

  if(!st)         return 0;
  if(st[1] == -1) return -1;
  id->misc->stat = st;

  string realfile = unpostslash(localpath) + d->path;

  Stdio.File fh;

  if (mixed e = catch(fh = Stdio.File(realfile, "r"))) {
    TRACE("Error opening file \"%s\"", realfile);
    report_error("%s", describe_backtrace(e));
    return -1;
  }

  return Roxen.http_file_answer(fh, "image/png");
}

string get_image(string file)
{
  TRACE("Get: %O\n",  file);
  if (Stdio.exist(combine_path(localpath, file)))
    return file;

  return 0;
}