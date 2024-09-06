/* -*- flycheck-gcc-include-path: ("/usr/include/guile/3.0"); flycheck-clang-include-path: ("/usr/include/guile/3.0"); -*- */
/* Shared object module for solving 0/1knapsack with dynamic programming */

#include <stddef.h>
#include <stdlib.h>
#include <stdbool.h>
#include <libguile.h>

static void Serror(const char *msg)
{
  scm_strerror(scm_from_latin1_string(msg));
  return;
}

struct Items {
  int size;
  int *weights;
  int *values;
};

static void solve_guard(int capacity, SCM ws, SCM vs)
{
  if (capacity < 0) {
	Serror("can't have capacity less than 0");
  }
  if (!scm_vector_p(ws)) {
	Serror("expected weights to be a vector");
  }
  if (!scm_vector_p(vs)) {
	Serror("expected values to be a vector");
  }
}

static struct Items solve_validate_items(SCM ws, SCM vs)
{
  int sizews = scm_to_int(scm_vector_length(ws));
  int sizevs = scm_to_int(scm_vector_length(vs));
  if (sizews != sizevs) {
	Serror("expected the same number of weights and values");
  }
  struct Items items = (struct Items){ sizews, NULL, NULL };
  items.weights = calloc(items.size + 1, sizeof(int));
  if (items.weights == NULL) {
	Serror("failed to allocate space for items");
  }
  items.values = calloc(items.size + 1, sizeof(int));
  if (items.values == NULL) {
	free(items.weights);
	Serror("failed to allocate space for items");
  }
  for (int idx = 1; idx <= items.size; ++idx) {
	items.weights[idx] = scm_to_int(scm_vector_ref(ws, scm_from_int(idx - 1)));
	items.values[idx] = scm_to_int(scm_vector_ref(vs, scm_from_int(idx - 1)));
  }
  return items;
}

#define MAX(X,Y) ((X) >= (Y) ? (X) : (Y))

static void enumerate_solutions(int capacity, struct Items items,
								int (*solutions)[capacity + 1])
{
  for (int i = 1; i <= items.size; ++i) {
	for (int j = 1; j <= capacity; ++j) {
	  int wi = items.weights[i];
	  if (wi <= j) {
		// Fits current capacity.
		solutions[i][j] = MAX(items.values[i] + solutions[i-1][j-wi],
							  solutions[i-1][j]);
	  } else {
		// Doesn't fit, so skip it.
		solutions[i][j] = solutions[i-1][j];
	  }
	}
  }
}

// Return an Svector of booleans representing item presence.
SCM solve(SCM scapacity, SCM weights, SCM values)
{
  int solution = -1;
  const char *failmsg = NULL;

  int capacity = scm_to_int(scapacity);

  solve_guard(capacity, weights, values);
  struct Items items = solve_validate_items(weights, values);
  int (*solutions)[capacity + 1] =
  	calloc((items.size + 1) * (capacity + 1), sizeof(int));
  if (solutions == NULL) {
	failmsg = "Failed to allocate space for solution matrix";
	goto cleanup;
  }

  enumerate_solutions(capacity, items, solutions);
  solution = solutions[items.size][capacity];

 cleanup:
  if (items.weights) free(items.weights);
  if (items.values) free(items.values);
  if (solutions) free(solutions);
  if (failmsg) Serror(failmsg);
  return scm_from_int(solution);
}

void init_knapsack_solve(void *unused)
{
  (void)unused;
  scm_c_define_gsubr("solve", 3, 0, 0, solve);
}

void scm_init_knapasack_solve()
{
  scm_c_define_module("knapasack solve", init_knapsack_solve, NULL);
}
