#!/bin/bash
#
# Run the rFSM luaunit test-suite against several Lua interpreters.
#
# Usage: ./test-all-versions.sh [interp1 interp2 ...]
# Default: lua5.1 lua5.2 lua5.3 lua5.4 lua5.5 luajit
#
# Interpreters that are not installed (or that lack the luaunit / uutils
# dependencies) are skipped.

GRN='\e[0;32m'; RED='\e[0;31m'; CYA='\e[0;36m'; RST='\e[0m'

cd "$(dirname "$0")" || exit 1

INTERPS=("$@")
if [ ${#INTERPS[@]} -eq 0 ]; then
    INTERPS=(lua5.1 lua5.2 lua5.3 lua5.4 lua5.5 luajit)
fi

rc=0
for lua in "${INTERPS[@]}"; do
    if ! command -v "$lua" >/dev/null 2>&1; then
        echo -e "${CYA}skipping ${lua} (not installed)${RST}"
        continue
    fi
    # the in-tree dependencies (uutils, ansicolors) and luaunit must be
    # installed for this interpreter
    if ! "$lua" -e 'require("utils"); require("luaunit")' >/dev/null 2>&1; then
        echo -e "${CYA}skipping ${lua} (uutils/luaunit not installed for this version)${RST}"
        continue
    fi
    echo -e "${GRN}=== ${lua} ($($lua -v 2>&1 | head -1)) ===${RST}"
    if "$lua" run.lua; then
        echo -e "${GRN}${lua}: PASS${RST}"
    else
        echo -e "${RED}${lua}: FAIL${RST}"
        rc=1
    fi
done
exit $rc
