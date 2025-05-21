(import (rnrs))

;; Build and load shared object library for matrix computations.
(unless (and (zero? (system "gcc -shared -o ksdp.so -Wall -Werror -fpic ksdp.c")))
  (error 'knapsack.scm "gcc error building C auxillary library"))

(dynamic-call "init_knapsack_solve" (dynamic-link "./ksdp.so"))

(define (knapsack capacity weights values)
  (solve capacity (list->vector weights) (list->vector values)))
