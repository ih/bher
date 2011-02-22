(define o-line '(node o 0 5 (node o 0 5 (node o 0 5 (node o 0 5 (node o 0 5 (node o 0 5)))))))

(define rg-bent-line '(node r 0 5 (node r 0 5 (node r 0 5 (node r 0 5 (node r 0 5 (node r 0 5 (node r 90 5 
                             (node g 0 5 (node g 0 5 (node g 0 5 (node g 0 5 (node g 0 5 (node g 0 5 (node g 90 5)))))))))))))))

(define yb-bent-line '(node y 0 5 (node y 0 5 (node y 0 5 (node y 0 5 (node y 0 5 (node y 0 5 (node y 80 5 
                             (node b 0 5 (node b 0 5 (node b 0 5 (node b 0 5 (node b 0 5 (node b 0 5 (node b 90 5)))))))))))))))

;;;input (rg-bent-line yb-bent-line)

(let ()
  (define draw-bent-line
    (lambda (color1 color2 angle)
      (extend-by-2
        (extend-by-2
          (extend-by-2
            (node color1 angle 5
              (extend-by-2 (extend-by-2 (extend-by-2 (node color2 90 5) color2) color2)
                color2))
            color1)
          color1)
        color1)))
  (define extend-by-2
    (lambda (last-node color) (node color 0 5 (node color 0 5 last-node))))
;;;(rg-bent-line yb-bent-line) rewritten
((draw-bent-line r g 90) (draw-bent-line y b 80))

;;;input (o-line rg-bent-line yb-bent-line)
(define extend-by-1
  (lambda (color last-node)
    (node color 0 5 last-node)))

(define draw-line-length-6
  (lambda (last-element color)
    (extend-by-1 color
              (extend-by-1 color
                        (extend-by-1 color (extend-by-1 color (extend-by-1 color last-element)))))))

(define 2-color-bent-line
  (lambda (color1 color2 angle)
    (draw-line-length-6
     (extend-by-1 color1
               (node color1 angle 5
                     (draw-line-length-6 (extend-by-1 color2 (node color2 90 5)) color2)))
     color1)))
;;;(o-line rg-bent-line yb-bent-line) rewritten
((draw-line-length-6 (node o 0 5) o) (2-color-bent-line r g 90) (2-color-bent-line y b 80))

;;;CHECKING FOR TYPE
;;;input (o-line rg-bent-line yb-bent-line)
  (define bent-line
    (lambda (color1 color2)
      (extend-by-3
        (extend-by-3
          (extend-by-1 (extend-by-3 (extend-by-3 (node color2 90 5) color2) color2)
            color1)
          color1)
        color1)))
  (define extend-by-1 (lambda (last-node color) (node color 0 5 last-node)))
  (define extend-by-3
    (lambda (last-node color)
      (extend-by-1 (extend-by-1 (extend-by-1 last-node color) color) color)))
;;;(o-line rg-bent-line yb-bent-line) rewritten
((extend-by-3 (extend-by-1 (extend-by-1 (node o 0 5) o) o) o) (bent-line r g) (bent-line y b))



;;;(list o-line rg-bent-line pt-bent-line)
(let ()
  (define F196 (lambda (V643 V776) (node V643 0 5 V776)))
  (define F193
    (lambda (V747 V746 V743)
      (F172
        (F196 V747
          (node V747 V743 5
            (F172 (F196 V746 (node V746 90 5)) V746)))
        V747)))
  (define F172
    (lambda (V644 V643)
      (F196 V643
        (F196 V643 (F196 V643 (F196 V643 (F196 V643 V644)))))))
  ((F172 (node o 0 5) o) (F193 r g 90) (F193 p t 20)))