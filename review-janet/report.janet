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
          (string/format (string "info: "
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
          (string/format (string "info: "
                                 "%s:%d:%d: `%s` "
                                 "has parameter with built-in name: `%s`")
                         path line col dname bname))
        #
        (errorf "Unrecognized review type: %p" the-type)))
    (eprint msg)))

