(library (testing)
         (export test-expr trivial-expr)
         (import (rnrs))

         (define (test-expr) '(let () (if (if #t #t #t) (if #t #t #t) (if #t #t #t))))
         (define (trivial-expr) '(let () #t))
         )
           