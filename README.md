# Scheme Test Runner

Test scheme exercisms in docker.

## Plan

Pass the three parameters given to [run.sh](bin/run.sh) to [exercise.scm](code/exercise.scm). 

From October 2026 only GNU Guile is supported. 

Run the solution's `test.scm` under Guile and read the s-expression it outputs.
Then convert the keys in the association list to the format laid out in the [exercism/automated-tests](https://github.com/exercism/automated-tests/) repository and finally output as JSON to a file `results.json`.

## Notes

The script gets three parameters:

- slug (eg. `two-fer`)
- path to solution directory (including final slash)
- path to output directory

The output is to be in json in the file `results.json`.

### Output structure

Fields are "status", "message"?, and "tests". Each test has "name",
"status", "message"?, "output" as fields.

Possible values for status include "pass", "fail", "error". "error"
is for unexpected exceptions.

### Running the fixture tests

Running the fixtures in Docker (`bin/run-tests-in-docker.sh`) leaves
`results.json` files owned by root in `tests/`. A later local run
(`bin/run-tests.sh`) can't overwrite them, and the failure is silent,
so the diffs compare stale results. Run `make clean-results` when
switching between Docker and local runs.

## todo

Most of the requirements should be implemented. One that isn't is
ensuring the output is `< 500` chars.
