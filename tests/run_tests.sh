#!/bin/bash
# This unit test runner script supports several command line options
#
# coverage:
# enables code coverage
# requires
#   - luarocks package manager
#   - luacov project
#
# interp:
# run tests with different lua interpreters
# for example: --interp=lua5.3
# for example: -i lua5.2
# for example: --interp="lua5.1 lua5.2 lua5.3"
#
# noclean:
# by default, test artifacts are removed at end of test
# unset the default by passing --noclean
set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )" 
OPTION_INTERP=lua
OPTION_NOCLEAN=
OPTION_COVERAGE=

TEST=`echo fsmtest_*`
#TEST="test_simple.lua"

function show_help() {
  echo "$0 [--coverage] [-i | --interp]=\"${OPTION_INTERP}\" [--noclean]"
  exit 0
}

LONGOPTS=coverage,interp:,noclean,help
OPTIONS=i:,h
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
eval set -- "$PARSED"
while true; do
    case "$1" in
        --coverage)
            OPTION_COVERAGE=1
            shift 1
            ;;
	-i|--interp)
            OPTION_INTERP="$2"
            shift 2
            ;;
        --noclean)
            OPTION_NOCLEAN=1
            shift 1
            ;;
        -h|--help)
            show_help
            shift 1
            ;;
        --)
            shift
            break
            ;;
        *)
            echo error
            exit 3
            ;;
    esac
done

cd ${SCRIPT_DIR} # change to tests directory
for interp in $OPTION_INTERP; do
    echo Using interpreter: $interp

    set +e
    which $interp
    [[ $? -ne 0 ]] && continue
    set -e

    PATTERN='^Lua ([0-9][.][0-9])'
    [[ `$interp -v 2>&1` =~ $PATTERN ]] && LUA_VERSION=${BASH_REMATCH[1]} || exit

    FLAGS=""
    if [ $OPTION_COVERAGE ]; then
        rm -vf luacov.stats* # zero the coverage statistics
        FLAGS="-lluacov"
        eval "$(luarocks --lua-version ${LUA_VERSION} path --bin)"
    fi

    # on ubuntu, libgv-lua provides libgv_lua.so
    export LUA_CPATH="$LUA_CPATH;/usr/lib/x86_64-linux-gnu/graphviz/lua/?.so"

    for t in $TEST; do
        echo -e "\n\n*********************************** $interp $t ********************************************"
        $interp $FLAGS $t
    done

    if [ $OPTION_COVERAGE ]; then
        luacov
        mv luacov.report.out luacov.report.out.${LUA_VERSION}
    fi

done

if [ -z $OPTION_NOCLEAN ]; then
    rm -vf *.png
    rm -vf luacov.report.out* luacov.stats*
fi
