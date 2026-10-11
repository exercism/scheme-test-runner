(use-modules (ice-9 popen)
             (ice-9 exceptions)
             (srfi srfi-1))

;; Read and write symbols such as |foo bar| the way test-util.ss does.
(read-enable 'r7rs-symbols)
(print-enable 'r7rs-symbols)

(define (legacy-output-results status tests output)
  (write-results `((version . 2)
                   (status . ,status)
                   (tests . ,tests))))

(define (legacy-report-results result)
  (if (null? result)
      (write-results
       `((version . 2)
         (status . error)
         (message . "legacy test crash")
         (tests)))
      (legacy-output-results
       (if (zero? (legacy-failure-count result)) "pass" "fail")
       (failure-messages result) "")))

(define (write-results r)
  (with-output-to-file "results.json"
    (lambda () (json-write r))))

(define (result-ok? result)
  (eq? 'ok (cdr-or (assoc 'status result) #f)))

(define (test-result? results)
  (and (pair? results)
       (or (eq? 'pass (car results))
           (eq? 'fail (car results)))))

(define (get-tests results)
  (filter test-result? results))

(define (report-results results)
  (write-results
   `((version . 2)
     . ,(if (result-ok? results)
            `((status
               . ,(if (zero? (failure-count results)) 'pass 'fail))
              (tests
               ,@(map report-test (get-tests results))))
            `((status . error)
              (message . ,(cdr-or (assoc 'message results) "")))))))

;; Read one s-expression from the command's stdout. The command's
;; stderr passes straight through to ours. Returns #f if the output
;; can't be read.
(define (process->scheme command)
  (let* ((port (open-input-pipe command))
         (result (catch #t
                   (lambda () (read port))
                   (lambda (key . args)
                     (format (current-error-port)
                             "Error reading output of ~s: ~s ~s\n"
                             command key args)
                     #f))))
    (close-pipe port)
    result))

(define (scheme->pretty-string o)
  (with-output-to-string
    (lambda ()
      (pretty-write-at o 0 (current-output-port))
      (newline))))

;; A compact pretty printer in the style of Chez Scheme's. Guile's
;; (ice-9 pretty-print) puts every element of a long list on its own
;; line; here lists of data are filled across the line instead.
(define pretty-line-length 75)
(define pretty-one-line-limit 60)

(define abbreviations
  '((quote . "'") (quasiquote . "`")
    (unquote . ",") (unquote-splicing . ",@")))

;; Forms whose first argument stays on the head line, with the body
;; indented below.
(define body-forms
  '(lambda define let let* letrec letrec* let-values let*-values
    when unless case do))

(define (abbreviation x)
  (and (pair? x) (pair? (cdr x)) (null? (cddr x))
       (assq-ref abbreviations (car x))))

(define (flat x)
  (cond
   ((abbreviation x)
    => (lambda (prefix) (string-append prefix (flat (cadr x)))))
   ((pair? x)
    (let loop ((x x) (parts '()))
      (cond
       ((null? x) (string-append "(" (string-join (reverse parts) " ") ")"))
       ((pair? x) (loop (cdr x) (cons (flat (car x)) parts)))
       (else (loop '() (cons* (flat x) "." parts))))))
   (else (with-output-to-string (lambda () (write x))))))

;; A string fits on the line if it neither runs past the line length nor
;; is longer than the one-line limit.
(define (fits? width col)
  (and (<= width pretty-one-line-limit)
       (<= (+ col width) pretty-line-length)))

(define (lambda-form? x)
  (and (pair? x) (eq? 'lambda (car x))))

;; Write x to port p starting at column col and return the column where
;; the output ends.
(define (pretty-write-at x col p)
  (let ((s (flat x)))
    (cond
     ((or (not (list? x)) (fits? (string-length s) col))
      (display s p)
      (+ col (string-length s)))
     ((abbreviation x)
      => (lambda (prefix)
           (display prefix p)
           (pretty-write-at (cadr x) (+ col (string-length prefix)) p)))
     (else
      (display "(" p)
      (let* ((head (car x))
             (args (cdr x))
             (end
              (cond
               ;; (lambda (x)
               ;;   body)
               ((and (memq head body-forms) (pair? args))
                (let ((c (pretty-write-at head (+ col 1) p)))
                  (display " " p)
                  (pretty-write-lines (cdr args) (+ col 2)
                                      (pretty-write-at (car args) (+ c 1) p) p)))
               ;; (= (f x)
               ;;    y)
               ((and (symbol? head) (pair? args)
                     (<= (string-length (flat head)) 2))
                (let ((c (pretty-write-at head (+ col 1) p)))
                  (display " " p)
                  (pretty-write-lines (cdr args) (+ c 1)
                                      (pretty-write-at (car args) (+ c 1) p) p)))
               ;; (f
               ;;   x
               ;;   y)
               ((or (symbol? head) (lambda-form? head))
                (pretty-write-lines args (+ col 2)
                                    (pretty-write-at head (+ col 1) p) p))
               ;; (1 2 3
               ;;  4 5)
               (else (pretty-write-fill x col p)))))
        (display ")" p)
        (+ end 1))))))

;; Write each of xs on its own line, indented to column indent.
(define (pretty-write-lines xs indent col p)
  (fold (lambda (x col)
          (newline p)
          (display (make-string indent #\space) p)
          (pretty-write-at x indent p))
        col xs))

;; Write the elements of xs, as many to a line as fit, aligned one column
;; past the open paren at column col.
(define (pretty-write-fill xs col p)
  (let ((indent (+ col 1)))
    (fold (lambda (x c)
            (let* ((s (flat x))
                   (end (+ c 1 (string-length s))))
              (cond
               ((and (<= (- end col) pretty-one-line-limit)
                     (<= end pretty-line-length))
                (display " " p)
                (display s p)
                end)
               (else
                (newline p)
                (display (make-string indent #\space) p)
                (pretty-write-at x indent p)))))
          (pretty-write-at (car xs) indent p)
          (cdr xs))))

(define (process-condition e)
  (if (not (exception? e)) e
      `(error
        ,(if (exception-with-origin? e) (exception-origin e)
             'unknown)
        ,(if (exception-with-message? e) (exception-message e)
             (exception-kind e))
        ,@(if (not (exception-with-irritants? e)) '()
              (exception-irritants e)))))

(define (cdr-or x y)
  (if (pair? x) (cdr x) y))

(define (exercise slug input-directory output-directory)
  (chdir input-directory)
  (let ((result (process->scheme "guile -l $CODE_DIR/guile-suppress-warning-messages.scm test.scm --docker")))
    (chdir output-directory)
    (with-exception-handler
        (lambda (e)
          (format (current-error-port) "Non-fatal error: ~s\n"
                  (process-condition e))
          (write-results
           `((version . 2)
             (status . error)
             (message . "Syntax error")
             (tests))))
      (lambda ()
        (unless (list? result)
          (error "syntax error"))
        ;; Branch on the version.
        (case (cdr-or (assoc 'test-lib-version result) 0)
          ((0) (legacy-report-results (legacy-convert result)))
          (else
           (report-results result))))
      #:unwind? #t)))

(define (failure-count results)
  (count failed-test? results))

(define (failed-test? test-result)
  (and (pair? test-result)
       (eq? 'fail (car test-result))))

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
      (else (error "unexpected result shape" result)))))

(define (report-test test)
  (let* ((attrs (cdr test))
         (message
          (and (failed-test? test)
               (format #f "Expected ~s but got ~s"
                       (cdr (assoc 'expected attrs))
                       (cdr (assoc 'actual attrs))))))
    `((name . ,(cdr (assoc 'description attrs)))
      (status . ,(if (failed-test? test) "fail" "pass"))
      (output . ,(cdr (assoc 'stdout attrs)))
      (test_code . ,(format-test-code (cdr (assoc 'code attrs))))
      ,@(if message `((message . ,message)) '()))))

(define (format-test-code code)
  (if (not (and (list? code) (not (null? code))))
      (scheme->pretty-string code)
      (case (car code)
        ((test-success) (format-test-success code))
        ((test-error) (format-test-error code))
        (else (scheme->pretty-string code)))))

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
       ((string? x) (if (string-null? x) (display "null" p) (write x p)))
       ((number? x) (write x p))
       ((boolean? x) (display (if x "true" "false") p))
       ((symbol? x) (if (eq? x 'null)
                        (display "null" p)
                        (write (symbol->string x) p))) ;; for convenience
       ((and (list? x)
             (pair? (car x))
             (not (pair? (caar x))))
        (write-ht x p))
       ((list? x) (write-array x p))
       (else (error "Invalid JSON object in json-write" x))))

    (lambda (x)
      (write-any x (current-output-port)))))

;; Usage: guile code/exercise.scm slug input-directory output-directory
(apply exercise (cdr (command-line)))
