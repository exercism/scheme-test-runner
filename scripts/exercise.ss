(import (chezscheme))

;; plan: run solution for both guile and chez. take the result which
;; passes the most test cases. finally, convert that output to
;; appropriate json.
(define (exercise-chez slug input-directory output-directory)
  (parameterize ((cd input-directory))
    (system (format "scheme --script test.scm --docker"))))

(let ((args (cdr (command-line)))) ;; cdr because this file appears as first argument
  (apply exercise-chez args))
