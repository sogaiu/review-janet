# review-janet (rjan)

Review tool for `.janet` code.

## Status

* Checks whether definition names contain non-ASCII.
* Check for presence of Unicode bidirectional formatting characters.

There's not much yet, but it can be used via a couple of editors or
via direct invocation.

## Use in Editors

### Emacs

`rjan` can be ("chained") along with `janet -k` in Emacs using
[flycheck-janet](https://github.com/sogaiu/flycheck-janet) and
[flycheck-rjan](https://github.com/sogaiu/flycheck-rjan).

### Neovim

`rjan` can be used via
[nvim-lint](https://github.com/mfussenegger/nvim-lint/) along with
`janet -k` in Neovim with a little work.

Had some success with something like the following in `init.vim`:


```vimscript
lua <<EOF
require('lint').linters_by_ft = {
  janet = {'janet', 'rjan'}
}
EOF
```

along with making a file at `nvim-lint/lua/lint/linters/rjan.lua` with
the content:

```
-- info: path:line:col: message
-- warning: path:line:col: message
-- error: path:line:col: message
local pattern = '([^ ]+): [^:]+:(%d+):(%d+): (.+)'
local groups = { 'severity', 'lnum', 'col', 'message' }
local severity_map = {
  info = vim.diagnostic.severity.INFO,
  warning = vim.diagnostic.severity.WARN,
  error = vim.diagnostic.severity.ERROR,
}
local defaults = { source = 'rjan' }

return {
  cmd = 'rjan',
  stdin = true,
  args = {
    '-s',
  },
  stream = 'stderr',
  ignore_exitcode = true,
  parser =
    require('lint.parser').from_pattern(pattern, groups,
                                        severity_map, defaults),
}
```

### Get basic help

```
$ rjan -h
Usage: rjan [option] [file|dir]...

Review janet code and report.

  -h, --help                       show this output

When one or more files and/or directories are specified, review and
report on findings for each located .janet file.

The supported reviews include:

* Check if a definition's name contains non-ascii.

  The definitions that are checked include:

  * defn / defn-
  * defmacro / defmacro-
  * def / def-
  * varfn
  * var / var-

* Check if a name made via destructuring is a built-in name.

  The definitions that are checked include:

  * def / def-
  * var / var-

  * Check for presence of Unicode bidirectional formatting
    characters.

Perhaps other things might be checked for eventually...
```

