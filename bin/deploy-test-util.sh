#! /usr/bin/env sh

function die ()
{
    local msg=
    if [ -z "$1" ]; then
        msg="internal error"
    fi
    msg="$1"
    echo "$msg" >&2
    exit 1
}

if [ -z "$1" ]; then
    die "Missing path to new test-util.scm file!"
elif [ -f "$1" ]; then
    new="$1"
else
    die "'${1}' is not a file!"
fi

for old in `find tests -depth -name "test-util.ss"`; do
    cp "$new" "$old"
done
