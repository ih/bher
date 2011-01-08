(library (testing)
         (export test-expr)
         (import (rnrs))

         (define (test-expr) '(let () (if (if #t #t #t) (if #t #t #t) (if #t #t #t)))))
           