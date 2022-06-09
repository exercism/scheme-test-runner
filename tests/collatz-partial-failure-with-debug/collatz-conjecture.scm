;; Fail one case on purpose, adn test the debug mechanism for test reporting.
(define (collatz n)
  (let ((result
         (cond ((= n 1) 0)
               ;; Bad case
               ((= n 12) 8)
               ((even? n) (+ 1 (collatz (/ n 2))))
               (else (+ 1 (collatz (+ 1 (* 3 n))))))))
    (display (format "Debug: ~s\n" result))
    result))
