# review-janet (rjan)

Review tool for `.janet` code.

## Status

* Checks whether parameter names are built-in names.
* Checks whether definition names are built-in names.

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

## Invocation Examples

### Check for parameter names shadowing built-in names

Suppose there is a file named `sample.janet` with content:

```janet
(defn my-fn
  [table]
  (put table :a :ok))

(defn my-other-fn
  [count]
  (print "Number of jumps was: %d" count))
```

The file may be checked by:

```
$ rjan sample.janet
info: sample.janet:2:4: `my-fn` has parameter with built-in name: `table`
info: sample.janet:6:4: `my-other-fn` has parameter with built-in name: `count`
```

### Check if a definition's name shadows a built-in name

Suppose there is a file named `sample2.janet` with content:

```janet
(defn inc
  [x]
  (+ 1 x))

(def default-peg-grammar
  {:a '(range "ay" "AY")})
```

The file may be checked by:

```
$ rjan sample2.janet
info: sample2.janet:1:7: `inc` is a built-in name
info: sample2.janet:5:6: `default-peg-grammar` is a built-in name
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

* Check if any parameter names for certain definitions are built-in
  names (e.g. `count`, `hash`, `keys`, `kvs`, `min`, `table`,
  `type`, etc.).

  The definitions that are checked include:

  * defmacro / defmacro-
  * defn / defn-
  * varfn

  There isn't any support for destructured forms at the moment.

* Check if a definition's name is a built-in name.

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

Perhaps other things might be checked for eventually...
```

## Stats

Based on running `rjan` across some collected Janet code, the top 10
built-in names that were used as parameters were:

```
1. type: 18
2. last: 13
3. hash: 12
3. doc: 12
5. keys: 11
5. table: 11
5. count: 11
8. in: 10
8. pairs: 10
10. max: 8
```

The top 10 built-in names that were "overridden" were:

```
1. parse: 32
2. update: 21
3. assert: 19
4. count: 18
5. last: 16
6. get: 15
7. label: 14
8. sum: 12
8. all: 12
8. compile: 12
```
