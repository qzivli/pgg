;;; cogen-completer.scm

;;; copyright � 1996, 1997, 1998 by Peter Thiemann
;;; non-commercial use is free as long as the original copright notice
;;; remains intact

(define-syntax _complete
  (syntax-rules ()
    ((_complete body)
     (let ((var (make-residual-variable (gensym-local 'mlet))))
       (shift k (make-residual-let-trivial var body (k var)))))))

(define-syntax _complete-no-result
  (syntax-rules ()
    ((_complete-no-result body)
     (let ((var (make-residual-variable (gensym-local 'mlet))))
       (shift k (make-residual-begin body (k var)))))))

(define-syntax _complete-serious
  (syntax-rules ()
    ((_complete-serious proc args)
     (let ((var (make-residual-variable (gensym-local 'mlet))))
       (shift k (make-residual-let-serious
		 var proc args 
		 (k var)))))))

(define-syntax _complete-serious-apply
  (syntax-rules ()
    ((_complete-serious-apply proc arg)
     (let ((var (make-residual-variable (gensym-local 'mlet))))
       (shift k (make-residual-let-serious-apply
		 var proc arg
		 (k var)))))))

(define-syntax _complete-serious-no-result
  (syntax-rules ()
    ((_complete-serious-no-result proc args)
     (let ((var (make-residual-variable (gensym-local 'mlet))))
       (shift k (make-residual-begin (apply make-residual-call proc (list args))
				     (k var)))))))

(define-syntax _complete-serious-apply-no-result
  (syntax-rules ()
    ((_complete-serious-apply-no-result proc arg)
     (let ((var (make-residual-variable (gensym-local 'mlet))))
       (shift k (make-residual-begin (make-residual-apply proc arg)
				     (k var)))))))

(define-syntax _complete-maybe
  (syntax-rules ()
    ((_complete-serious body)
     (let ((value body))
       (if (or (symbol? value) (number? value))
	   value
	   (let ((var (make-residual-variable (gensym-local 'mlet))))
	     (shift k (make-residual-let-serious var (car value) (cdr value)
						 (k var)))))))))

