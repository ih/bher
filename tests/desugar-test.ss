(import (church desugar))

(de-sugar-all '(define (F1 x) (+ x x)))
;;(de-sugar-all '(lambda () (define F1 (lambda (V1 V2 V3) #f)) #f))