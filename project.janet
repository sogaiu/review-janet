(declare-project
  :name "review-janet"
  :url "https://github.com/sogaiu/review-janet"
  :repo "git+https://github.com/sogaiu/review-janet.git")

(declare-source
  :source @["review-janet"])

(declare-binscript
  :main "rjan"
  :is-janet true)

(task "cmd-line-tests" []
  :tags [:test]
  (os/execute ["janet"
               "script/run-cmd-line-tests.janet"
               "data/cmd"
               "data/stdout"
	       "data/stderr"]
              :p))
