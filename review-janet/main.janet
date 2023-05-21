(import ./fs :as fs)
(import ./study :as s)
(import ./janet-cursor :as jc)

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

  # for measuring duration of processing
  (def start (os/clock))

  # for looking up built-in names
  (def root-bindings
    (all-bindings root-env true))

  # make sure to have an even number of captures
  # that are made from pairs of captures such that
  # the first of a pair is `(constant ::<name>)` and
  # the second is something that produces one capture
  # as the captures will be used to create a table
  (def query-peg
    ~(sequence `(`
               :s*
               (constant ::type)
               (capture (choice "defn-" "defn"
                                "defmacro-" "defmacro"
                                "def-" "def"
                                "varfn"
                                "var-" "var"))
               :s+
               (constant ::name)
               :blob
               :s+
               (drop (any :input))
               `)`))

  # for traversing source - to collect basic info to review
  (def {:study study}
    (s/make-study-infra query-peg))

  # for cursors - to examine things (e.g. parents, siblings, etc.)
  # based on the collected info
  (def {:grammar loc-grammar
        :node-table id->node
        :loc-table loc->id
        :reset reset-tables!}
    (jc/make-infra))

  # all the paths to examine
  (def src-paths
    (fs/collect-paths args))

  # ...and possibly a special case for handling standard input
  (when on-stdin
    (array/push src-paths :stdin))

  # in each file, look for various conditions
  (each path src-paths

    (when (string? path)
      (unless (os/stat path)
        (eprintf "Non-existent path: %s" path)
        (os/exit 1)))

    (def src
      (if (string? path)
        (slurp path)
        (file/read stdin :all)))

    # the initial source traversal, collecting basic info
    (def [backstack _]
      (study src))

    (when backstack

      # this needs to be done before a new file is examined
      # so earlier results don't confuse things
      # (reset id->node and loc->id for next path)
      (reset-tables!)

      # preparation for the cursor bits to function
      # (side-effect of filling in id->node and loc->id)
      (peg/match loc-grammar src)

      (each res backstack
        (def [_ attrs name] (get res ::name))
        (def loc (freeze attrs))
        (def id (loc->id loc))
        (unless id
          (eprintf "no id for loc: %p" loc)
          (break))
        # check if a definition uses a built-in name
        (when (index-of (symbol name) root-bindings)
          (def name-line (get attrs :bl))
          (def name-col (get attrs :bc))
          (eprintf (string "info: "
                           "%s:%d:%d: `%s` "
                           "is a built-in name")
                   path name-line name-col name))
        # check if anything with parameters uses a built-in name
        (when (get {"defmacro" true
                    "defmacro-" true
                    "defn" true
                    "defn-" true
                    "varfn" true}
                   (get res ::type))
          # XXX: move this before the check above if other lints
          #      that use the cursor get added
          (def crs-at-node
            (jc/make-cursor id->node
                            (get id->node id)))
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
                         path sym-line sym-col name sym-name))))))))

  (when (os/getenv "VERBOSE")
    (printf "%d files processed in %g secs"
            (length src-paths) (- (os/clock) start)))

  (os/exit 0))

