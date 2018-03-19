#!/bin/bash

set -uexo pipefail

HOST_DMD_VER=2.078.1
CURL_USER_AGENT="CirleCI $(curl --version | head -n 1)"
DUB=${DUB:-dub}
N=2
CIRCLE_NODE_INDEX=${CIRCLE_NODE_INDEX:-0}
BUILD="debug"

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
        if curl -fsS -A "$CURL_USER_AGENT" --max-time 5 https://dlang.org/install.sh -O ||
           curl -fsS -A "$CURL_USER_AGENT" --max-time 5 https://nightlies.dlang.org/install.sh -O ; then
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
        if git clone --branch "$branch" "$url" "$path" "${@:4}"; then
            break
        elif [ $i -lt 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to clone: ${url}"
            exit 1
        fi
    done
}

setup_repos()
{
    # set a default in case we run into rate limit restrictions
    local base_branch=""
    if [ -n "${CIRCLE_PR_NUMBER:-}" ]; then
        base_branch=$((curl -fsSL https://api.github.com/repos/dlang/phobos/pulls/$CIRCLE_PR_NUMBER || echo) | jq -r '.base.ref')
    else
        base_branch=$CIRCLE_BRANCH
    fi
    base_branch=${base_branch:-"master"}

    # merge upstream branch with changes, s.t. we check with the latest changes
    if [ -n "${CIRCLE_PR_NUMBER:-}" ]; then
        local head=$(git rev-parse HEAD)
        git remote add upstream "https://github.com/dlang/$CIRCLE_PROJECT_REPONAME.git"
        git fetch -q upstream "+refs/pull/${CIRCLE_PR_NUMBER}/merge:"
        git checkout -f FETCH_HEAD
    fi

    for proj in dmd druntime ; do
        if [ $base_branch != master ] && [ $base_branch != stable ] &&
            ! git ls-remote --exit-code --heads https://github.com/dlang/$proj.git $base_branch > /dev/null; then
            # use master as fallback for other repos to test feature branches
            clone https://github.com/dlang/$proj.git ../$proj master --depth 1
        else
            clone https://github.com/dlang/$proj.git ../$proj $base_branch --depth 1
        fi
    done

    # load environment for bootstrap compiler
    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash ~/dlang/install.sh dmd-$HOST_DMD_VER --activate)"

    # build dmd and druntime
    make -j$N -C ../dmd/src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD BUILD=$BUILD all
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL HOST_DMD=$DMD BUILD=$BUILD
}

# verify style guide
style_lint()
{
    # dscanner needs a more up-to-date DMD version
    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash ~/dlang/install.sh dmd-$HOST_DMD_VER --activate)"

    make -f posix.mak style_lint DUB=$DUB BUILD=$BUILD
}

# run unittest with coverage
coverage()
{
    make -f posix.mak clean
    # remove all existing coverage files (just in case)
    rm -rf $(find -name '*.lst')

    # Coverage information of the test runner can be missing for some template instatiations.
    # https://issues.dlang.org/show_bug.cgi?id=16397
    # ENABLE_COVERAGE="1" make -j$N -f posix.mak MODEL=$MODEL unittest-debug

    # So instead we run all tests individually (hoping that that doesn't break any tests).
    # -cov is enabled by the %.test target itself
    make -j$N -f posix.mak BUILD=$BUILD $(find std etc -name "*.d" | sed "s/[.]d$/.test/")

    # Remove coverage information from lines with non-deterministic coverage.
    # These lines are annotated with a comment containing "nocoverage".
    sed -i 's/^ *[0-9]*\(|.*nocoverage.*\)$/       \1/' ./*.lst
}

# extract publictests and run them independently
publictests()
{
    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash ~/dlang/install.sh dmd-$HOST_DMD_VER --activate)"

    # checkout a specific version of https://github.com/dlang/tools
    if [ ! -d ../tools ] ; then
        clone https://github.com/dlang/tools.git ../tools master
    fi
    git -C ../tools checkout 6ad91215253b52e6ecfc39fe1854815867c66f23

    make -f posix.mak -j$N publictests DUB=$DUB BUILD=$BUILD
}

case $1 in
    install-deps) install_deps ;;
    setup-repos) setup_repos ;;
    coverage) coverage ;;
    publictests) publictests ;;
    style_lint) style_lint ;;
    # has_public_example has been removed and is kept for compatibility with older PRs
    has_public_example) echo "OK" ;;
    *) echo "Unknown command"; exit 1;;
esac
