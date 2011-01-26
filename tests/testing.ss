(library (testing)
         (export test-expr trivial-expr test-exprs)
         (import (rnrs))

         (define (test-expr) '(let () (if (if #t #t #t) (if #t #t #t) (if #t #t #t))))
         (define (trivial-expr) '(let () #t))
         (define (test-exprs) '((let () (if (if #t #t #t) (if #t #t #t) (if #t #t #t)))
                                (let () (define F1 (lambda () (if #t #t #t))) (if (F1) (F1) (F1)))
                                (let () (define F1 (lambda (V1) (if V1 V1 V1)) (F1 (F1 #t))))
                                (let () (if #t #f #t))))
         )
           