(import (chezscheme))

(define (report-results chez guile)
  (let ((results (failure-messages
		  (if (< (failure-count chez) (failure-count guile))
		      chez
		      guile))))
    (pretty-print results)
    (newline)))

;; read s-expression from process stdout
(define (process->scheme command)
  (let-values (((out in id) (apply values (process command))))
    (let ((result (read out)))
      (close-port out)
      (close-port in)
      result)))

;; try to run solution for both guile and chez. report-results selects
;; run with fewest failures.
(define (exercise slug input-directory output-directory)
  (let ((chez-cmd "scheme --script test.scm --docker")
	(guile-cmd "guile test.scm --docker"))
    (parameterize ((cd input-directory))
      (let ((chez-result (convert (process->scheme chez-cmd)))
	    (guile-result (convert (process->scheme guile-cmd))))
	(parameterize ((cd output-directory))
	  (report-results chez-result guile-result))))))

(define (failed-test? test-result)
  (eq? 'fail (car test-result)))

(define (failure-count result)
  (car result))

(define (failure-messages result)
  (cdr result))

;; massage result of tests to desired format
(define (convert result)
  (let ((failures (filter failed-test? result)))
    (cons (length failures) (map test->message result))))

(define (test->message result)
  (let ((messages (cdr result)))
    (case (car result)
      ((fail)
       `((name . ,(cdr (assoc 'description messages)))
	 (status . "fail")
	 (output . ,(cdr (assoc 'stdout messages)))))
      ((pass)
       `((name . ,(cdr (assoc 'description messages)))
	 (status . "pass")
	 (output . ,(cdr (assoc 'stdout messages)))))
      (else 'test->message "unexpected result shape" result))))

(let ((args (cdr (command-line)))) ;; cdr because this file appears as first argument
  (apply exercise args))
