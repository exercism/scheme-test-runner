(import (chezscheme))

(define (output-results status tests output)
  (delete-file "results.json")
  (with-output-to-file "results.json"
    (lambda ()
      (json-write `((version . ,2)
                    (status . ,status)
                    (tests . ,tests)
                    (output . ,output))))))

(define (report-results chez guile)
  (if (zero? (+ (length chez) (length guile)))
    (output-results "fail" '() "Syntax error")
    (let ((choice (cond
                    ((null? guile) chez)
                    ((null? chez) guile)
                    (else (if (<= (failure-count chez) (failure-count guile))
                            chez
                            guile)))))
      (if (zero? (failure-count choice))
          (output-results "pass" (failure-messages choice) "")
          (output-results "fail" (failure-messages choice) "")))))

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
  (cond
    ((list? result)
      (let ((failures (filter failed-test? result)))
            (cons (length failures) (map test->message result))))
    (else '())))

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

(define json-write
  (let ()
    (define (write-ht vec p)
      (display "{" p)
      (do ((need-comma #f #t)
           (vec vec (cdr vec)))
          ((null? vec))
        (if need-comma
            (display ", " p)
            (set! need-comma #t))
        (let* ((entry (car vec))
               (k (car entry))
               (v (cdr entry)))
          (cond
           ((symbol? k) (write (symbol->string k) p))
           ((string? k) (write k p)) ;; for convenience
           (else (error "Invalid JSON table key in json-write" k)))
          (display ": " p)
          (write-any v p)))
      (display "}" p))

    (define (write-array a p)
      (display "[" p)
      (let ((need-comma #f))
        (for-each (lambda (v)
                    (if need-comma
                        (display ", " p)
                        (set! need-comma #t))
                    (write-any v p))
                  a))
      (display "]" p))

    (define (write-any x p)
      (cond
       ((null? x) (display "null" p))
       ((string? x) (write (if (eq? x "") 'null x) p))       
       ((number? x) (write x p))       
       ((boolean? x) (display (if x "true" "false") p))
       ((symbol? x) (write (if (eq? x 'null) 'null (symbol->string x))
                           p)) ;; for convenience       
       ((and (list? x)
             (pair? (car x))
             (not (pair? (caar x))))
        (write-ht x p))
       ((list? x) (write-array x p))
       (else (error "Invalid JSON object in json-write" x))))

    (lambda (x)
      (write-any x (current-output-port)))))

(let ((args (cdr (command-line))))
  (apply exercise args))
