(import ./fs :as fs)
(import ./janet-cursor :as jc)
(import ./note :as n)
(import ./report :as r)
(import ./study :as s)


(def usage
  ``
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
  ``)

########################################################################

(defn uba-dir-fmt-chars-scan
  [src path note!]
  # https://www.unicode.org/reports/tr9
  (def udfc-table
    {"\u061c" "ALM"
     "\u200e" "LRM"
     "\u200f" "RLM"
     #
     "\u202a" "LRE"
     "\u202b" "RLE"
     "\u202c" "PDF"
     "\u202d" "LRO"
     "\u202e" "RLO"
     #
     "\u2066" "LRI"
     "\u2067" "RLI"
     "\u2068" "FSI"
     "\u2069" "PDI"})
  (def udfc-peg
    (peg/compile
      ~(some (choice (cmt (sequence (line) (column)
                                    (capture
                                      (choice ,;(keys udfc-table))))
                          ,|{:bl $0
                             :bc $1
                             :char-name (get udfc-table $2)})
                     1))))
    (when-let [results (peg/match udfc-peg src)]
      (each res results
        (note! {:type :uba-dir-fmt-chars
                :path path
                :char-name (get res :char-name)
                :bl (get res :bl)
                :bc (get res :bc)}))))

(defn non-ascii-scan
  [specimen]
  (def na-peg
    (peg/compile
      ~(some (choice (cmt (sequence (column)
                                    (capture (range "\x80\xFF")))
                          ,|{:bc $0
                             :non-ascii $1})
                     1))))
  (peg/match na-peg specimen))

(defn handle-name-case
  [res path loc->id id->node root-bindings note!]
  (def [_ attrs name] (get res ::name))
  (def loc (freeze attrs))
  (def id (loc->id loc))
  (unless id
    (eprintf "no id for loc: %p" loc)
    (break))
  # check if a definition uses a built-in name
  (when (index-of (symbol name) root-bindings)
    (note! {:type :def-uses-builtin
            :path path
            :name name
            :bl (get attrs :bl)
            :bc (get attrs :bc)}))
  # check if identifier contains non-ascii
  (when-let [results (non-ascii-scan name)]
    (each res results
      (note! {:type :non-ascii-identifier
              :path path
              :name name
              :non-ascii (get res :non-ascii)
              :bl (get attrs :bl)
              :bc (get res :bc)})))
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
          (note! {:type :param-uses-builtin
                  :path path
                  :def-name name
                  :builtin-name (get sym-node 2)
                  :bl (get-in sym-node [1 :bl])
                  :bc (get-in sym-node [1 :bc])}))))))

(defn handle-destr-tup-case
  [res path loc->id id->node root-bindings note!]
  (def [_ attrs] (get res ::destr-tup))
  (def loc (freeze attrs))
  (def id (loc->id loc))
  (unless id
    (eprintf "no id for loc: %p" loc)
    (break))
  (def crs-at-node
    (jc/make-cursor id->node
                    (get id->node id)))
  (def builtin-sym-nodes
    (filter |(match $
               [:blob _ a-name]
               (index-of (symbol a-name) root-bindings))
            (jc/children crs-at-node)))
  #
  (when (not (empty? builtin-sym-nodes))
        (each sym-node builtin-sym-nodes
          (note! {:type :destr-tup-uses-builtin
                  :path path
                  :builtin-name (get sym-node 2)
                  :bl (get-in sym-node [1 :bl])
                  :bc (get-in sym-node [1 :bc])}))))

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
    (array/concat (all-bindings root-env true)
                  (map symbol
                       [:break :def :do :fn :if :quasiquote :quote
                        :set :splice :unquote :upscope :var :while])))

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
               (choice (sequence (constant ::name)
                                 :blob)
                       (sequence (constant ::destr-tup)
                                 :dl/square))
               :s+
               (drop (any :input))
               `)`))

  # for traversing source - to collect basic info to review
  (def {:study study}
    (s/make-study-infra query-peg))

  # for cursors - to examine things (e.g. parents, siblings, etc.)
  # based on the collected info
  (def {:make-tables make-tables}
    (jc/make-cursor-infra))

  # for noting results
  (def {:note note!
        :record record
        :reset-record reset-record!}
    (n/make-note-infra))

  # all the paths to examine
  (def src-paths
    (fs/collect-paths (slice args 1)))

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

    # check for bidi bits - cf. trojan source
    (uba-dir-fmt-chars-scan src path note!)

    # the initial source traversal, collecting basic info
    (def [results _]
      (study src))

    (when results

      # preparation for the cursor bits to function
      (def [id->node loc->id]
        (make-tables src))

      (each res results
        (cond
          (get res ::name)
          (handle-name-case
            res path loc->id id->node root-bindings note!)
          #
          (get res ::destr-tup)
          (handle-destr-tup-case
            res path loc->id id->node root-bindings note!)
          #
          (errorf "Unknown result type, keys were: %p" (keys res))))

      # report results
      (r/to-stderr record)

      # clear record to prepare for next round
      (reset-record!)))

  (when (os/getenv "VERBOSE")
    (printf "%d files processed in %g secs"
            (length src-paths) (- (os/clock) start)))

  (os/exit 0))

