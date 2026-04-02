(defn to-stderr
  [record]
  (each item record
    (def the-type (get item :type))
    (def msg
      (case the-type
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

