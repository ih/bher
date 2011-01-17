(define (f a b . z)
  z)

(define (f x)
  (let*-values ([(x y z) (apply values '(a b c))])
    (list x y z)))