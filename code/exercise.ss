(import (chezscheme))

(define (legacy-output-results status tests output)
  (delete-file "results.json")
  (with-output-to-file "results.json"
    (lambda ()
      (json-write `((version . ,2)
                    (status . ,status)
                    (tests . ,tests)
                    (output . ,output))))))

(define legacy-report-results
  (let ((pass-or-fail
         (lambda (result)
           (legacy-output-results
            (or (and (zero? (legacy-failure-count result)) "pass") "fail")
            (failure-messages result) ""))))
    (lambda (chez guile)
      (cond
       ((andmap null? `(,chez ,guile))
        (output-results "fail" '() "Syntax error"))
       (else
        (if (not (null? chez)) (pass-or-fail chez)
            (pass-or-fail guile)))))))

(define (write-results r)
  (delete-file "results.json")
  (with-output-to-file "results.json"
    (lambda () (json-write r))))

(define (result-ok? result)
  (eq? 'ok (cdr (assoc 'status result))))

(define (test-result? results)
  (or (eq? 'pass (car results))
      (eq? 'fail (car results))))

(define (get-tests results)
  (filter test-result? results))

;; If x is bad return y
;; If y is bad return x
;; Otherwise return the results with the fewest errors.
(define (choose-results x y)
  (call/cc
   (lambda (k)
     (unless (result-ok? x) (k y))
     (unless (result-ok? y) (k x))
     (if (<= (failure-count x)
             (failure-count y))
         x y))))

(define (report-results chez guile)
  (let ((results (choose-results chez guile)))
    (write-results
     `((version . 2)
       . ,(call/cc
           (lambda (k)
             (unless (parse-ok? results)
               (k `((status . error)
                    (message . ,(cdr (assoc 'message results))))))
             `((status
                . (if (zero? (failure-count results)) 'pass 'fail))
               (tests
                (map report-test (get-tests results))))))))))

;; read s-expression from process stdout
(define (process->scheme command)
  (let-values (((out in id) (apply values (process command))))
    (let ((result (read out)))
      (close-port out)
      (close-port in)
      result)))

(define (scheme->string o)
  (with-output-to-string
    (lambda ()
      (write o))))

(define (process-condition e)
  (if (not (condition? e)) e
      `(error
        ,(if (who-condition? e) (condition-who e)
             'unknown)
        ,(condition-message e)
        ,@(if (not (irritants-condition? e)) '()
              (condition-irritants e)))))

(define (cdr-or x y)
  (if (pair? x) (cdr x) y))

;; try to run solution for both guile and chez. report-results selects
;; run with fewest failures.
(define (exercise slug input-directory output-directory)
  (let ((chez-cmd "scheme --script test.scm --docker")
        (guile-cmd "guile test.scm --docker"))
    (parameterize ((cd input-directory))
      (let ((chez-result (process->scheme chez-cmd))
            (guile-result (process->scheme guile-cmd)))
        (parameterize ((cd output-directory))
          (call/cc
           (lambda (k)
            (with-exception-handler
                (lambda (e)
                  (k
                   (write-results
                    `((version . 2)
                      (status . error)
                      (message . "Syntax error")
                      (tests)))))
              (lambda ()
                (case (or (cdr-or (assoc 'test-lib-version chez-result) 0)
                          (cdr-or (assoc 'test-lib-version guile-result) 0))
                  (0 (legacy-report-results (convert chez-result)
                                            (convert guile-result)))
                  (else
                   (report-results chez-result guile-result))))))))))))

(define (failure-count results)
  (fold-left (lambda (count x)
               (if (failed-test? x) (+ count x)
                   count))
             0 results))

(define (failed-test? test-result)
  (eq? 'fail (car test-result)))

(define (legacy-failure-count result)
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

(define (report-test test)
  (let* ((attrs (cdr test))
         (message
          (and (failed-test? test)
               (format "Expected ~s but got ~s"
                       (cdr (assoc 'expected attrs))
                       (cdr (assoc 'actual attrs))))))
    `((name . ,(cdr (assoc 'description attrs)))
      (status . ,(if (failed-test? test) "fail" "pass"))
      (output . ,(cdr (assoc 'stdout attrs)))
      (test_code . ,(scheme->string (cdr (assoc 'code attrs))))
      ,@(or (and message `((message . ,message))) '()))))

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
