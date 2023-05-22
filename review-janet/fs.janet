(def file-ext
  ".janet")

(def sep
  (if (= :windows (os/which))
    "\\"
    "/"))

(defn find-files-with-ext
  [dir ext]
  (def paths @[])
  (defn helper
    [a-dir]
    (each path (os/dir a-dir)
      (def sub-path
        (string a-dir sep path))
      (case (os/stat sub-path :mode)
        :directory
        (helper sub-path)
        #
        :file
        (when (string/has-suffix? ext sub-path)
          (array/push paths sub-path)))))
  (helper dir)
  paths)

(comment

  (find-files-with-ext "." file-ext)

  )

(defn clean-end-of-path
  [path sep]
  (when (one? (length path))
    (break path))
  (if (string/has-suffix? sep path)
    (string/slice path 0 -2)
    path))

(comment

  (clean-end-of-path "hello/" "/")
  # =>
  "hello"

  (clean-end-of-path "/" "/")
  # =>
  "/"

  )

(defn collect-paths
  [args]
  (def src-filepaths @[])
  (each thing args
    (def apath
      (clean-end-of-path thing sep))
    (def stat
      (os/stat apath :mode))
    # XXX: should :link be supported?
    (cond
      (= :file stat)
      (if (string/has-suffix? file-ext apath)
        (array/push src-filepaths apath)
        (do
          (eprintf "File does not have extension: %p" file-ext)
          (break nil)))
      #
      (= :directory stat)
      (array/concat src-filepaths (find-files-with-ext apath file-ext))
      #
      (do
        (eprintf "Not an ordinary file or directory: %p" apath)
        (break nil))))
  #
  src-filepaths)

