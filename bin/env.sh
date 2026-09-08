#!/usr/bin/env sh

# Discover Chez's scheme.h dynamically
CHEZ_INCLUDE_PATH="$(dirname "$(find /usr/lib -name scheme.h -print -quit)")"
C_INCLUDE_PATH="${CHEZ_INCLUDE_PATH}:/usr/include/guile/3.0"
export C_INCLUDE_PATH
