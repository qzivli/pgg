;;; $Id$
;;; projection functions for memoization
;;; parameterized over `result'
;;; $Log$
;;; Revision 1.3  1995/10/23 16:52:57  thiemann
;;; continuation based reduction works
;;;


;;; code that must be executed at run time of a static lambda or
;;; constructor with dynamic free variables
;;; improvements:
;;; - specialize this guy wrt `label' and `bts', as well
;;;   as project-static, project-dynamic, and clone-dynamic!
;;; - use delay/force to memoize project-static and project-dynamic
;;;
;;; static-constructor : Ident \times (2Value^* -> (K Code)^* -> K
;;; Code) \times 2Value^* \times BT^* -> Value
(define (static-constructor ctor closed-value vvs bts)
  ;; (let ((closed-value (lambda fvs (lambda (arg) body)))) ...)
  (let ((ctor-vvs (cons ctor vvs)))
     (lambda (what)
       (cond
	((equal? what 'value)
	 (apply closed-value vvs))
	((equal? what 'static)
	 (project-static ctor-vvs bts))
	((equal? what 'dynamic)
	 (project-dynamic ctor-vvs bts))
	((equal? what 'clone)
	 (static-constructor ctor
			     closed-value
			     (cdr (clone-dynamic ctor-vvs bts))
			     bts)))))) 

;;; extract the static parts out of a partially static value which
;;; starts with some static tag and the rest of which is described by
;;; the binding times in bt-args
(define (project-static value bt-args)
  (cons (car value)
	(let loop ((values (cdr value))
		   (bt-args bt-args))
	  (if (null? values)
	      '()
	      (let ((skeleton (loop (cdr values)
				    (cdr bt-args))))
		(if (= 0 (car bt-args))
		    (let ((s-value (car values)))
		      (if (procedure? s-value)
			  (append (s-value 'STATIC) skeleton)
			  (cons s-value skeleton)))
		    skeleton))))))

;;; extract the dynamic parts of value
(define (project-dynamic value bt-args)
  (let* ((values-by-bt
	  (project-dynamic-level (cdr value) bt-args 0))
	 (nested-dynamics
	  (let loop ((values (car values-by-bt)))
	    (if (null? values)
		'()
		(if (procedure? (car values))
		    (multi-append ((car values) 'DYNAMIC)
				  (loop (cdr values)))
		    (loop (cdr values)))))))
    (multi-append nested-dynamics (cdr values-by-bt)))) 

;;; return `values' grouped according to `bt-args' starting with `level'
(define (project-dynamic-level values bt-args level)
  (let loop ((values values)
	     (bt-args bt-args)
	     (rvalues '())
	     (rbt-args '()))
    (if (null? values)
	(if (null? rvalues)
	    (list '())
	    (cons '()
		  (project-dynamic-level (reverse rvalues)
					 (reverse rbt-args)
					 (+ level 1))))
	(if (= level (car bt-args))
	    (let ((values-by-bt
		   (loop (cdr values) (cdr bt-args) rvalues rbt-args)))
	      (cons (cons (car values) (car values-by-bt))
		    (cdr values-by-bt)))
	    (loop (cdr values) (cdr bt-args)
		  (cons (car values) rvalues) (cons (car bt-args)
						    rbt-args))))))

;;; clone the dynamic parts of a list of values 
;;; return a value with identical static skeleton, but all dynamic
;;; parts replaced by a fresh variable
(define (clone-dynamic value bts)
  (cons (car value)
	(let loop ((values (cdr value)) (bts bts))
	  (if (null? values)
	      '()
	      (let ((skeleton (loop (cdr values) (cdr bts))))
		(if (= 0 (car bts))
		    (let ((s-value (car values)))
		      (if (procedure? s-value)
			  (cons (s-value 'CLONE) skeleton)
			  (cons s-value skeleton)))
		    (cons (gensym 'clone) skeleton)))))))

;;; (multi-append x y) is almost like (map append x y) except when the
;;; lists x and y have different lengths in which case the result has
;;; the length of the longest argument list
(define (multi-append xss yss)
  (if (pair? xss)
      (let ((xs (car xss)))
	(if (pair? yss)
	    (let ((ys (car yss)))
	      (cons (append xs ys)
		    (multi-append (cdr xss) (cdr yss))))
	    xss))
      yss)) 

;;; reconstruct binding times from a list of value blocks
(define (binding-times blocks)
  (let loop ((blocks blocks) (i 0))
    (if (null? blocks)
	'()
	(let inner-loop ((values (car blocks)))
	  (if (null? values)
	      (loop (cdr blocks) (+ i 1))
	      (cons i (inner-loop (cdr values))))))))

