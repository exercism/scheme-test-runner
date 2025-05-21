(import (rnrs))

;; The anscient version of Guile running on the Exercism system prints
;; "weird" symbols using the so-called extended read syntax, which the
;; test grader run by Chez Scheme does not understand. The next line
;; forces Guile to use the syntax Chez Scheme understands.
;; (print-set! r7rs-symbols 'r7rs-symbols)

(define (accumulate f xs)
  (let ((head (list '())))
    (let recurse ((xs xs) (tail head))
      (when (not (null? xs))
        (set-cdr! tail (list (f (car xs))))
        (recurse (cdr xs) (cdr tail))))
    (cdr head)))
