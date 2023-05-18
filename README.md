# review-janet (rjan)

Review tool for `.janet` code.

## Status

Not much yet :)

* Checks whether parameter names are built-in names.
* Checks whether definition names are built-in names.

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

* Check whether any parameter names for certain definitions are
  built-in names (e.g. `count`, `hash`, `keys`, `kvs`, `min`, `table`,
  `type`, etc.).

  The definitions that are checked include:

  * defmacro / defmacro-
  * defn / defn-
  * varfn

  There isn't any support for destructured forms at the moment.

* Check whether a definition's name is a built-in name.

  The definitions that are checked include:

  * defn / defn-
  * defmacro / defmacro-
  * def / def-
  * varfn
  * var / var-

Perhaps other things might be checked for eventually...
```
