(import (chezscheme))

(define (legacy-output-results status tests output)
  (delete-file "results.json")
  (with-output-to-file "results.json"
    (lambda ()
      (json-write `((version . 2)
                    (status . ,status)
                    (tests . ,tests))))))

(define legacy-report-results
  (let ((pass-or-fail
         (lambda (result)
           (legacy-output-results
            (or (and (zero? (legacy-failure-count result)) "pass") "fail")
            (failure-messages result) ""))))
    (lambda (chez guile)
      (cond
       ((andmap null? `(,chez ,guile))
        (write-results
         `((version . 2)
           (status . error)
           (message . "legacy test crash")
           (tests))))
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
             (unless (result-ok? results)
               (k `((status . error)
                    (message . ,(cdr (assoc 'message results))))))
             `((status
                . ,(if (zero? (failure-count results)) 'pass 'fail))
               (tests
                ,@(map report-test (get-tests results))))))))))

;; read s-expression from process stdout
(define (process->scheme command)
  (let-values (((out in err id) (open-process-ports command 'block (current-transcoder))))
    (let ((err* (get-string-all err))
          (result (read in)))
      (unless (eof-object? err*)
        (call-with-port (current-error-port)
          (lambda (e)
            (display (format "Error executing ~s:\n" command) e)
            (display err* e)
            (newline))))
      (close-port out)
      (close-port err)
      (close-port in)
      result)))

(define (scheme->string o)
  (with-output-to-string
    (lambda ()
      (write o))))

(define (scheme->pretty-string o)
  (with-output-to-string
    (lambda () (pretty-print o))))

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

;; We can create the input and output dirs from just the slug
;; when we are running tests for the test-runner.
(define (run-test-exercise slug)
  (let ((dir (format "~a/tests/~a/" (current-directory) slug)))
    (exercise slug dir dir)))

(define (convert xs)
  (or (and (list? xs) xs) '()))

;; try to run solution for both guile and chez. report-results selects
;; run with fewest failures.
(define (exercise slug input-directory output-directory)
  (parameterize ((cd input-directory))
    (let ((chez-result (process->scheme "scheme --script test.scm --docker"))
          (guile-result (process->scheme "guile -l $CODE_DIR/guile-suppress-warning-messages.scm test.scm --docker")))
      (parameterize ((cd output-directory))
        (call/cc
         (lambda (k)
           (with-exception-handler
               (lambda (e)
                 (call-with-port (current-error-port)
                   (lambda (out)
                     (display (format "Non-fatal error: ~s\n" (process-condition e)) out)))
                 (k
                  (write-results
                   `((version . 2)
                     (status . error)
                     (message . "Syntax error")
                     (tests)))))
             (lambda ()
               ;; One result must be a list at least.
               (unless (ormap list? `(,chez-result ,guile-result))
                 (error 'exercise "syntax error"))
               ;; Now make sure they are both lists.
               (set! chez-result (convert chez-result))
               (set! guile-result (convert guile-result))
               ;; Finally branch on the version.
               (case (or (cdr-or (assoc 'test-lib-version chez-result) #f)
                         (cdr-or (assoc 'test-lib-version guile-result) 0))
                 (0 (legacy-report-results (legacy-convert chez-result)
                                           (legacy-convert guile-result)))
                 (else
                  (report-results chez-result guile-result)))))))))))

(define (failure-count results)
  (fold-left (lambda (count x)
               (if (failed-test? x) (1+ count)
                   count))
             0 results))

(define (failed-test? test-result)
  (eq? 'fail (car test-result)))

(define (legacy-failure-count result)
  (car result))

(define (failure-messages result)
  (cdr result))

;; massage result of tests to desired format
(define (legacy-convert result)
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
      (test_code . ,(format-test-code (cdr (assoc 'code attrs))))
      ,@(or (and message `((message . ,message))) '()))))

(define (format-test-code code)
  (call/cc
   (lambda (k)
     (unless (and (list? code) (not (null? code)))
       (k (scheme->pretty-string code)))
     (case (car code)
       ((test-success) (format-test-success code))
       ((test-error) (format-test-error code))
       (else (scheme->pretty-string code))))))

(define (third xs)
  (list-ref xs 2))

(define (fourth xs)
  (list-ref xs 3))

(define (fifth xs)
  (list-ref xs 4))

(define (sixth xs)
  (list-ref xs 5))

;; The 3rd, 4th, 5th, and 6th elements of the src list are the
;; comparator, procedure, inputs, and expected output respectively.
;; The output is not always quoted, so we actually need to treat it
;; specially and pull it out of the quote only when detected as a quoted list.
(define (format-test-success code)
  (scheme->pretty-string
   `(,(third code)
     (,(fourth code) ,@(cadr (fifth code)))
     ,(get-output (sixth code)))))

(define (get-output x)
  (cond
   ((and (list? x) (not (null? x))
         (equal? 'quote (car x)))
    (cadr x))
   (else x)))

;; The 3rd and 4th elements of the src list are procedure and its inputs.
(define (format-test-error code)
  (scheme->pretty-string
   `(,(third code) ,@(cadr (fourth code)))))

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
