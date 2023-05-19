########################################################################

(def tap-version 14)

(defn print-tap-version
  [n]
  (printf "TAP Version %d" n))

(defn indent
  [buf n]
  (when (not (pos? (length buf)))
    (break buf))
  #
  (def nl-spaces
    (buffer/push @"\n"
                 ;(map |(do $ " ")
                       (range 0 n))))
  (def indented
    (buffer/push (buffer/new-filled n (chr " "))
                 buf))
  # XXX: not so efficient, but good enough?
  (string/replace-all "\n"
                      nl-spaces
                      indented))

(comment

  (def src
    @``
     (source [0, 0] - [1, 0]
       (kwd_lit [0, 0] - [0, 8]))
     ``)

  (indent src 2)
  # =>
  ``
    (source [0, 0] - [1, 0]
      (kwd_lit [0, 0] - [0, 8]))
  ``

  )

########################################################################

(defn run-tests
  [cmd-dir stdout-dir stderr-dir]
  (when (or (not (os/stat cmd-dir))
            (and (not (os/stat stdout-dir))
                 (not (os/stat stderr-dir))))
    (eprint "cmd and stdout or stderr directories must exist")
    (break nil))

  (def stats @[])

  (var i 0)

  (def out-tf (file/temp))
  (def err-tf (file/temp))

  (def actual-out @"")
  (def expected-out @"")
  (def actual-err @"")
  (def expected-err @"")

  (var last-err-end 0)
  (var last-out-end 0)

  (def src-paths
    (filter |(= :file
                (os/stat (string cmd-dir "/" $)
                         :mode))
            (os/dir cmd-dir)))

  # XXX: tappy doesn't seem to like this
  #(print-tap-version tap-version)

  (var result-out nil)
  (var result-err nil)

  (printf "1..%d" (length src-paths))

  (each fp src-paths

    (buffer/clear actual-out)
    (buffer/clear expected-out)
    (buffer/clear actual-err)
    (buffer/clear expected-err)

    # result may be set to return value of deep= below
    # which is true or false - nil means test skipped
    (set result-out nil)
    (set result-err nil)

    (def cmd-fp
      (string cmd-dir "/" fp))

    (def ext-pos
      (last (string/find-all ".txt" fp)))

    (def name-no-ext
      (string/slice fp 0 ext-pos))

    (def expected-out-fp
      (string stdout-dir "/" name-no-ext ".txt"))
    (def expected-err-fp
      (string stderr-dir "/" name-no-ext ".txt"))

    # only makes sense to test if there is an expected value
    (when (or (os/stat expected-out-fp)
              (os/stat expected-err-fp))

      # XXX: eventually support other invocation formats, e.g.
      #      program name and arguments each on own line (so split on \n)
      (def command
        (->> (slurp cmd-fp)
             string/trim
             (string/split " ")))

      # XXX: somehow this keeps appending to tf, ignoring where the current
      #      file position is (as reported by file/tell)
      (def ret
        (os/execute command :p {:out out-tf
                                :err err-tf}))

      (file/flush out-tf)
      (file/flush err-tf)

      (def out-pos
        (file/tell out-tf))
      (def err-pos
        (file/tell err-tf))

      (def out-n-bytes
        (- out-pos last-out-end))
      (def err-n-bytes
        (- err-pos last-err-end))

      (file/seek out-tf :set last-out-end)
      (file/seek err-tf :set last-err-end)

      (set last-out-end out-pos)
      (set last-err-end err-pos)

      (file/read out-tf out-n-bytes actual-out)
      (file/read err-tf err-n-bytes actual-err)

      # at least one of the files should exist
      # based on the earlier check above
      (when (os/stat expected-out-fp)
        (def of (file/open expected-out-fp))
        (file/read of :all expected-out)
        (file/close of))
      (when (os/stat expected-err-fp)
        (def ef (file/open expected-err-fp))
        (file/read ef :all expected-err)
        (file/close ef))

      (set result-out
        (deep= actual-out expected-out))
      (set result-err
        (deep= actual-err expected-err)))

    (cond
      (and (true? result-out)
           (true? result-err))
      (do
        (printf "ok %d" (inc i))
        (array/push stats [i :ok]))
      #
      (or (false? result-out)
          (false? result-err))
      (do
        (printf "not ok %d - %s"
                (inc i) cmd-fp)
        (printf "  ---")
        (when (false? result-out)
          (printf "  found (out):")
          (printf "%s" (indent (string/trim actual-out) 4))
          (printf "  wanted (out):")
          (printf "%s" (indent (string/trim expected-out) 4)))
        (when (false? result-err)
          (printf "  found (err):")
          (printf "%s" (indent (string/trim actual-err) 4))
          (printf "  wanted (err):")
          (printf "%s" (indent (string/trim expected-err) 4)))
        (printf "  ...")
        (array/push stats [i :not-ok]))
      #
      (or (nil? result-out)
          (nil? result-err))
      (do
        (printf "not ok %d - %s # SKIP"
                (inc i) cmd-fp)
        (array/push stats [i :skip]))
      # defensive
      (eprintf "Unexpected result, one or both of following:")
      (eprintf "* out: %M" result-out)
      (eprintf "* err: %M" result-err))

    (++ i))

  (file/close out-tf)
  (file/close err-tf)

  [stats i])

(defn main
  [& args]
  # XXX: always require 3 arguments?
  (unless (>= (length args) (inc 3))
    (eprintf "Please specify cmd, stdout, and stderr directory paths")
    (os/exit 1))
  #
  (def cmd-files-dir
    (get args 1))
  (def stdout-files-dir
    (get args 2))
  (def stderr-files-dir
    (get args 3))
  #
  (run-tests cmd-files-dir stdout-files-dir stderr-files-dir))

