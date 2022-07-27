/* Shared object module for solving 0/1knapsack with dynamic programming */

#include <scheme.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>

static void Serror(const char * sym, const char *msg)
{
  ptr error = Stop_level_value(Sstring_to_symbol("error"));
  Scall2(error, Sstring_to_symbol(sym), Sstring(msg));
  return;
}

struct Items {
  int size;
  int *weights;
  int *values;
};

static void solve_guard(int capacity, ptr ws, ptr vs)
{
  if (capacity < 0) {
	Serror("solve", "can't have capacity less than 0");
  }
  if (!Svectorp(ws)) {
	Serror("solve", "expected weights to be a vector");
  }
  if (!Svectorp(vs)) {
	Serror("solve", "expected values to be a vector");
  }
}

static struct Items solve_validate_items(ptr ws, ptr vs)
{
  iptr sizews = Svector_length(ws);
  iptr sizevs = Svector_length(vs);
  if (sizews != sizevs) {
	Serror("solve", "expected the same number of weights and values");
  }
  struct Items items = (struct Items){ sizews, NULL, NULL };
  items.weights = calloc(items.size + 1, sizeof(int));
  if (items.weights == NULL) {
	Serror("solve", "failed to allocate space for items");
  }
  items.values = calloc(items.size + 1, sizeof(int));
  if (items.values == NULL) {
	free(items.weights);
	Serror("solve", "failed to allocate space for items");
  }
  for (iptr idx = 1; idx <= items.size; ++idx) {
	items.weights[idx] = Sinteger32_value(Svector_ref(ws, idx - 1));
	items.values[idx] = Sinteger32_value(Svector_ref(vs, idx - 1));
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
int solve(int capacity, ptr weights, ptr values)
{
  int solution = -1;
  const char *failmsg = NULL;

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
  if (failmsg) Serror("solve", failmsg);
  return solution;
}
