#!/bin/bash

set -euxo pipefail
BUILD="debug"
DUB=${DUB:-dub}
N=${N:-2}

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

    bash codecov.sh -t "${CODECOV_TOKEN}"
}


# extract publictests and run them independently
publictests()
{
    if [ ! -d ../tools ] ; then
        git clone --depth 1 https://github.com/dlang/tools.git ../tools
    fi

    make -f posix.mak -j$N publictests DUB=$DUB BUILD=$BUILD
}

# test stdx dub package
dub_package()
{
    pushd test
    dub -v --single dub_stdx_checkedint.d
    dub -v --single dub_stdx_allocator.d
    popd
}

publictests
dub_package
coverage
