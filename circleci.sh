#!/bin/bash

set -uexo pipefail

HOST_DMD_VER=2.072.2 # same as in dmd/src/posix.mak
CURL_USER_AGENT="CirleCI $(curl --version | head -n 1)"
DUB=${DUB:-$HOME/dlang/dub/dub}
N=2
CIRCLE_NODE_INDEX=${CIRCLE_NODE_INDEX:-0}
CIRCLE_PROJECT_REPONAME=${CIRCLE_PROJECT_REPONAME:-phobos}

case $CIRCLE_NODE_INDEX in
    0) MODEL=64 ;;
    1) MODEL=32 ;;
esac

download() {
    local url="$1"
    local fallbackurl="$2"
    local outputfile="$3"
    for i in {0..4}; do
        if curl -fsS -A "$CURL_USER_AGENT" --max-time 5 "$url" -O "$outputfile" ||
           curl -fsS -A "$CURL_USER_AGENT" --max-time 5 "$fallbackurl" -o "$outputfile" ; then
            break
        elif [ $i -ge 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to download script ${outputfile}" 1>&2
            exit 1
        fi
    done
}

install_deps() {
    if [ $MODEL -eq 32 ]; then
        sudo apt-get update --quiet=2
        sudo aptitude install g++-multilib --assume-yes --quiet=2
    fi

    download "https://dlang.org/install.sh" "https://nightlies.dlang.org/install.sh" "install.sh"

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
        base_branch=$((curl -fsSL https://api.github.com/repos/dlang/$CIRCLE_PROJECT_REPONAME/pulls/$CIRCLE_PR_NUMBER || echo) | jq -r '.base.ref')
    else
        base_branch=$CIRCLE_BRANCH
    fi
    base_branch=${base_branch:-"master"}

    # merge upstream branch with changes, s.t. we check with the latest changes
    if [ -n "${CIRCLE_PR_NUMBER:-}" ]; then
        local head=$(git rev-parse HEAD)
        git fetch https://github.com/dlang/$CIRCLE_PROJECT_REPONAME.git $base_branch
        git checkout -f FETCH_HEAD
        local base=$(git rev-parse HEAD)
        git config user.name 'CI'
        git config user.email '<>'
        git merge -m "Merge $head into $base" $head
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
    make -j$N -C ../dmd/src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD all
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL HOST_DMD=$DMD
}

# verify style guide
style()
{
    # load compiler for dscanner
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
    make -f posix.mak $(find std etc -name "*.d" | sed "s/[.]d$/.test")
}

# compile all public unittests separately
publictests()
{
    clone https://github.com/dlang/tools.git ../tools master
    # fix to a specific version of https://github.com/dlang/tools/blob/master/phobos_tests_extractor.d
    git -C ../tools checkout 184f5e60372d6dd36d3451b75fb6f21e23f7275b
    make -f posix.mak publictests DUB=$DUB
}

codecov()
{
    # CodeCov gets confused by lst files which it can't matched
    rm -rf test/runnable/extra-files
    download "https://codecov.io/bash" "https://raw.githubusercontent.com/codecov/codecov-bash/master/codecov" "codecov.sh"
    bash codecov.sh
}

case $1 in
    install-deps) install_deps ;;
    setup-repos) setup_repos ;;
    coverage) coverage ;;
    style) style ;;
    publictests) publictests ;;
    codecov) codecov ;;
esac
