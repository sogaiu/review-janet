(defn to-stderr
  [record]
  (each item record
    (def the-type
      (get item :type))
    (def msg
      (case the-type
        :def-uses-builtin
        (do
          (def {:path path
                :name name
                :bl line :bc col}
            item)
          (string/format
            (string "info: "
                    "%s:%d:%d: `%s` "
                    "is a built-in name")
            path line col name))
        #
        :param-uses-builtin
        (do
          (def {:path path
                :def-name dname :builtin-name bname
                :bl line :bc col}
            item)
          (string/format
            (string "info: "
                    "%s:%d:%d: `%s` "
                    "has parameter with built-in name: `%s`")
            path line col dname bname))
        #
        :destr-tup-uses-builtin
        (do
          (def {:path path
                :builtin-name bname
                :bl line :bc col}
            item)
          (string/format
            (string "info: "
                    "%s:%d:%d: "
                    "destructuring name is a built-in name: `%s`")
            path line col bname))
        #
        :non-ascii-identifier
        (do
          (def {:path path
                :name name
                :non-ascii non-ascii
                :bl line :bc col}
            item)
          (string/format
            (string "info: "
                    "%s:%d:%d: non-ascii %n in identifier `%s`")
            path line col non-ascii name))
        #
        :uba-dir-fmt-chars
        (do
          (def {:path path
                :char-name char-name
                :bl line :bc col}
            item)
          (string/format
            (string "info: "
                    "%s:%d:%d: unicode bidi formatting char `%s`")
            path line col char-name))
        #
        (errorf "Unrecognized review type: %p" the-type)))
    (eprint msg)))

