;;; cogen-driver.scm
;;; driver for the compiler generator

;;; copyright � 1996, 1997, 1998 by Peter Thiemann
;;; non-commercial use is free as long as the original copright notice
;;; remains intact

;;; the main entry point
;;; `job-file' contains a list of file names which contain the source
;;; code and declarations for the current project (can also be the
;;; list of filenames itself)
;;; `skeleton' is a prototype call with arguments replaced by their
;;; binding times 
;;; proposal for specifying partially static input: a list containing
;;; bt-prototypes for the expected constructors, e.g.:
;;; '((anil) (acons d *)) means "expect a list with static spine
;;; and dynamic elements"; it is a shorthand for the recursive type 
;;; \mu \alpha . ANIL + CONS d \alpha.

(define *macro-source*
  (file->list
   (namestring "scheme-standard-macros.scm"
	       (file-name-directory (%file-name%))
	       #f)))

(define (cogen-driver job-file/files skeleton . options)
  (let* ((source-files
	  (if (string? job-file/files)
	      (map symbol->string (file->list job-file/files))
	      job-file/files))
	 (full-source
	  (append *macro-source*
		  (apply append (map file->list source-files)))))
    (call-with-values
     (lambda ()
       (scheme-desugar full-source))
     (lambda (def-function* rejected*)
       ;; (writelpp def-function* "/tmp/def1.scm")
       (let* ((symbol-table (process-type-declarations rejected*))
	      (abssyn (scheme->abssyn-d def-function* symbol-table))
	      (d* (bta-run abssyn
			   symbol-table
			   skeleton
			   rejected*)))
	 (perform-termination-analysis d*)
	 (generate-d d*)
	 (process-options options skeleton rejected*)
	 (append (filter (lambda (def) (eq? (car def) 'define-data))
			 rejected*)
		 *generating-extension*)))))) 

(define (process-options options skeleton rejected*)
  (let* ((user-open '())
	 (user-files '())
	 (user-export '())
	 (user-options '()))
    (let loop ((options options))
      (and (not (null? options))
	   (let ((option (car options)))
	     (cond
	      ((pair? option)
	       (case (car option)
		 ((export)
		  (set! user-export (append user-export (cdr option))))
		 ((open)
		  (set! user-open (append user-open (cdr option))))
		 ((files)
		  (set! user-files (append user-files (cdr option))))
		 (else
		  (set! user-options (cons option user-options))))
	       (loop (cdr options)))
	      ((string? option)
	       (let* ((suffix-stripped (strip-path-suffix option))
		      (option (strip-path-prefix suffix-stripped))
		      (outfile-name (string-append suffix-stripped ".scm"))
		      (config-name  (string-append suffix-stripped ".config.scm")))
		 (with-output-to-file outfile-name
		   (lambda ()
		     (for-each (lambda (def)
				 (if (eq? (car def) 'define-data)
				     (p def)))
			       rejected*)
		     (for-each p *generating-extension*)))
		 (with-output-to-file config-name
		   (lambda ()
		     (let ((interface-sym
			    (string->symbol (string-append option "-interface")))
			   (structure-sym
			    (string->symbol option))
			   (main-sym
			    '$goal))
		       (p
			`(define-interface ,interface-sym
			   (export ,main-sym ,@user-export)))
		       (p
			`(define-structure ,structure-sym ,interface-sym
			   (open scheme signals define-data pgg-library
				 ,@user-open)
			   ,@(reverse user-options)
			   (files ,@user-files ,structure-sym))))))))))))))

;;; TO DO:
;;; - error recognition & handling
