(import ./janet-peg :as jp)

(defn make-search-infra
  [query-peg]

  (def lang-grammar
    (jp/make-grammar))

  (def backstack @[])

  (def capture-query-peg
    ~(cmt ,query-peg
          ,(fn [& caps]
             (when (not (empty? caps))
               (array/push backstack (table ;caps)))
             caps)))

  (def search-grammar
    (-> (table ;(kvs lang-grammar))
        (put :main ~(some :input))
        # add our query to the grammar
        (put :query capture-query-peg)
        # make the query one of the items in the choice special for
        # :form so querying works on "interior" forms.  otherwise only
        # top-level captures show up.
        (put :form (let [old-form (get lang-grammar :form)]
                     (tuple 'choice
                            :query
                            ;(tuple/slice old-form 1))))))

  (defn reset-backstack!
    []
    (array/clear backstack))

  {:search-grammar search-grammar
   :backstack backstack
   :reset-backstack reset-backstack!})

