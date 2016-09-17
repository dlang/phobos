#!/bin/bash

set -uexo pipefail

HOST_DMD_VER=2.068.2 # same as in dmd/src/posix.mak
CURL_USER_AGENT="CirleCI $(curl --version | head -n 1)"
N=2

case $CIRCLE_NODE_INDEX in
    0) MODEL=64 ;;
    1) MODEL=32 ;;
esac

install_deps() {
    if [ $MODEL -eq 32 ]; then
        sudo apt-get update
        sudo apt-get install g++-multilib
    fi

    for i in {0..4}; do
        if curl -fsS -A "$CURL_USER_AGENT" --max-time 5 https://dlang.org/install.sh -O; then
            break
        elif [ $i -ge 4 ]; then
            sleep $((1 << $i))
        else
            echo 'Failed to download install script' 1>&2
            exit 1
        fi
    done

    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash install.sh dmd-$HOST_DMD_VER --activate)"
    $DC --version
    env
}

# clone dmd and druntime
clone() {
    local url="$1"
    local path="$2"
    local branch="$3"
    for i in {0..4}; do
        if git clone --depth=1 --branch "$branch" "$url" "$path"; then
            break
        elif [ $i -lt 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to clone: ${url}"
            exit 1
        fi
    done
}

# setup dmd and druntime
setup_repos()
{
    # set a default in case we run into rate limit restrictions
    local base_branch="master"
    if [ -n "${CIRCLE_PR_NUMBER:-}" ]; then
        base_branch=$(curl -fsSL https://api.github.com/repos/dlang/phobos/pulls/$CIRCLE_PR_NUMBER | jq -r '.base.ref')
    else
        base_branch=$CIRCLE_BRANCH
    fi

    clone https://github.com/dlang/dmd.git ../dmd $base_branch
    clone https://github.com/dlang/druntime.git ../druntime $base_branch

    # load environment for bootstrap compiler
    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash ~/dlang/install.sh dmd-$HOST_DMD_VER --activate)"

    # build dmd and druntime
    make -j$N -C ../dmd/src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD all
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL HOST_DMD=$DMD
}

# verify style guide
style()
{
    # load dmd to build dscanner
    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash ~/dlang/install.sh dmd-$HOST_DMD_VER --activate)"
    make -f posix.mak style
}

# run unittest with coverage
coverage()
{
    make -f posix.mak clean
    # remove all existing coverage files (just in case)
    rm -rf $(find -name '*.lst')

    # currently using the test_runner yields wrong code coverage results
    # see https://github.com/dlang/phobos/pull/4719 for details
    ENABLE_COVERAGE="1" make -f posix.mak MODEL=$MODEL unittest-debug

    # instead we run all tests individually
    make -f posix.mak $(find std etc -name "*.d" | sed "s/[.]d$/.test/" | grep -vE '(std.algorithm.sorting|std.encoding|net.curl)' )
}

case $1 in
    install-deps) install_deps ;;
    coverage) coverage ;;
    setup-repos) setup_repos ;;
esac
