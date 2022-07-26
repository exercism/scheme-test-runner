(import (rnrs))

;; Remove any artifacts from previous builds.
(system "rm -f *.so *.o")
;; Build and load shared object library for matrix computations.
(unless (and (zero? (system "gcc -c -Wall -Werror -fpic ksdp.c"))
             (zero? (system "gcc -shared -o ksdp.so ksdp.o")))
  (error 'knapsack.scm "gcc error building C auxillary library"))

(load-shared-object "./ksdp.so")

(define solve (foreign-procedure "solve" (integer-32 ptr ptr) integer-32))

(define (knapsack capacity weights values)
  (solve capacity (list->vector weights) (list->vector values)))
