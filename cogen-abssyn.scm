;;; abstract syntax for annotated programs
;;; definitions
;;; formals are #f if no formals are available
(define (annMakeDef name formals body)
  (vector 'DEF name formals body 'btvar 'evar #t))
(define (annMakeDefWithoutMemoization name formals body)
  (vector 'DEF name formals body 'btvar 'evar #f))
(define (annDefFetchProcName d)
  (vector-ref d 1)) 
(define (annDefFetchProcFormals d)
  (vector-ref d 2)) 
(define (annDefFetchProcBody d)
  (vector-ref d 3))
(define (annDefSetProcBody d body)
  (vector-set! d 3 body))
(define (annDefSetProcBTVar! d tv)
  (vector-set! d 4 tv))
(define (annDefFetchProcBTVar d)
  (vector-ref d 4))
(define (annDefFetchProcEVar d)
  (vector-ref d 5))
(define (annDefSetProcEVar! d ocs)
  (vector-set! d 5 ocs))
(define (annDefFetchProcAutoMemo d)
  (vector-ref d 6))
(define (annDefSetProcAutoMemo! d f)
  (vector-set! d 6 f))
(define (annDefLookup name d*)
  (let loop ((d* d*))
    (and (not (null? d*))
	 (let ((d (car d*)))
	   (if (equal? (annDefFetchProcName d) name)
	       d
	       (loop (cdr d*)))))))
;;; expressions
;;; general layout:
;;; #(tag sub-object level type memo effect)
(define (annMakeExpr tag sub-object)
  (vector tag sub-object 0 #f #f #f))
(define-syntax annExprFetchTag
  (syntax-rules ()
    ((_ e) (vector-ref e 0))))
(define (annExprSetTag! e t)
  (vector-set! e 0 t))
(define-syntax annExprFetchSubobject
  (syntax-rules ()
    ((_ e) (vector-ref e 1))
    ((_ e i) (vector-ref (vector-ref e 1) i))))
(define-syntax annExprSetSubobject!
  (syntax-rules ()
    ((_ e so) (vector-set! e 1 so))
    ((_ e i so) (vector-set! (vector-ref e 1) i so))))
(define (annExprFetchLevel e)
  (vector-ref e 2))
(define (annExprSetLevel! e lv)
  (vector-set! e 2 lv))
(define (annExprFetchType e)
  (vector-ref e 3))
(define (annExprSetType! e bt)
  (vector-set! e 3 bt))
(define (annExprFetchMemo e)
  (vector-ref e 4))
(define (annExprSetMemo! e bt)
  (vector-set! e 4 bt))
(define (annExprFetchEffect e)
  (vector-ref e 5))
(define (annExprSetEffect! e bt)
  (vector-set! e 5 bt))
;;; variable
(define (annMakeVar v)
  (annMakeExpr 'VAR v))
(define (annIsVar? e)
  (equal? 'VAR (annExprFetchTag e)))
(define (annFetchVar e)
  (annExprFetchSubobject e))
;;; constant
(define (annMakeConst c)
  (annMakeExpr 'CONST c))
(define (annIsConst? e)
  (equal? 'CONST (annExprFetchTag e)))
(define (annFetchConst e)
  (annExprFetchSubobject e))
;;; conditional
(define (annMakeCond e-cond e-then e-else)
  (annMakeExpr 'IF (vector e-cond e-then e-else)))
(define (annIsCond? e)
  (equal? 'IF (annExprFetchTag e)))
(define (annFetchCondTest e)
  (annExprFetchSubobject e 0))
(define (annFetchCondThen e)
  (annExprFetchSubobject e 1))
(define (annFetchCondElse e)
  (annExprFetchSubobject e 2))
;;; primitive operations
(define INTERNAL-IDENTITY (list '???lift))
(define (annMakeOp op args)
  (annMakeExpr 'OP (vector op args #t #f #f #f)))
(define (annMakeOpaqueOp op args)
  (annMakeExpr 'OP (vector op args #f #f #f #f)))
(define (annMakeFullOp op opaque property pp type args)
  (annMakeExpr 'OP (vector op args opaque property pp type)))
(define (annMakeOp1 opaque property pp type)
  (lambda (op args) (annMakeFullOp op opaque property pp type args)))
(define (annIsOp? e)
  (equal? 'OP (annExprFetchTag e)))
(define (annFetchOpName e)
  (annExprFetchSubobject e 0))
(define (annFetchOpArgs e)
  (annExprFetchSubobject e 1))
(define (annFetchOpDiscardability e)
  (annExprFetchSubobject e 2))
(define (annFetchOpProperty e)
  (annExprFetchSubobject e 3))
(define (annFetchOpPostprocessor e)
  (annExprFetchSubobject e 4))
(define (annFetchOpType e)
  (annExprFetchSubobject e 5))
;;; procedure call
(define (annMakeCall fname args)
  (annMakeExpr 'CALL (vector fname args)))
(define (annIsCall? e)
  (equal? 'CALL (annExprFetchTag e)))
(define (annFetchCallName e)
  (annExprFetchSubobject e 0))
(define (annFetchCallArgs e)
  (annExprFetchSubobject e 1))
;;; let, one variable
(define (annMakeLet v e1 e2)
  (annMakeExpr 'LET (vector v e1 e2 #f 0)))
(define (annIsLet? e)
  (equal? 'LET (annExprFetchTag e)))
(define (annFetchLetVar e)
  (annExprFetchSubobject e 0))
(define (annFetchLetHeader e)
  (annExprFetchSubobject e 1))
(define (annFetchLetBody e)
  (annExprFetchSubobject e 2))
(define (annFetchLetUnfoldability e)
  (annExprFetchSubobject e 3))
(define (annSetLetUnfoldability! e prop)
  (annExprSetSubobject! e 3 prop))
(define (annFetchLetUseCount e)
  (annExprFetchSubobject e 4))
(define (annSetLetUseCount! e count)
  (annExprSetSubobject! e 4 count))
;;; vlambda
(define (annMakeVLambda label fixed-formals var-formal body)
  (annMakeExpr 'VLAMBDA (vector fixed-formals var-formal body label #f)))
(define (annIsVLambda? e)
  (equal? 'VLAMBDA (annExprFetchTag e)))
(define (annFetchVLambdaFixedVars e)
  (annExprFetchSubobject e 0))
(define (annFetchVLambdaVar e)
  (annExprFetchSubobject e 1))
(define (annFetchVLambdaBody e)
  (annExprFetchSubobject e 2))
(define (annSetVLambdaBody! e body)
  (annExprSetSubobject! e 2 body))
(define (annFetchVLambdaLabel e)
  (annExprFetchSubobject e 3))
(define (annFetchVLambdaBTVars e)
  (annExprFetchSubobject e 4))
(define (annSetVLambdaBTVars! e btv)
  (annExprSetSubobject! e 4 btv))
;;; lambda
(define (annMakeLambda label formals body)
  (annMakeExpr 'LAMBDA (vector formals body label #f)))
(define (annIsLambda? e)
  (equal? 'LAMBDA (annExprFetchTag e)))
(define (annFetchLambdaVars e)
  (annExprFetchSubobject e 0))
(define (annFetchLambdaBody e)
  (annExprFetchSubobject e 1))
(define (annSetLambdaBody! e body)
  (annExprSetSubobject! e 1 body))
(define (annFetchLambdaLabel e)
  (annExprFetchSubobject e 2))
(define (annFetchLambdaBTVars e)
  (annExprFetchSubobject e 3))
(define (annSetLambdaBTVars! e btv)
  (annExprSetSubobject! e 3 btv))
;;; application
(define (annMakeApp rator rands)
  (annMakeExpr 'APPLY (vector rator rands)))
(define (annIsApp? e)
  (equal? 'APPLY (annExprFetchTag e)))
(define (annFetchAppRator e)
  (annExprFetchSubobject e 0))
(define (annFetchAppRands e)
  (annExprFetchSubobject e 1))
;;; constructor
(define (annMakeCtor ctor label desc args)
  (annMakeExpr 'CTOR (vector ctor desc args label)))
(define (annIsCtor? e)
  (equal? 'CTOR (annExprFetchTag e)))
(define (annFetchCtorName e)
  (annExprFetchSubobject e 0))
(define (annFetchCtorDesc e)
  (annExprFetchSubobject e 1))
(define (annFetchCtorArgs e)
  (annExprFetchSubobject e 2))
(define (annFetchCtorLabel e)
  (annExprFetchSubobject e 3))
;;; selector
(define (annMakeSel ctor-sel desc sel arg)
  (annMakeExpr 'SEL (vector ctor-sel desc sel arg)))
(define (annMakeSel1 ctor desc sel)
  (lambda (ctor-sel args)
    (annMakeSel ctor-sel desc sel (car args))))
(define (annIsSel? e)
  (equal? 'SEL (annExprFetchTag e)))
(define (annFetchSelName e)
  (annExprFetchSubobject e 0))
(define (annFetchSelDesc e)
  (annExprFetchSubobject e 1))
(define (annFetchSelComp e)
  (annExprFetchSubobject e 2))
(define (annFetchSelArg e)
  (annExprFetchSubobject e 3))
;;; constructor test
(define (annMakeTest ctor-test desc arg)
  (annMakeExpr 'TEST (vector ctor-test desc arg)))
(define (annMakeTest1 ctor desc)
  (lambda (ctor-test args) (annMakeTest ctor-test desc (car args))))
(define (annIsTest? e)
  (equal? 'TEST (annExprFetchTag e)))
(define (annFetchTestName e)
  (annExprFetchSubobject e 0))
(define (annFetchTestDesc e)
  (annExprFetchSubobject e 1))
(define (annFetchTestArg e)
  (annExprFetchSubobject e 2))
;;; reference creation:
(define (annMakeRef label arg)
  (annMakeExpr 'REF (vector label arg)))
(define (annIsRef? e)
  (equal? 'REF (annExprFetchTag e)))
(define (annFetchRefLabel e)
  (annExprFetchSubobject e 0))
(define (annFetchRefArg e)
  (annExprFetchSubobject e 1))
;;; dereferencing:
(define (annMakeDeref arg)
  (annMakeExpr 'DEREF arg))
(define (annIsDeref? e)
  (equal? 'DEREF (annExprFetchTag e)))
(define (annFetchDerefArg e)
  (annExprFetchSubobject e))
;;; assignment
(define (annMakeAssign label ref arg)
  (annMakeExpr 'ASSIGN (vector label ref arg)))
(define (annIsAssign? e)
  (equal? 'ASSIGN (annExprFetchTag e)))
(define (annFetchAssignLabel e)
  (annExprFetchSubobject e 0))
(define (annFetchAssignRef e)
  (annExprFetchSubobject e 1))
(define (annFetchAssignArg e)
  (annExprFetchSubobject e 2))
;;; pointer equality
(define (annMakeCellEq args)
  (annMakeExpr 'CELLEQ args))
(define (annIsCellEq? e)
  (equal? 'CELLEQ (annExprFetchTag e)))
(define (annFetchCellEqArgs e)
  (annExprFetchSubobject e))
;;; special form:
(define (annMakeEval eval args)
  (annMakeExpr 'EVAL (vector (car args) 0 #f)))
(define (annIsEval? e)
  (equal? 'EVAL (annExprFetchTag e)))
(define (annFetchEvalBody e)
  (annExprFetchSubobject e 0))
(define (annFetchEvalDiff e)
  (annExprFetchSubobject e 1))
(define (annSetEvalDiff! e ld)
  (annExprSetSubobject! e 1 ld))
(define (annFetchEvalQuoted e)
  (annExprFetchSubobject e 2))
(define (annSetEvalQuoted! e b)
  (annExprSetSubobject! e 2 b))
;;; subject to discussion:
;;; lift
(define (annIntroduceLift e lv ld)
  (let ((body (list->vector (vector->list e))))
    (annExprSetTag! e 'LIFT)
    (annExprSetLevel! e lv)
    (annExprSetSubobject! e (vector ld body))))
(define (annIsLift? e)
  (equal? 'LIFT (annExprFetchTag e)))
(define (annSetLiftDiff! e ld)
  (annExprSetSubobject! e 0 ld))
(define (annFetchLiftDiff e)
  (annExprFetchSubobject e 0))
(define (annFetchLiftBody e)
  (annExprFetchSubobject e 1))
;;; subject to discussion:
;;; memoization
(define (annIntroduceMemo e bt lv vars)
  (annIntroduceMemo1 e bt lv vars (list->vector (vector->list e))))
(define (annIntroduceMemo1 e bt lv vars body)    
  (annExprSetTag! e 'MEMO)
  (annExprSetLevel! e bt)
  (annExprSetSubobject! e (vector lv vars body)))
(define (annMakeMemo body)
  (annMakeExpr 'MEMO (vector 0 '() body)))
(define (annIsMemo? e)
  (equal? 'MEMO (annExprFetchTag e)))
(define (annSetMemoVars! e args)
  (annExprSetSubobject! e 1 args))
(define (annFetchMemoVars e)
  (annExprFetchSubobject e 1))
(define (annFetchMemoBody e)
  (annExprFetchSubobject e 2))
(define (annFetchMemoLevel e)
  (annExprFetchSubobject e 0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (ann-maybe-coerce e)
  (if *abssyn-maybe-coerce*
      (annMakeOp INTERNAL-IDENTITY (list e))
      e))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (annFreeVars e)
  (let loop ((e e))
    (cond
     ((annIsVar? e)
      (list e))
     ((annIsConst? e)
      '())
     ((annIsCond? e)
      (var-union (loop (annFetchCondTest e))
		 (loop (annFetchCondThen e))
		 (loop (annFetchCondElse e))))
     ((annIsOp? e)
      (apply var-union (map loop (annFetchOpArgs e))))
     ((annIsCall? e)
      (apply var-union (map loop (annFetchCallArgs e))))
     ((annIsLet? e)
      (var-union (loop (annFetchLetHeader e))
		 (var-difference (loop (annFetchLetBody e))
				 (list (annFetchLetVar e)))))
     ((annIsVLambda? e)
      (var-difference (loop (annFetchVLambdaBody e))
		      (cons (annFetchVLambdaVar e)
			    (annFetchVLambdaFixedVars e))))
     ((annIsLambda? e)
      (var-difference (loop (annFetchLambdaBody e))
		      (annFetchLambdaVars e)))
     ((annIsApp? e)
      (apply var-union (cons (loop (annFetchAppRator e))
			     (map loop (annFetchAppRands e)))))
     ((annIsCtor? e)
      (apply var-union (map loop (annFetchCtorArgs e))))
     ((annIsSel? e)
      (loop (annFetchSelArg e)))
     ((annIsTest? e)
      (loop (annFetchTestArg e)))
     ((annIsRef? e)
      (loop (annFetchRefArg e)))
     ((annIsDeref? e)
      (loop (annFetchDerefArg e)))
     ((annIsAssign? e)
      (var-union (loop (annFetchAssignRef e))
		 (loop (annFetchAssignArg e))))
     ((annIsCellEq? e)
      (apply var-union (map loop (annFetchCellEqArgs e))))
     ((annIsLift? e)
      (loop (annFetchLiftBody e)))
     ((annIsEval? e)
      (loop (annFetchEvalBody e)))
     ((annIsMemo? e)
      (loop (annFetchMemoBody e)))
     (else
      (error 'annFreeVars "Unknown syntax construction")))))
 
(define (var-member v vs)
  (let ((vname (annFetchVar v)))
    (var-member-1 vname vs)))
(define (var-member-1 vname vs)
    (let loop ((vs vs))
      (if (null? vs)
	  #f
	  (or (equal? (annFetchVar (car vs)) vname)
	      (loop (cdr vs))))))

(define (var-union . args)
  (if (null? args)
      '()
      (let ((s1 (car args))
	    (s2 (apply var-union (cdr args))))
	(let loop ((s1 s1))
	  (if (null? s1)
	      s2
	      (if (var-member (car s1) s2)
		  (loop (cdr s1))
		  (cons (car s1) (loop (cdr s1)))))))))
(define (var-member-2 v vv)
  (let ((vname (annFetchVar v)))
    (let loop ((vv vv))
      (if (null? vv)
	  #f
	  (or (equal? vname (car vv))
	      (loop (cdr vv))))))) 

(define (var-difference vs1 vv2)
  (let  loop ((vs1 vs1))
    (if (null? vs1)
	'()
	(if (var-member-2 (car vs1) vv2)
	    (loop (cdr vs1))
	    (cons (car vs1) (loop (cdr vs1)))))))
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (annExprTerminates? e)
  (let loop ((e e))
    (cond
     ((annIsVar? e)
      #t)
     ((annIsConst? e)
      #t)
     ((annIsCond? e)
      (and (loop (annFetchCondTest e))
	   (loop (annFetchCondThen e))
	   (loop (annFetchCondElse e))))
     ((annIsOp? e)
      (and (annFetchOpDiscardability e)
	   (and-map loop (annFetchOpArgs e))))
     ((annIsCall? e)
      #f)
     ((annIsLet? e)
      (and (loop (annFetchLetHeader e))
	   (loop (annFetchLetBody e))))
     ((annIsVLambda? e)
      #t)
     ((annIsLambda? e)
      #t)
     ((annIsApp? e)
      #f)
     ((annIsCtor? e)
      (and-map loop (annFetchCtorArgs e)))
     ((annIsSel? e)
      (loop (annFetchSelArg e)))
     ((annIsTest? e)
      (loop (annFetchTestArg e)))
     ((annIsLift? e)
      #t)
     ((annIsRef? e)
      #f)
     ((annIsDeref? e)
      #f)
     ((annIsAssign? e)
      #f)
     ((annIsCellEq? e)
      (and-map loop (annFetchCellEqArgs e)))
     ((annIsEval? e)
      (loop (annFetchEvalBody e)))
     ((annIsMemo? e)
      (loop (annFetchMemoBody e)))
     (else
      (error 'annExprTerminates? "Unknown syntax construction")))))
