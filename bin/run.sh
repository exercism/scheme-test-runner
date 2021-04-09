#!/usr/bin/env sh

# Synopsis:
# Run the test runner on a solution.

# Arguments:
# $1: exercise slug
# $2: absolute path to solution folder
# $3: absolute path to output directory

# Output:
# Writes the test results to a results.json file in the passed-in output directory.
# The test results are formatted according to the specifications at https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md

# Example:
# ./bin/run.sh two-fer /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/

# If any required arguments is missing, print the usage and exit
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "usage: ./bin/run.sh exercise-slug /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/"
    exit 1
fi

test_output=$(scheme --script "bin/exercise.ss" $@ 2>&1)

# TODO: update 'exercise.ss' to gracefully handle syntax errors
if [ ! $? -eq 0 ]; then
    output_dir="${3%/}"
    results_file="${output_dir}/results.json"
    jq -n --arg output "${test_output}" '{version: 2, status: "fail", output: $output, tests: []}' > ${results_file}
fi

