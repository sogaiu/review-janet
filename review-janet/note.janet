(defn make-note-infra
  []
  (def record @[])

  (defn note!
    [info]
    (array/push record info))

  (defn reset-record!
    []
    (array/clear record))

  {:note note!
   :record record
   :reset-record reset-record!})

