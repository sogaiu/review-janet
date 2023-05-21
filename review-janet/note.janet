(defn make-note-infra
  []
  (def record @[])

  (defn note!
    [info]
    (array/push record info))

  {:note note!
   :record record})

