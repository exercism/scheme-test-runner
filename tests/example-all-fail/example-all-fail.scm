(import (rnrs))

(define (leap-year? year)
  (not (zero? (modulo year 2))))
