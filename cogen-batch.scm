;; cogen-batch.scm:
;; Run the cogen and generating extensions in batch mode
;; needs big-scheme, i/o, handle, conditions
;; pp, and fname.scm (or scsh, for that matter ...)

(define cogen-usage-text
'("Usage:"
  "Explain me:"
  "cps-mcogen ( --help | -h )"
  ""
  "just create a generating extension:"
  "cps-mcogen ( -c callpat | --call-pattern=callpat )"
  "           [ -o outfile ] [ --output=outfile ]"
  "           [ -v ] [ --verbose ]"
  "           subjectfile ..."
  ""
  "do everything:"
  "cps-mcogen ( -c callpat | --call-pattern=callpat )"
  "           ( -i infile | --input=infile )"
  "           [ -p goalproc ] [ --goal-proc=goalproc ]"
  "           [ -s supportfile+ ] [ --support=supportfile+ ]"
  "           [ -o outfile ] [ --output=outfile ]"
  "           [ -v ] [ --verbose ]"
  "           subjectfile ..."
  ""
  "specialize with pre-fabricated generating extension or later stage:"
  "cps-mcogen ( -i infile | --input=infile )"
  "           [ -p goalproc ] [ --goal-proc=goalproc ]"
  "           [ -s supportfile+ ] [ --support=supportfile+ ]"
  "           [ -o outfile ] [ --output=outfile ]"
  "           [ -v ] [ --verbose ]"
  "           genextfile ..."))

(define (cogen-display-usage)
  (for-each (lambda (line)
	      (display line) (newline))
	    cogen-usage-text))

(define cogen-options
  '(("help" "h" help)
    ("v" "verbose" verbose)
    ("c" "call-pattern" parameter call-pattern)
    ("i" "input" parameter accumulates splits input)
    ("o" "output" parameter output)
    ("p" "goal-proc" parameter goal-proc)
    ("s" "support" parameter accumulates splits support)))

(define scheme-file-suffixes '(".scm" ".ss"))
(define input-file-suffixes '(".dat"))
(define cogen-generating-extension-file-suffix "-genext")

(define cogen-stage-prefix ";; ")

(define (canonical-genext-name name)
  (call-with-values
   (lambda ()
     (parse-file-name name))
   (lambda (dir base suffix)
     (string-append dir base cogen-generating-extension-file-suffix suffix))))

(define (maybe-sans-suffix string suffix)
  (let ((length (string-length string))
	(suffix-length (string-length suffix)))
    (if (and (>= length suffix-length)
	     (string=? (substring string
				  (- length suffix-length) length)
		       suffix))
	(substring string 0 (- length suffix-length))
	string)))

(define (canonical-residual-name name inputs)
  (call-with-values
   (lambda ()
     (parse-file-name name))
   (lambda (dir base suffix)
     (let ((base (maybe-sans-suffix 
		  base cogen-generating-extension-file-suffix)))
       (string-append
	dir base
	(apply string-append
	       (map (lambda (input)
		      (string-append
		       "-"
		       (file-name-sans-extension
			(file-name-nondirectory input))))
		    inputs))
	suffix)))))

(define (read-line . arg)
  (let* ((port (if (null? arg) (current-input-port) (car arg)))
	 (char (read-char port)))
    (if (eof-object? char)
	char
	(do ((char char (read-char port))
	     (clist '() (cons char clist)))
	    ((or (eof-object? char) (char=? #\newline char))
	     (list->string (reverse clist)))))))

(define (read-memo-info)
  (let* ((line (read-line))
	 (line-length (string-length line))
	 (prefix-length (string-length cogen-stage-prefix)))

    (if (or (< line-length prefix-length)
	    (not (string=? cogen-stage-prefix (substring line 0 prefix-length))))
	(error "invalid memo template: ~a" line))

    (let* ((memo-stuff (substring line prefix-length line-length))
	   (port (make-string-input-port memo-stuff))
	   (id (read port))
	   (stuff (read port)))
      (values id stuff))))

(define (pp-list l . args)
  (for-each (lambda (x)
	      (apply pp x args))
	    l))

(define (cogen-make-generating-extension files pattern)
  (let ((residual-program (cogen-driver files pattern)))
    (values residual-program
	    *support-code*)))

(define (cogen-run-generating-extension pattern input-parameters)
  (let ((template
	 (start-memo-internal
	  1
	  '$goal
	  (eval '$goal (interaction-environment))
	  pattern
	  input-parameters)))
    (values
     template
     *residual-program*
     *support-code*)))

(define (cogen-run-later-stage memo-template input-parameters)
  (let ((next-memo-template
	 (nextlevel memo-template input-parameters)))
    (values
     next-memo-template
     *residual-program*
     *support-code*)))

(define (cogen-main argv)
  (call-with-current-continuation
   (lambda (exit)

     (with-handler

      (lambda (condition decline)
	(decline)
	(if (error? condition)
	    (apply format (current-error-port) (condition-stuff condition)))
	(exit 1))

      (lambda ()
	(call-with-values
	 (lambda ()
	   (with-handler
	    ;; we expect only errors here ...
	    (lambda (condition decline)
	      (apply format (current-error-port) (condition-stuff condition))
	      (cogen-display-usage)
	      (exit 1))
	    (lambda ()
	      (get-options cogen-options argv))))

	 (lambda (options files)

	   ;; mode 0
	   (if (assq 'help options)
	       (begin
		 (cogen-display-usage)
		 (exit 0)))
	   
	   (if (null? files)
	       (error "No input files specified.~%"))

	   (let ((verbose? (assq 'verbose options))
		 (the-genext #f)
		 (the-memo-template #f)
		 (the-bt-pattern #f))
	  
	     (define (maybe-format . l)
	       (if verbose?
		   (begin 
		     (apply format #t l)
		     (force-output (current-output-port)))))

	     ;; mode 1 or 2---make a generating extension
	     (if (assq 'call-pattern options)
		 (begin
		   (maybe-format "Creating a generating extension~%")
		   (let* ((pattern-string
			   (cdr (assq 'call-pattern options)))
			  (pattern
			   (read (make-string-input-port pattern-string))))

		     (call-with-values
		      (lambda ()
			(maybe-format "Computing the generating extension~%")
			(cogen-make-generating-extension files pattern))
		      (lambda (genext support-code)
			(if (assq 'input options)
			    ;; specialize also---later
			    (begin
			      (set! the-genext (append genext support-code))
			      (set! the-bt-pattern (cdr pattern)))
			    ;; just write out the generating extension
			    (let ((genext-name
				   (if (assq 'output options)
				       (cdr (assq 'output options))
				       (canonical-genext-name (car files)))))
			      (maybe-format "Writing generating extension into ~A~%"
					    genext-name)
			      (with-output-to-file
				  genext-name
				(lambda ()
				  (format #t "~a~a ~s~%~%"
					  cogen-stage-prefix
					  'bt-pattern
					  (cdr pattern))
				  (pp-list genext)
				  (if (not (null? support-code))
				      (format #t "~%;; Supporting definitions:~%"))
				  (pp-list support-code))))))))))

	     ;; mode 2 or 3---specialize something
	     (if (assq 'input options)
		 (let ((input-files (cdr (assq 'input options))))

		   (maybe-format "Running a generating extension~%")

		   (if (assq 'support options)
		       (begin
			 (maybe-format "Loading support code~%")
			 (for-each (lambda (support-file)
				     (maybe-format "Loading ~A~%" support-file)
				     (load support-file))
				   (cdr (assq 'support options)))))

		   (maybe-format "Loading generating extension ")
		   (if (assq 'call-pattern options)
		       ;; we have one in memory
		       (begin
			 (maybe-format "from memory~%")
			 (load-program the-genext))
		       (begin
			 (maybe-format "from files~%")
			 (call-with-values
			  (lambda ()
			    (with-input-from-file
				(car files)
			      read-memo-info))
			  (lambda (id stuff)
			    (if (eq? 'bt-pattern id)
				(set! the-bt-pattern stuff)
				(set! the-memo-template stuff))))
			 (for-each (lambda (file)
				     (maybe-format "Loading ~A~%" file)
				     (load file))
				   files)))

		   (let ((input-parameters
			  (begin
			    (maybe-format "Parsing input from files~%")
			    (let loop ((input-files input-files))
			      (if (null? input-files)
				  '()
				  (begin
				    (maybe-format "Parsing ~A~%" (car input-files))
				    (append (file->list (car input-files))
					    (loop (cdr input-files))))))))
			 (goal (if (assq 'goal-proc options)
				   (cdr (assq 'goal-proc options))
				   '$goal))
			 (residual-program-name
			  (if (assq 'output options)
			      (cdr (assq 'output options))
			      (canonical-residual-name (car files) input-files))))
		     
		     (maybe-format "Specializing with goal ~A~%" goal)
		     (call-with-values
		      (lambda ()
			(if the-bt-pattern
			    (cogen-run-generating-extension the-bt-pattern
							    input-parameters)
			    (cogen-run-later-stage the-bt-pattern
						   input-parameters)))
		      (lambda (memo-template code support-code)
			(maybe-format "Writing residual program into ~A~%"
				      residual-program-name)
			(with-output-to-file
			    residual-program-name
			  (lambda ()
			    (format #t "~a~a ~s~%~%"
				    cogen-stage-prefix
				    'memo-template
				    memo-template)
			    (pp-list code)
			    (if (not (null? support-code))
				(format #t "~%;; Supporting definitions:~%"))
			    (pp-list support-code))))))))

	     (exit 0)))))))))
