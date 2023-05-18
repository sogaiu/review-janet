(import ./fs :as fs)
(import ./janet-cursor :as jc)
(import ./janet-query :as jq)

(def usage
  ``
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
  ``)

########################################################################

(defn main
  [& argv]

  (def args
    (array/slice argv))

  (when (or (one? (length args))
            (when-let [arg (get args 1)]
              (or (= "--help" arg)
                  (= "-h" arg))))
    (print usage)
    (os/exit 0))

  # XXX
  (def on-stdin
    (when-let [arg (get args 1)]
      (when (or (= "--stdin" arg)
                (= "-s" arg))
        (array/remove args 1))))

  (def start (os/clock))

  (def query-str
    ``
    (<::type '[capture [choice "defn-" "defn"
                               "defmacro-" "defmacro"
                               "def-" "def"
                               "varfn"
                               "var-" "var"]]>
     <::name :blob>
     <:...>)
    ``)

  (def root-bindings
    (all-bindings root-env true))

  (def {:grammar loc-grammar
        :node-table id->node
        :loc-table loc->id
        :reset reset!}
    (jc/make-infra))

  (def src-paths
    (fs/collect-paths args))

  (when on-stdin
    (array/push src-paths :stdin))

  # in each file, look for parameters that have built-in names
  (each path src-paths

    (when (string? path)
      (unless (os/stat path)
        (eprintf "Non-existent path: %s" path)
        (os/exit 1)))

    (def src
      (if (string? path)
        (slurp path)
        (file/read stdin :all)))

    (def [results _ loc->node]
      (try
        (jq/query query-str src {:blank-delims [`<` `>`]})
        ([e]
          (def m
            (peg/match '(sequence (thru "line: ")
                                  (capture :d+)
                                  " "
                                  (thru "column: ")
                                  (capture :d+))
                       e))
          (def line
            (scan-number (get m 0)))
          (def col
            (scan-number (get m 1)))
          (eprintf "error: %s:%d:%d: query failed: %s"
                   path line col e)
          [nil nil nil])))

    (when results

      # side-effect of filling in id->node and loc->id
      (peg/match loc-grammar src)

      (each res results
        (def [_ attrs name] (get res ::name))
        (def loc (freeze attrs))
        (def id (loc->id loc))
        (unless id
          (eprintf "no id for loc: %p" loc)
          (break))
        (def crs-at-node
          (jc/make-cursor id->node
                          (get id->node id)))
        (when (index-of (symbol name) root-bindings)
          (def name-line (get attrs :bl))
          (def name-col (get attrs :bc))
          (eprintf (string "info: "
                           "%s:%d:%d: `%s` "
                           "is a built-in name")
                   path name-line name-col name))
        (when (get {"defmacro" true
                    "defmacro-" true
                    "defn" true
                    "defn-" true
                    "varfn" true}
                   (get res ::type))
          (def crs-at-params
            (jc/right-until crs-at-node
                            |(match ($ :node)
                               [:dl/square]
                               true)))
          (when crs-at-params
            (def builtin-sym-nodes
              (filter |(match $
                         [:blob _ a-name]
                         (index-of (symbol a-name) root-bindings))
                      (jc/children crs-at-params)))
            #
            (when (not (empty? builtin-sym-nodes))
              (each sym-node builtin-sym-nodes
                (def sym-name (get sym-node 2))
                (def sym-line (get-in sym-node [1 :bl]))
                (def sym-col (get-in sym-node [1 :bc]))
                (eprintf (string "info: "
                                 "%s:%d:%d: `%s` "
                                 "has parameter with built-in name: `%s`")
                         path sym-line sym-col name sym-name))))))

      # reset id->node and loc->id for next path
      (reset!)))

  (when (os/getenv "VERBOSE")
    (printf "%d files processed in %g secs"
            (length src-paths) (- (os/clock) start)))

  (os/exit 0))
