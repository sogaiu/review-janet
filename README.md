# review-janet (rjan)

Review tool for `.janet` code.

## Status

Not much yet :)

* Checks whether parameter names use built-in names.

## Invocation Examples

Check for parameter names shadowing built-in names.

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
sample.janet:2:4 `my-fn` has parameter with built-in name: `table`
sample.janet:6:4 `my-other-fn` has parameter with built-in name: `count`

```

Get basic help.

```
$ rjan -h
Usage: rjan [option] [file|dir]...

Review janet code and report.

  -h, --help                       show this output

When one or more files and/or directories are specified, review and
report on findings for each located .janet file.

The supported reviews include:

* Check whether any parameter names for certain definitions use
  built-in names (e.g. `count`, `keys`, `kvs`, `min`, `type`, etc.).

  The definitions that are checked include:

  * defmacro / defmacro-
  * defn / defn-
  * varfn

  There isn't any support for destructured forms at the moment.

Perhaps other things might be checked for eventually...
```
