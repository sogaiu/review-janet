(def raw-all-bindings
  (do
    # arrange for a relatively unpopulated environment for evaluation
    (def result-env
      (run-context
        {:env root-env
         :read
         (fn [env where]
           # just want one evaluation, set to nil after to avoid exiting
           (put env :exit true)
           #
           '(upscope
              (def result
                (all-bindings))))}))
    # not doing this causes the program to exit
    (put result-env :exit nil)
    (def result-value
      ((get result-env 'result) :value))
    # remove 'result
    (array/remove result-value 
                  (index-of 'result result-value))))
