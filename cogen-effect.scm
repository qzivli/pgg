;;; effect analysis

;;; debugging and trace aids
;;;(define *effect-display-level* 1)
(define-syntax debug-level
  (syntax-rules ()
    ((_ level arg ...)
     (if (>= *effect-display-level* level)
	 (begin arg ...)))))

(define (effect-analysis d* nr-of-ref-labels)
  (debug-level 1 (display "effect analysis:"))
  (set-labset-size! (+ 1 nr-of-ref-labels))
  (set! *access-vector* (make-vector (+ 1 nr-of-ref-labels) #f))
  (set! *initial-effects* '())
  (allocate-effect-variables-d* d*)
  (debug-level 1 (display " fixpointing"))
  (with-output-to-file "/tmp/effect-out.scm"
    (lambda () (effect-fixpoint)))
  (debug-level 1 (display " done") (newline)))

;;; need an access vector that maps labels back to expressions
(define *access-vector* 'undefined-access-vector)
(define (effect-label->type label)
  (node-fetch-type (full-ecr (annExprFetchType (vector-ref *access-vector* label)))))
(define (effect-for-each proc effect)
  (labset-for-each proc (effect->labset effect)))
;;;
(define (node-fetch-effect node)
  (type->effect (node-fetch-type (full-ecr node))))

(define-record effect
  (neighbors labset)
  (constraints #f))
;;; neighbors contains pointers to the super-effects
(define (effect-add-neighbor! esub esuper)
  (let ((n (effect->neighbors esub)))
    (if (not (memq esuper n))
	(effect->neighbors! esub (cons esuper n)))))

(define (allocate-effect-variables-d* d*)
  (for-each (lambda (d)
	      (allocate-effect-variables-t
	       (annDefFetchProcBTVar d))) d*)
  (for-each (lambda (d) (allocate-effect-variables-d d d*)) d*))

(define (allocate-effect-variables-d d d*)
  (allocate-effect-variables-e (annDefFetchProcBody d) d*))

(define (allocate-effect-variables-e e d*)
  (let loop ((e e))
    ;; (display (vector-ref e 1)) (newline)
    (let ((evar  (make-effect '() empty-labset)))
      (annExprSetEffect! e evar)
      (allocate-effect-variables-t (annExprFetchType e))
      (cond
       ((annIsVar? e)
	'nothing-to-do)
       ((annIsConst? e)
	'nothing-to-do)
       ((annIsCond? e)
	(let ((etest (loop (annFetchCondTest e)))
	      (ethen (loop (annFetchCondThen e)))
	      (eelse (loop (annFetchCondElse e))))
	  (effect-add-neighbor! etest evar)
	  (effect-add-neighbor! ethen evar)
	  (effect-add-neighbor! eelse evar)))
       ((annIsOp? e)
	(for-each (lambda (arg)
		    (effect-add-neighbor! (loop arg) evar))
		  (annFetchOpArgs e)))
       ((annIsCall? e)
	(for-each (lambda (arg) (effect-add-neighbor!
				 (loop arg) evar))
		  (annFetchCallArgs e))
	(let* ((name (annFetchCallName e))
	       (defn (annDefLookup name d*))
	       (node (full-ecr (annDefFetchProcBTVar defn)))
	       (etype (node-fetch-effect node)))
	  (effect-add-neighbor! etype evar)))
       ((annIsLet? e)
	(let* ((eheader (loop (annFetchLetHeader e)))
	       (ebody (loop (annFetchLetBody e))))
	  (effect-add-neighbor! eheader evar)
	  (effect-add-neighbor! ebody evar)))
       ;;(annIsVLambda? e)
       ((annIsLambda? e)
	(vector-set! *access-vector* (annFetchLambdaLabel e) e)
	(let* ((etype (node-fetch-effect (annExprFetchType e)))
	       (ebody (loop (annFetchLambdaBody e)))
	       (free (annFreeVars e))
	       (efree (apply append (map extract-references free)))
	       (efvar (make-effect (nubq efree) empty-labset)))
	  ;;; need to filter the global effects!
	  (effect->constraints! efvar ebody)
	  (effect-add-neighbor! ebody etype)))
       ((annIsApp? e)
	(for-each (lambda (arg) (effect-add-neighbor!
				 (loop arg) evar))
		  (annFetchAppRands e))
	(let ((rator (annFetchAppRator e)))
	  (effect-add-neighbor! (loop rator) evar)
	  (let ((etype (node-fetch-effect (annExprFetchType rator))))
	    (effect-add-neighbor! etype evar))))
       ((annIsCtor? e)
	(vector-set! *access-vector* (annFetchCtorLabel e) e)
	(for-each (lambda (arg) (effect-add-neighbor!
				 (loop arg) evar))
		  (annFetchCtorArgs e)))
       ((annIsSel? e)
	(effect-add-neighbor! (loop (annFetchSelArg e)) evar))
       ((annIsTest? e)
	(effect-add-neighbor! (loop (annFetchTestArg e)) evar))
       ((annIsRef? e)
	(vector-set! *access-vector* (annFetchRefLabel e) e)
	(effect-add-neighbor! (loop (annFetchRefArg e)) evar)
	(let* ((node (annExprFetchType e))
	       (lab  (annFetchRefLabel e))
	       (eref (make-effect '() (labset-singleton lab)))
	       (etype (node-fetch-effect node)))
	  (initial-effects-add! eref)
	  (effect-add-neighbor! eref evar)
	  (effect-add-neighbor! eref etype)))
       ((annIsDeref? e)
	(let ((arg (annFetchDerefArg e)))
	  (effect-add-neighbor! (loop arg) evar)
	  (let ((eref (node-fetch-effect (annExprFetchType arg))))
	    (effect-add-neighbor! eref evar))))
       ((annIsAssign? e)
	(vector-set! *access-vector* (annFetchAssignLabel e) e)
	(let* ((ref (annFetchAssignRef e))
	       (arg (annFetchAssignArg e)))
	  (effect-add-neighbor! (loop ref) evar)
	  (effect-add-neighbor! (loop arg) evar)
	  (let ((eref (node-fetch-effect (annExprFetchType ref))))
	    (effect-add-neighbor! eref evar))))
       ((annIsCellEq? e)
	(for-each (lambda (arg)
		    (effect-add-neighbor! (loop arg) evar))
		  (annFetchCellEqArgs e)))
       ((annIsEval? e)
	(effect-add-neighbor! (loop (annFetchEvalBody e)) evar)))
      ;; (display (annExprFetchTag e)) (newline)
      evar)))

(define (allocate-effect-variables-t node)
  (let loop ((node node) (seen '()))
    (if (memq node seen)
	'nothing-to-do
	(let* ((type (node-fetch-type (full-ecr node)))
	       (ctor (type->ctor type))
	       (effect (type->effect type)))
	  ;;(display (list 'allocate-effect-variables-t ctor effect))
	  (if effect
	      'nothing-to-do
	      (let ((seen (cons node seen)))
		(if (or (eq? ctor ctor-function)
			(eq? ctor ctor-reference)
			(eq? ctor ctor-top))
		    (type->effect! type (make-effect '() empty-labset)))
		(for-each (lambda (node) (loop node seen))
			  (type->args type))))))))

(define (extract-references var)
  (let ((node (annExprFetchType var)))
    (let loop ((node node) (seen '()))
      (if (memq node seen)
	  '()
      (let* ((type (node-fetch-type (full-ecr node)))
	     (ctor (type->ctor type)))
	(cond
	 ((eq? ctor ctor-function)
	  (list (type->effect type)))
	 ((eq? ctor ctor-reference)
	  (list (type->effect type)))
	 (else
	  (let ((seen (cons node seen)))
	    (apply append (map (lambda (node) (loop node seen))
			       (type->args type)))))))))))

(define (effect-singlestep)
  (let loop ((roots *initial-effects*) (change? #f))
    (if (null? roots)
	change?
	(let recur-a ((evar (car roots)))
	  (let recur ((n (effect->neighbors evar)))
	    (if (null? n)
		(loop (cdr roots) change?)
		(let* ((evarb (car n))
		       (constraints (effect->constraints evarb))
		       (labs (effect->labset evar))
		       (labs (if constraints
				 (labset-intersection
				  labs
				  (effect->labset constraints))
				 labs))
		       (labsb (effect->labset evarb)))
		    (if (labset-subset? labs labsb)
			(recur (cdr n))
			(begin (set! change? #t)
			       (debug-level
				2 (display (list (labset->list labs)
						 "|||"
						 (labset->list labsb)))
				(newline))
			       (effect->labset! evarb
						(labset-union labs labsb))
			       (recur-a evarb)
			       (recur (cdr n)))))))))))

(define (effect-fixpoint)
  (let loop ()
    (if (effect-singlestep)
	(loop))))

(define *initial-effects* '())
(define (initial-effects-add! evar)
  (set! *initial-effects* (cons evar *initial-effects*)))

(define (nubq evar*)
  (let loop ((ins evar*) (outs '()))
    (if (null? ins)
	outs
	(let ((in (car ins)))
	(if (memq in outs)
	    (loop (cdr ins) outs)
	    (loop (cdr ins) (cons in outs)))))))

