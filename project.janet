(declare-project
  :name "review-janet"
  :url "https://github.com/sogaiu/review-janet"
  :repo "git+https://github.com/sogaiu/review-janet.git")

(declare-source
  :source @["review-janet"])

(declare-binscript
  :main "rjan"
  :is-janet true)

