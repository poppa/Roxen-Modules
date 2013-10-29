/*
  Author: Pontus Östlund <https://profiles.google.com/poppanator>

  Permission to copy, modify, and distribute this source for any legal
  purpose granted as long as my name is still attached to it. More
  specifically, the GPL, LGPL and MPL licenses apply to this software.

  JavaScript and CSS minifier filter module. This filter removes redundant
  whitespace and comments from JavaScript and CSS files.
*/

#charset utf-8
#include <config.h>
#include <module.h>
inherit "module";

//#define JSMIN_DEBUG

#ifdef JSMIN_DEBUG
# define TRACE(X...) \
  report_debug("%s:%d: %s", basename(__FILE__), __LINE__, sprintf(X))
#else
# define TRACE(X...) 0
#endif

constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "Poppa Tags: JSMin/CSSMin";
constant module_doc  = "JavaScript and CSS minifier filter";

private array(string) paths;
private string qsv;

void create(Configuration conf)
{
  set_module_creator("Pontus Östlund, &lt;spam@poppa.se&gt;.");

  defvar("allow_paths",
         Variable.StringList(({}), VAR_INITIAL,
         "Allowed paths",
         "Paths in which files will be minified. This can either "
         "be a directory glob or a full path to a file."));

  defvar("query_string_variable",
         Variable.String("minify", VAR_INITIAL,
         "Query string variable",
         "If this query string variable exists in the request the file "
         "will be minified"));
}

void start(int whence, Configuration conf)
{
  paths = query("allow_paths");
  qsv = query("query_string_variable");
}

int(0..1) is_allowed(string path)
{
  foreach (paths, string allowed)
    if (glob(allowed, path))
      return 1;

  return 0;
}

mapping|void filter(mapping result, RequestID id)
{
  if (result && result->type && result->type == "application/x-javascript") {
    if ((qsv && id->variables[qsv]) || is_allowed(id->not_query)) {

      object jsmin = id->variables[qsv] == "2" ? JSmin2() : JSMin();

      TRACE("Minify: %s with %O\n", id->not_query, jsmin);

      if (mixed e = catch(result->data = jsmin->minify(result->data))) {
        report_error("Failed minifying %s: %s\n",
                     id->not_query, describe_backtrace(e));
      }

      return result;
    }
  }
  else if (result && result->type && result->type == "text/css") {
    if ((qsv && id->variables[qsv]) || is_allowed(id->not_query)) {
      TRACE("Minify: %s\n", id->not_query);
      result->data = CSSMin()->minify(result->data);
      return result;
    }
  }
}

//| Using the jsmin algorithm originally by Douglas Crockford
//|
//| Copyright © 2002 Douglas Crockford  (www.crockford.com)
//| Copyright © 2010 Pontus Östlund (http://www.poppa.se)
//|
//| Permission is hereby granted, free of charge, to any person obtaining a copy
//| of this software and associated documentation files (the "Software"), to
//| deal in the Software without restriction, including without limitation the
//| rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//| sell copies of the Software, and to permit persons to whom the Software is
//| furnished to do so, subject to the following conditions:
//|
//| The above copyright notice and this permission notice shall be included in
//| all copies or substantial portions of the Software.
//|
//| The Software shall be used for Good, not Evil.
//|
//| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//| IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//| FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//| AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//| LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//| FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//| IN THE SOFTWARE.
class JSMin // {{{
{
  constant EOF = '\0';

  private int a;
  private int b;
  private int lookahead = EOF;
  private Stdio.FakeFile input;
  private String.Buffer output;

#define add(C) output->add(sprintf("%c", (C)))

  void create()
  {
  }

  string minify(Stdio.File|string data)
  {
    input = stringp(data) ? Stdio.FakeFile(data) : data;
    output = String.Buffer();

    jsmin();

    // Remove the first newline added
    return output->get()[1..];
  }

  private int get()
  {
    int c = lookahead;
    lookahead = EOF;

    c == EOF && sscanf(input->read(1), "%c", c);

    if (c >= ' ' || c == '\n' || c == EOF)
      return c;

    return c == '\r' && '\n' || ' ';
  }

#define peek() (lookahead = get())

  private int next()
  {
    int c = get();
    if (c == '/') {
      switch (peek())
      {
        case '/':
          while (c = get())
            if (c <= '\n')
              return c;
          break;

        case '*':
          get();
          while (1) {
            switch (get())
            {
              case '*':
                if (peek() == '/') {
                  get();
                  return ' ';
                }
                break;

              case EOF:
                error("Unterminated string literal! ");
            }
          }
          break;

        default:
          return c;
      }
    }

    return c;
  }

#define action(d)                                                          \
  do {                                                                     \
    switch ((int)d)                                                        \
    {                                                                      \
      case 1:                                                              \
        add(a);                                                            \
      case 2:                                                              \
        a = b;                                                             \
        if (a == '"' || a == '\'') {                                       \
          while (1) {                                                      \
            add(a);                                                        \
            a = get();                                                     \
            if (a == b)                                                    \
              break;                                                       \
            if (a == '\\') {                                               \
              add(a);                                                      \
              a = get();                                                   \
            }                                                              \
            if (a == EOF)                                                  \
              error("Unterminated string literal! ");                      \
          }                                                                \
        }                                                                  \
      case 3:                                                              \
        b = next();                                                        \
        if (b == '/' &&                                                    \
           (< '(',',','=',':','[','!','&','|','?','{','}',';','\n' >)[a] ) \
        {                                                                  \
          add(a);                                                          \
          add(b);                                                          \
          while (1) {                                                      \
            a = get();                                                     \
            if (a == '/')                                                  \
              break;                                                       \
            if (a == '\\') {                                               \
              add(a);                                                      \
              a = get();                                                   \
            }                                                              \
            if (a == EOF)                                                  \
              error("Unterminated regular expression literal");            \
            add(a);                                                        \
          }                                                                \
          b = next();                                                      \
        }                                                                  \
        break;                                                             \
    }                                                                      \
  } while(0)

#define is_alnum(c) ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || \
                     (c >= 'A' && c <= 'Z') || c == '_' || c == '$' ||   \
                      c == '\\' || c > 126)

  private void jsmin()
  {
    a = '\n';
    action(3);
    while (a != EOF) {
      switch (a)
      {
        case ' ':
          if (is_alnum(b))
            action(1);
          else
            action(2);
          break;

        case '\n':
          switch (b)
          {
            case '{':
            case '[':
            case '(':
            case '+':
            case '-':
              action(1);
              break;
            case ' ':
              action(3);
              break;

            default:
              if (is_alnum(b))
                action(1);
              else
                action(2);
          }
          break;

        default:
          switch (b)
          {
            case ' ':
              if (is_alnum(a)) {
                action(1);
                break;
              }
              action(3);
              break;

            case '\n':
              switch (a)
              {
                case '}':
                case ']':
                case ')':
                case '+':
                case '-':
                case '\'':
                case '"':
                  action(1);
                  break;
                default:
                  if (is_alnum(a))
                    action(1);
                  else
                    action(3);
              }
              break;

            default:
              action(1);
          }
      }
    }
  }
} // }}}

#undef add
#undef peek
#undef is_alnum
#undef action

class CSSMin // {{{
{
  constant DELIMITERS = (< ';',',',':','{','}','(',')' >);
  constant WHITES = (< ' ','\t','\n' >);
  constant WHITES_DELIMS = DELIMITERS + WHITES;

  string minify(string css)
  {
#define next css[i+1]
#define prev css[i-1]
#define curr css[i]

    int len = sizeof(css);
    css += "\0";
    String.Buffer buf = String.Buffer();
    function add = buf->add;
    int(0..1) in_import = 0, in_media = 0;

    outer: for (int i; i < len; i++) {
      int c = css[i];
      switch (c)
      {
        case '@':
          if (next == 'i') {
            in_import = 1;
            add (" ");
          }
          else if (next == 'm') {
            in_media = 1;
            add (" ");
          }
          break;

        case '(':
          if (in_media) {
            add(" (");
            in_media = 0;
            continue outer;
          }

        case ';':
          if (in_import) {
            add(css[i..i], "\n");
            in_import = 0;
            continue outer;
          }
          break;

        case '\r':
        case '\n':
          in_media = 0;
          in_import = 0;
          continue outer;

        case ' ':
        case '\t':
          if (WHITES_DELIMS[prev] || WHITES_DELIMS[next])
            continue outer;
          break;

        case '/':
          if (next == '*') {
            i++;

            int (0..1) keep = 0;
            if (next == '!') {
              keep = 1;
              add ("/*");
            }

            while (i++ < len) {
              if (keep) add (css[i..i]);
              if (curr == '*' && next == '/') {
                if (keep) add ("/\n");
                i++;
                continue outer;
              }
            }
          }
          break;

        case ')': // This is needed for Internet Explorer
          if (!DELIMITERS[next]) {
            add(") ");
            continue outer;
          }
          break;

        case '}':
          add(css[i..i], "");
          continue outer;
      }
      add(css[i..i]);
    }

    return String.trim_all_whites(buf->get());
  }
} // }}}

#undef next
#undef curr
#undef prev


#ifdef DEBUG
# define DO_IF_DEBUG(X) X
#else
# define DO_IF_DEBUG(X) 0
#endif

// Next character
#define next data[i+1]

// Current character
#define curr data[i]

// Current character as a string
#define scurr data[i..i]

// Previous character
#define prev data[i-1]

// Throws an error if (pos = search(..)) == -1
#define perr(MESS, ARGS...) if (pos == -1) { error (MESS, ARGS); }

// Checks if character A is a delimiter
#define is_delimiter(A) delims[A]

// Checks if character A is a whitespace
#define is_whitespace(A) ws[A]

// Eats unwanted whitespace
#define eat_whitespace() do {                             \
  int pp = data[i];                                       \
  while (ws[data[++i]] && i < len)                        \
    ; /* do nothing */                                    \
  i -= 1;                                                 \
  if (!delims[pp] && !delims[data[i+1]] && !ws[data[i]])  \
    add (" ");                                            \
} while (0)

// Checks if we're at a block comment
#define is_block_comment() (curr == '/' && next == '*')

// Checks if we're at a line comment
#define is_line_comment() (curr == '/' && next == '/')

// Checks if what comes next is a line or block comment
#define next_is_comment() (next == '/' && (data[i+2] == '*' || data[i+2]=='/'))

// Checks if what comes next is a block comment
#define next_is_block_comment() (next == '/' && data[i+2] == '*')

// Checks if what comes next is a line comment
#define next_is_line_comment() (next == '/' && data[i+2] == '/')

// Eats a block comment
#define eat_block_comment() do {                                          \
  i++;                                                                    \
  int pos = search (data, "*/", i);                                       \
  perr ("Unclosed block comment at position %d\n", i);                    \
  string chunk = data[i..pos+1];                                          \
  if (next == '!') {                                                      \
    if (i > 1) add ("\n");                                                \
    add ("/" + chunk + "\n");                                             \
  }                                                                       \
  i = pos+1;                                                              \
  eat_whitespace ();                                                      \
} while (0)

// Eats a line comment
#define eat_line_comment() do {                                           \
  int pos = search (data, "\n", i+1);                                     \
  if (pos == -1) {                                                        \
    i = len;                                                              \
    break; /* End of file */                                              \
  }                                                                       \
  i = pos;                                                                \
  eat_whitespace ();                                                      \
} while (0)

class JSmin2
{
  protected multiset delims = (< '.', '|', '&', ':', '!', '=', '>', '<', '~',
                                 ';', ',', '{', '}', '[', ']', '(', ')', '+',
                                 '-','*','/','%','?' >);
  protected multiset ws = (< '\n', '\r', '\t', ' ' >);

  string minify (string data)
  {
    data                  = String.trim_all_whites (data);
    String.Buffer out     = String.Buffer ();
    function add          = out->add;
    int len               = sizeof (data);
    int i                 = -1;
    int(0..1) in_function = 0;
    int prev_char         = 0;
    int re_end            = 0;
    ADT.Stack func_stack  = ADT.Stack ();

    data += "\0\0";

    function(void:int(0..1)) is_regex = lambda ()
    {
      int j = i;

      while (++j < len) {
        if (data[j] == '\n') {
          DO_IF_DEBUG (werror ("Not a Regexp\n"));
          return 0;
        }
        else if (data[j] == '/') {
          int k = j, cn = 0;

          // Count escapes.
          while (--k > 0 && data[k] == '\\')
            cn++;

          // If there was an even number of escapes it wasn't the / slash
          // that was escaped so we're at the end of a regexp
          if (cn % 2 == 0) {
            DO_IF_DEBUG (werror ("It's a Regexp\n"));
            return j;
          }
        }
      }

      return 0;
    };

    while (++i < len) {
      // Block comment
      if (is_block_comment ()) {
        eat_block_comment ();
        continue;
      }
      // Line comment
      else if (is_line_comment ()) {
        eat_line_comment();
        continue;
      }
      // Maybe Regexp
      else if (curr == '/' && ((re_end = is_regex ()) > 0)) {
        int start = i;
        add (data[start..re_end]);
        i = re_end;
      }
      // Strings
      else if (curr == '"' || curr == '\'') {
        int pos, char = curr, start = i;
        i++;

        while (1) {
          pos = search (data, char, i);

          perr ("Unclosed string literal at position %d. "
                "Context: %s\n", i, out->get ());

          i = pos;

          if (data[pos-1] != '\\')
            break;

          i++;
        }

        add (data[start..pos]);

        i = pos;
      }
      // Closing bracet in in_function mode
      else if (curr == '}' && in_function) {
        func_stack->top()->level--;

        eat_whitespace ();
        add ("}");
        prev_char = '}';

        if (func_stack->top()->level == 0) {
          // Eat comments to see what real char comes after the }
          while (next_is_comment()) {
            if (next_is_line_comment ())
              eat_line_comment ();
            if (next_is_block_comment ()) {
              i++;
              eat_block_comment ();
            }
          }

          // A function declared like:
          //
          // var fun = function() {
          // }
          //
          // without a terminating ;
          // Lets add one...
          if (!is_delimiter (next)) {
            add (";");
            prev_char = ';';
          }

          func_stack->pop();

          // Empty stack
          if (func_stack->ptr == 0)
            in_function = 0;
        }
      }
      // Whitespace
      else if (is_whitespace (curr)) {
        int char = curr, next_ws = is_whitespace (next);

        if (is_delimiter (next) || next_ws) {
          if (char == '\n' && next_ws)
            add (" ");

          eat_whitespace ();
        }
        else
          add (scurr);
      }
      // Delimiter
      else if (is_delimiter (curr)) {
        if (curr == ';') {
          while (is_whitespace (next) || next_is_comment ()) {
            if (is_whitespace (next))
              eat_whitespace ();
            if (next_is_block_comment ())
              eat_block_comment ();
            if (next_is_line_comment ())
              eat_line_comment ();
          }

          if (next == '\0') break;
          if (next == '}') continue;

          DO_IF_DEBUG (werror ("Curr [%c] next [%c]:%[1]d\n", curr, next));

          add(";");

          continue;
        }

        add (scurr);

        if (curr == '{' && in_function)
          func_stack->top ()->level++;

        prev_char = curr;

        if (is_whitespace (next))
          eat_whitespace ();
      }
      // Other
      else {
        // Declaration like:
        //
        // var myFunc = function () {
        //   ...
        // }
        //
        // If a function like this isn't terminated with a ; or directly
        // followed by a delimiter (most likey another closing }), the script
        // will smoke. To make sure the function is terminated properly we
        // count the following opening { and closing }. When the stack is back
        // at zero at a closing } we can check if the next character is a
        // delimiter. If not we add a ; to terminate the function.
        if (curr == 'f' && prev_char == '=' && data[i..i+7] == "function") {
          in_function = 1;
          func_stack->push (([ "level" : 0 ]));
        }

        prev_char = curr;
        add (scurr);
      }
    }

    return out->get ();
  }
}
