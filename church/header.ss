#!r6rs

;; authors: noah goodman

;;this library generates the church-specific header definitions.
;;the header includes:
;;  church-make-xrp
;;  church-apply, church-eval
;;  mcmc code, including the query primitives assumed by the de-sugarring transform.
;;  deterministic (non-higher-order) scheme primitives wrapped up into church- forms. (NOTE: should have a mechanism to provide additional primitives -- add external defs arg to generate-header.)

;;this should generate scheme compatible with r4rs+srfi1 (some additional defines are needed for stalin, etc, that don't have srfis).

;;NOTE: assumes a bunch of random sampling/scoring primitives, which should be provided from GSL (eg. in our external/math-env.ss).

(library
 (church header)

 (export generate-header)

 (import (rnrs)
         (_srfi :1) ; lists
         (church readable-scheme)
         )

 (define *storethreading* false)
 (define *lazy* true)

 (define (prefix-church symb) (string->symbol (string-append "church-" (symbol->string symb))))
 (define (church-symbol? symb) (and (< 7 (length (string->list (symbol->string symb))))
                                    (equal? "church-" (list->string (take (string->list (symbol->string symb)) 7)))))
 (define (un-prefix-church symb) (if (church-symbol? symb)
                                     (string->symbol (list->string (drop (string->list (symbol->string symb)) 7)))
                                     symb))
 
 (define (wrap-primitive symb . nargs)
   (let* ((actual-args (if (null? nargs) 'args (repeat (first nargs) gensym)))
          (arguments  `(address store . ,actual-args))
          (application (if (null? nargs)
                           (if *lazy*
                               `(apply ,symb (map (lambda (a) (church-force address store a)) args))
                               `(apply ,symb args))
                           (if *lazy*
                               `(,symb ,@(map (lambda (a) `(church-force address store ,a)) actual-args))
                               `(,symb ,@actual-args)))))
     (if *storethreading*
         `(lambda ,arguments (list ,application store))
         `(lambda ,arguments ,application))))
 
 (define (primitive-def symb)
   `(define ,symb ,(wrap-primitive (un-prefix-church symb))))

 ;;any free "church-" variable in the program that isn't provided explicitly is assumed to be a scheme primitive, and a church- definition is generated for it.
 (define (generate-header storethreading lazy free-variables external-defs)
   (set! *storethreading* storethreading)
   (set! *lazy* lazy)
   (let* ((special-defs (generate-special))
          (def-symbols (map (lambda (d) (if (pair? (second d)) (first (second d)) (second d)))
                            (append special-defs external-defs))) ;;get defined symbols
          (leftover-symbols (filter (lambda (v) (not (memq v def-symbols))) (filter church-symbol? (delete-duplicates free-variables))))
          (primitive-defs (map (lambda (s) (primitive-def s)) leftover-symbols)))
     (append external-defs primitive-defs special-defs)))

 (define (generate-special)
   `(
;;;
     ;;misc church primitives
     (define (church-apply address store proc args)
       ,(if *lazy*
            `(apply (church-force address store proc) address store (church-force address store args))
            `(apply proc address store args)))
     ;(define (church-eval address store sexpr env) (error 'eval "eval not implemented"))

     ;;requires compile, eval, and environment to be available from underlying scheme....
     (define (church-eval addr store sexpr)
       ((eval `(letrec ,(map (lambda (def)
                              (if (symbol? (cadr def))
                                  (list (cadr def) (caddr def))
                                  `(,(car (cadr def)) (lambda ,(cdr (cadr def)) ,@(cddr def)))))
                            (compile (list sexpr) '()))
                church-main)
             (environment '(rnrs)
                          '(abstract)
                          '(pi lazy)
                          '(util)
                          '(sym)
                          '(rnrs mutable-pairs)
                          '(_srfi :1)
                          '(rename (church external math-env) (sample-discrete discrete-sampler))
                          '(rename (only (ikarus) gensym pretty-print exact->inexact) (gensym scheme-gensym))
                          '(_srfi :19)
                          '(church compiler)
                          '(rnrs eval)  ))
             addr store))
     
     (define (church-get-current-environment address store) (error 'gce "gce not implemented"))
     (define church-true #t)
     (define church-false #f)
     (define church-pair ,(wrap-primitive 'cons 2))
     (define church-first ,(wrap-primitive 'car 1))
     (define church-rest ,(wrap-primitive 'cdr 1))
     (define (church-or address store . args) (fold (lambda (x y) (or x y)) #f args)) ;;FIXME: better way to do this? ;;FIXME!! doesn't return store..
     (define (church-and address store . args) (fold (lambda (x y) (and x y)) #t args))

     (define (lev-dist) (error "lev-dist not implemented"))

     ;;for laziness and constraint prop:
     (define (church-force address store val) (if (and (pair? val) (eq? (car val) 'delayed))
                                                  (church-force address store ((cadr val) address store))
                                                  val))
     

;;;
     ;;stuff for xrps (and dealing with stores):
     (define (make-store xrp-draws xrp-stats score tick enumeration-flag with-proposer-calls)
       (let ();[db (pretty-print (list "new score is " score))])
         (list xrp-draws xrp-stats score tick enumeration-flag with-proposer-calls)))
     (define (make-empty-store) (make-store (make-addbox) (make-addbox) 0.0 0 #f (make-addbox)))
     (define store->xrp-draws first)
     (define store->xrp-stats second)
     (define store->score third)
     (define store->tick fourth)
     (define store->enumeration-flag fifth) ;;FIXME: this is a hacky way to deal with enumeration...
     (define store->with-proposer-calls sixth)

     (define (church-reset-store-xrp-draws address store)
       (return-with-store store
                          (make-store (make-addbox)
                                      (store->xrp-stats store)
                                      (store->score store)
                                      (store->tick store)
                                      (store->enumeration-flag store)
                                      (store->with-proposer-calls store))
                          'foo))

     (define (reset-with-proposer-calls state)
       (let* ([store (mcmc-state->store state)])
         (make-mcmc-state (make-store (store->xrp-draws store)
                                      (store->xrp-stats store)
                                      (store->score store)
                                      (store->tick store)
                                      (store->enumeration-flag store)
                                      (make-addbox))
                          (mcmc-state->value state)
                          (mcmc-state->address state))))


     
     (define (return-with-store store new-store value) ,(if *storethreading*
                                                            '(list value new-store)
                                                            '(begin (set-car! store (car new-store))
                                                                    (set-cdr! store (cdr new-store))
                                                                    value)))


     (define alist-insert
       (lambda (addbox address info)
         (cons (cons address info) addbox)))

     ;; returns pair of info and remaining addbox. returns false if no
     ;; info with this address.
     (define alist-pop
       (lambda (addbox address)
         (if (null? addbox)
             (cons #f '())
             (if (equal? address (caar addbox))
                 (cons (cdar addbox) (cdr addbox))
                 (let ((ret (alist-pop (cdr addbox) address)))
                   (cons (car ret) (cons (car addbox) (cdr ret))))))))

     (define (make-empty-alist) '())
     (define alist-size length)
     (define alist-empty? null?)
     
     ;; addboxes hold info indexed by the evaluation address.
     ;; doesn't attempt to maintain order.

     ;; alist addbox
     (define (add/replace-into-addbox addbox address new-entry)
       (let* ([present (pull-outof-addbox addbox address)])
         (if (equal? present '(#f))
             (add-into-addbox addbox address new-entry)
             (add-into-addbox (rest present) address new-entry))))

              
     (define add-into-addbox alist-insert)
     (define pull-outof-addbox alist-pop)
     (define make-addbox make-empty-alist)
     (define addbox->alist (lambda (addbox) addbox))
     (define alist->addbox (lambda (alist) alist))
     (define addbox-size alist-size)
     (define addbox-empty? alist-empty?)
     
     ;; trie addbox
     ;; (define make-addbox make-empty-trie)
     ;; (define add-into-addbox trie-insert)
     ;; (define pull-outof-addbox trie-pop)
     ;; (define addbox->alist trie->alist)
     ;; (define alist->addbox alist->trie)
     ;; (define addbox-size trie-size)
     ;; (define addbox-empty? trie-empty?)

     (define (make-with-proposer-call address value proposer-thunk proc)
       (list address value proposer-thunk proc))

     (define with-proposer-call-address first)
     (define with-proposer-call-value second)
     (define with-proposer-call-proposer third)
     (define with-proposer-call-proc fourth)

     ;;creates a with-proposer-call and places it into the store everytime the proc is called, this with-proposer-call can be used to make proposals in basic-proposal-distribution, assumes proc is a church thunk for now
     (define (church-with-proposer address store proc proposer)
       (lambda (call-address store)
         (let* ([with-proposer-calls (store->with-proposer-calls store)]
                [value (proc call-address store)]
                [new-call (make-with-proposer-call call-address value proposer proc)]
                [new-proposer-calls (add/replace-into-addbox with-proposer-calls call-address new-call)]
                [new-store (make-store (store->xrp-draws store)
                                       (store->xrp-stats store)
                                       (store->score store)
                                       (store->tick store)
                                       (store->enumeration-flag store)
                                       new-proposer-calls)]) ;;only thing that changes is new-proposer-calls
           (return-with-store store new-store value))))


       

     
     (define (make-xrp-draw address value xrp-name proposer-thunk ticks score support)
       (list address value xrp-name proposer-thunk ticks score support))
     (define xrp-draw-address first)
     (define xrp-draw-value second)
     (define xrp-draw-name third)
     (define xrp-draw-proposer fourth)
     (define xrp-draw-ticks fifth) ;;ticks is a pair of timer tick when this xrp-draw is touched and previous touch if any.
     (define xrp-draw-score sixth)
     (define xrp-draw-support seventh)


     ;;note: this assumes that the fns (sample, incr-stats, decr-stats, etc) are church procedures.
     ;;FIXME: what should happen with the store when the sampler is a church random fn? should not accumulate stats/score since these are 'marginalized'.
     (define (church-make-xrp address store xrp-name sample incr-stats decr-stats score init-stats hyperparams proposer support)
       ;,(if *lazy*
       ;;FIXME!! only rebind args if lazy..
       (let* ((xrp-name (church-force address store xrp-name))
              (sample (church-force address store sample))
              (incr-stats (church-force address store incr-stats))
              (decr-stats (church-force address store decr-stats))
              (score (church-force address store score))
              (init-stats (church-force address store init-stats))
              (hyperparams (church-force address store hyperparams))
              (proposer (church-force address store proposer))
              (support (church-force address store support))
              ;;(db (pretty-print (list "creation of the xrp" xrp-name)))
              )
         (return-with-store
        store
        (let* ((ret (pull-outof-addbox (store->xrp-stats store) address))
               (oldstats (car ret))
               (reststatsbox (cdr ret))
               (tick (store->tick store)))
               ;;[db (pretty-print (list "before resetting of states" store xrp-name oldstats reststatsbox))])
          (if (and (not (eq? #f oldstats)) (= tick (second oldstats))) ;;reset stats only if this is first touch on this tick.
              store
              (make-store (store->xrp-draws store)
                          (add-into-addbox reststatsbox address (list init-stats tick))
                          (store->score store)
                          tick
                          (store->enumeration-flag store)
                          (store->with-proposer-calls store))))
        (let* ((xrp-address address)
               ;;[db (pretty-print (list "init-stats initialized?" store xrp-name))]
               (proposer (if (null? proposer)
                             (lambda (address store operands old-value) ;;--> proposed-value forward-log-prob backward-log-prob
                               (let* ((dec (decr-stats address store old-value (caar (pull-outof-addbox (store->xrp-stats store) xrp-address)) hyperparams operands))
                                      (decstats (second dec))
                                      (decscore (third dec))
                                      (inc (sample address store decstats hyperparams operands))
                                      (proposal-value (first inc))
                                      (incscore (third inc)))
                                 (list proposal-value incscore decscore)))
                             proposer)))
          (lambda (address store . args)
            (let* ((tmp (pull-outof-addbox (store->xrp-draws store) address)) ;;FIXME!! check if xrp-address has changed?
                   (old-xrp-draw (car tmp))
                   ;;[db (pretty-print (list "inside xrp" xrp-name old-xrp-draw))]
                   (rest-xrp-draws (cdr tmp))
                   (old-tick (if (eq? #f old-xrp-draw) '() (first (xrp-draw-ticks old-xrp-draw)))))
              ;;if this xrp-draw has been touched on this tick, as in mem, don't change score or stats.
              (if (equal? (store->tick store) old-tick)
                  (let ();;[db (pretty-print (list "xrp unchanged so tick is old-tick" (xrp-draw-score old-xrp-draw)))])
                  (return-with-store store store (xrp-draw-value old-xrp-draw))) ;;WHY IS THIS WRITTEN THIS WAY?
                  (let* ((tmp (pull-outof-addbox (store->xrp-stats store) xrp-address))
                         (stats (caar tmp))
                         (rest-statsbox (cdr tmp))
                         (support-vals (if (null? support) '() (support address store stats hyperparams args)))
                         ;;this commented out code is for incemental updates...
                         ;; (tmp (if (eq? #f old-xrp-draw)
                         ;;          (sample address store stats hyperparams args) ;;FIXME: returned store?
                         ;;          (let* ((decret (decr-stats address store (xrp-draw-value old-xrp-draw) stats hyperparams args)) ;;FIXME!!! old args and xrp stats?
                         ;;                 (incret (incr-stats address store (xrp-draw-value old-xrp-draw) (second decret) hyperparams args)))
                         ;;            (list (first incret) (second incret) (- (third incret) (third decret))))))
                         (tmp (if (eq? #f old-xrp-draw)
                                  (if (store->enumeration-flag store) ;;hack to init new draws to first element of support...
                                      (incr-stats address (cons (first store) (cdr store)) (first support-vals) stats hyperparams args)
                                      (sample address (cons (first store) (cdr store)) stats hyperparams args)) ;;FIXME: returned store?
                                  (incr-stats address (cons (first store) (cdr store)) (xrp-draw-value old-xrp-draw) stats hyperparams args)))
                         (value (first tmp))
                         (new-stats (list (second tmp) (store->tick store)))
                         (incr-score (third tmp)) ;;FIXME: need to catch measure zero xrp situation?
                         ;;[db (if (equal? xrp-name 'marginalized-eq-obs-gen-sexpr) (pretty-print (list xrp-name " adding " incr-score " to the total score.")) '())]
                         (new-xrp-draw (make-xrp-draw address
                                                      value
                                                      xrp-name
                                                      (lambda (address store state)
                                                        ,(if *storethreading*
                                                             '(list (first
                                                                     (church-apply (mcmc-state->address state) (mcmc-state->store state) proposer (list args value)))
                                                                    store)
                                                             '(let ((store (cons (first (mcmc-state->store state)) (cdr (mcmc-state->store state)))))
                                                                (church-apply (mcmc-state->address state) store proposer (list args value)))))
                                                      (cons (store->tick store) old-tick)
                                                      incr-score
                                                      support-vals))
                         (new-store (make-store (add-into-addbox rest-xrp-draws address new-xrp-draw)
                                                (add-into-addbox rest-statsbox xrp-address new-stats)
                                                (+ (store->score store) incr-score)
                                                (store->tick store)
                                                (store->enumeration-flag store)
                                                (store->with-proposer-calls store))))
                    (return-with-store store new-store value))))))))  )

     
       

       ;;mcmc-state structures consist of a store (which captures xrp state, etc), a score (which includes constraint enforcement), and a return value from applying a nfqp.
       ;;constructor/accessor fns: mcmc-state->xrp-draws, mcmc-state->score, mcmc-state->query-value, church-make-initial-mcmc-state.
       (define (make-mcmc-state store value address) (list store value address))

       (define (add-proc-to-state state proc)
         (append state (list proc)))
       
       (define mcmc-state->store first)
       (define mcmc-state->value second)
       (define mcmc-state->address third)
       (define (mcmc-state->xrp-draws state) (store->xrp-draws (mcmc-state->store state)))
       (define (mcmc-state->with-proposer-calls state) (store->with-proposer-calls (mcmc-state->store state)))
       (define (mcmc-state->score state)
         (if (not (eq? #t (first (second state))))
             -inf.0 ;;enforce conditioner.
             (store->score (mcmc-state->store state))))

       ;;this assumes that nfqp returns a thunk, which is the delayed query value. we force (apply) the thunk here, using a copy of the store from the current state.
       (define (mcmc-state->query-value state)
         ,(if *storethreading*
              '(first (church-apply (mcmc-state->address state) (mcmc-state->store state) (cdr (second state)) '()))
              '(let ((store (cons (first (mcmc-state->store state)) (cdr (mcmc-state->store state)))))
                 (church-apply (mcmc-state->address state) store (cdr (second state)) '()))))

       ;;this captures the current store/address and packages up an initial mcmc-state.
       (define (church-make-initial-mcmc-state address store)
                                        ;(for-each display (list "capturing store, xrp-draws has length :" (length (store->xrp-draws store))
                                        ;                        " xrp-stats: " (length (store->xrp-stats store)) "\n"))
         ,(if *storethreading*
              '(list (make-mcmc-state store 'init-val address) store)
              ;;'(make-mcmc-state (cons (first store) (cdr store)) 'init-val address)))
              '(make-mcmc-state (make-store (make-addbox)
                                            (store->xrp-stats store)
                                            0.0
                                            0
                                            (store->enumeration-flag store)
                                            (make-addbox))
                                'init-val address)))

       (define (church-make-addressed-initial-mcmc-state address store start-address)
                                        ;(for-each display (list "capturing store, xrp-draws has length :" (length (store->xrp-draws store))
                                        ;                        " xrp-stats: " (length (store->xrp-stats store)) "\n"))
         ,(if *storethreading*
              '(list (make-mcmc-state store 'init-val start-address) store)
              ;;'(make-mcmc-state (cons (first store) (cdr store)) 'init-val start-address)))
              '(make-mcmc-state (make-store (store->xrp-draws store)
                                            (store->xrp-stats store)
                                            0.0
                                            (store->tick store)
                                            (store->enumeration-flag store)
                                            (store->with-proposer-calls store))
                                'init-val start-address)))
       
       ;;this is like church-make-initial-mcmc-state, obut flags the created state to init new xrp-draws at left-most element of support.
       ;;clears the xrp-draws since it is meant to happen when we begin enumeration (so none of the xrp-draws in store can be relevant).
       (define (church-make-initial-enumeration-state address store)
         ;;FIXME: storethreading.
         (make-mcmc-state (make-store '() (store->xrp-stats store) (store->score store) (store->tick store) #t (make-addbox))
                          'init-val address))

       ;;this is the key function for doing mcmc -- update the execution of a procedure, with optional changes to xrp-draw values.
       ;;  takes: an mcmc state, a normal-from-proc, and an optional list of interventions (which is is a list of xrp-draw new-value pairs to assert).
       ;;  returns: a new mcmc state and the bw/fw score of any creations and deletions.
       ;;must exit with store being the original store, which allows it to act as a 'counterfactual'. this is taken care of by wrapping as primitive (ie. non church- name).
       (define (add-interventions interv xrps)
         (let* ([new-addbox (pull-outof-addbox xrps (xrp-draw-address (first interv)))]
                [new-addbox (if (eq? (first new-addbox) #f) xrps (cdr new-addbox))]) ;;if intervention wasn't in addbox use original addbox
                ;;[db (pretty-print (list "going through interventions in cf-update" (cdr (pull-outof-addbox xrps (xrp-draw-address (first interv)))) (xrp-draw-address (first interv)) (equal? (cdr (pull-outof-addbox xrps (xrp-draw-address (first interv)))) (xrp-draw-address (first interv)))))])
           (add-into-addbox new-addbox
                            (xrp-draw-address (first interv))
                            (make-xrp-draw (xrp-draw-address (first interv))
                                           (cdr interv)
                                           (xrp-draw-name (first interv))
                                           (xrp-draw-proposer (first interv))
                                           (xrp-draw-ticks (first interv))
                                           'dummy-score ;;dummy score which will be replace on update.
                                           (xrp-draw-support (first interv))
                                           ))))
       
       (define (counterfactual-update state nfqp . interventions)
         (let* ((new-tick (+ 1 (store->tick (mcmc-state->store state))))
                ;;(db (if (> (length interventions) 1) (pretty-print (list "interventions size" (length interventions) "uncompressed-state xrp-draw number" (length (store->xrp-draws (mcmc-state->store state)))))))
                ;;[db (pretty-print (list "in the cfupdate" (store->xrp-stats (mcmc-state->store state))))]
                (interv-store (make-store (fold add-interventions
                                                (store->xrp-draws (mcmc-state->store state))
                                                interventions)
                                          (store->xrp-stats (mcmc-state->store state)) ;;NOTE: incremental differs here (adjust score for new values).
                                          0.0 ;;NOTE: incremental differs here ;;(store->score (mcmc-state->store state))
                                          new-tick ;;increment the generation counter.
                                          (store->enumeration-flag (mcmc-state->store state))
                                          (store->with-proposer-calls (mcmc-state->store state))))
                ;;(db (if (> (length interventions) 1) (pretty-print  (list "interv-store" (length (store->xrp-draws interv-store)))) '()))
               ;; (db (pretty-print (list "interv-store"  interv-store)))
                ;;application of the nfqp happens with interv-store, which is a fresh pair, so won't mutate original state.
                ;;after application the store must be captured and put into the mcmc-state.
                ;;[db (pretty-print (list "running the nfqp" interv-store))]
                ;; [db (if (equal? (second state) 'init-val)
                ;;         '()
                ;;         (if (or (equal? (mcmc-state->query-value state) 0) (equal? (mcmc-state->query-value state) 1))
                ;;             (pretty-print (list "inside cf-update...global mcmc-state score before:" (mcmc-state->score state) " interv score" (store->score interv-store)))
                ;;             (pretty-print (list "inside cf-update...local mcmc-state score before:" (mcmc-state->score state) " interv score" (store->score interv-store)))))]
                (ret ,(if *storethreading*
                          '(church-apply (mcmc-state->address state) interv-store nfqp '()) ;;return is already list of value + store.
                          '(list (church-apply (mcmc-state->address state) interv-store nfqp '()) interv-store) ;;capture store, which may have been mutated.
                          ))
                ;; [db (if (equal? (second state) 'init-val)
                ;;         '()
                ;;         (if (or (equal? (mcmc-state->query-value state) 0) (equal? (mcmc-state->query-value state) 1))
                ;;             (pretty-print (list "inside cf-update...mcmc-state score after:" (mcmc-state->score state) " interv score" (store->score interv-store)))
                ;;             (pretty-print (list "inside cf-update...local mcmc-state score before:" (mcmc-state->score state) " interv score" (store->score interv-store)))))]
                
                ;;[db (pretty-print "nfqp complete")]
                ;;(db (pretty-print (list "interv-store after update" (store->tick (mcmc-state->store state)) interv-store)))
;;                (db (repl ret))

                ;;(db (pretty-print (list "value" (rest (first ret)))))
                (value (first ret))
                (new-store (second ret))
                ;;(db (pretty-print (list "passing to clean-store" new-store)))
                (ret2 (if (store->enumeration-flag new-store)
                          (list new-store 0)
                          (clean-store new-store))) ;;FIXME!! need to clean out unused xrp-stats?

                (new-store (first ret2))
                ;;(db (pretty-print (list "store cleaned" new-store)))
                (cd-bw/fw (second ret2))
                (proposal-state (make-mcmc-state new-store value (mcmc-state->address state))))
           (list proposal-state cd-bw/fw)))

       ;;we need to pull out the subset of new-state xrp-draws that were touched on this pass,
       ;;at the same time we want to accumulate the bw score of these deleted xrp-draws and the fw score of any new ones.
       ;;FIXME: this doesn't play nice with addbox abstraction, and is linear time in the number of xrp-draws.
       ;;FIXME: this method won't work with caching since used xrp-draws may not get 'touched'...
       ;;FIXME: assumes new choices drawn from the conditional prior -- that's currently true but not general.
       (define (clean-store store)
         (let* ((state-tick (store->tick store))
                ;;(db (pretty-print (list "in clean-store" (length (store->xrp-draws store)))))
                (draws-bw/fw
                 (let loop ((draws (addbox->alist (store->xrp-draws store)))
                            (used-draws '())
                            (bw/fw 0.0))
                   (if (null? draws)
                       (list used-draws bw/fw)
                       (if (= (first (xrp-draw-ticks (cdar draws))) state-tick)
                           (if (null? (cdr (xrp-draw-ticks (cdar draws))))
                               ;;this was a new xrp-draw, accumulate fw prob:
                               (loop (cdr draws) (cons (car draws) used-draws) (- bw/fw
                                                                                  (xrp-draw-score (cdar draws)) ;;NOTE: incremental differs here
                                                                                  ))
                               ;;this xrp-draw existed already:
                               (loop (cdr draws) (cons (car draws) used-draws) bw/fw))
                           ;;this xrp-draw was not used in last update, drop it and accumulate bw prob:
                           (loop (cdr draws) used-draws (+ bw/fw
                                                           (xrp-draw-score (cdar draws)) ;;NOTE: incremental differs here
                                                           )))))))
           (list (make-store (alist->addbox (first draws-bw/fw))
                             (store->xrp-stats store)
                             (store->score store)
                             (store->tick store)
                             (store->enumeration-flag store)
                             (store->with-proposer-calls store))
                 (second draws-bw/fw))))


       ;;this function takes a church proc and a proposer to use for it, returns a wrapped proc that stores the call and details: address, xrp-draws, return value
       ;(define (church-with-proposer address store fn proposer)
       ;  'foo
       ;  )
         
         

       )
     )

   )
