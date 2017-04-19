Guidelines for Contributing
===========================

Welcome to the D community and thanks for your interest in contributing!
If you need help you can ask questions on `#d` IRC channel on
freenode.org ([web interface](https://kiwiirc.com/client/irc.freenode.net/d))
or on [our forum](http://forum.dlang.org/). Please submit issues to our
[Bugzilla bug tracker](https://issues.dlang.org).

Guidelines for contributing to Phobos
-------------------------------------

Contributing to Phobos can be done using the [usual Github workflow](https://guides.github.com/introduction/flow/).
Detailed build instructions can be found at our [D wiki](https://wiki.dlang.org/Starting_as_a_Contributor#Building_D).

Below is a list of tips and checks that you should consider before opening your pull
request:

Code
----

Please read the [D style](http://dlang.org/dstyle.html) _carefully_ before you
start coding. All submissions are required to follow these rules.

### Advices

-   Does your PR address only one topic? Can it be split up in smaller, encapsulated
    PRs? ([Large diffs are very hard to review](http://forum.dlang.org/post/nmjlat$1dc7$1@digitalmars.com)
-   Is your code flexible enough to accommodate more use cases?
-   Is there an easier or more performant way to do it?
-   Read through your code again - is there any part that isn't understandable?
-   Avoid code duplication
-   Be critical when looking at Phobos code (some parts of Phobos are a
    bit older and have some relics due to lacking functionality of
    the compiler)

### Tests

-   [Autotester](https://wiki.dlang.org/Git_Commit_Tester) will automatically
    compile the code in your PR and test it on all supported platforms.
    For your first PR you need approval from any reviewer - ping them in
    case they forgot.
-   Do all [tests pass locally](https://wiki.dlang.org/Starting_as_a_Contributor#Unittest_phobos)? You
    can run the tests of
    -   single module or packages with `make` `-f` `posix.mak`
        `std/algorithm/comparison.test` or `make` `-f` `posix.mak`
        `std/algorithm.test`
    -   all tests with `make` `-f` `posix.mak` `unittest` (add `-j`
        `NUMBER_OF_CORES` if you have multiple cores)
    -   for small changes in a single module it might be faster to use `rdmd` `-main`
        `-unittest` `comparison.d` (be careful, this links to your
        current Phobos version)
    -   for Windows have a look at [building Phobos under
        windows](https://wiki.dlang.org/Starting_as_a_Contributor#Windows_2))
-   Do your tests cover all cases? (you can check code coverage in the
    resulting `std_algorithm_comparison.lst` file which is created e.g. by
    `make` `-f` `posix.mak` `std/algorithm/comparison.test`)

Review process
--------------

-   Every PR *must* pass all tests for all supported platforms of the
    [Autotester](https://wiki.dlang.org/Git_Commit_Tester) before being merged
-   Big additions (new modules) should go to `std.experimental` first
    (after they pass the [review process](https://wiki.dlang.org/Review/Process)).
    If you plan to work on a new module, it's a good idea to (1) ask the community
	for feedback before you start, (2) publish it as a DUB module, s.t. everyone
	can test your module during the review process.
-   Smaller additions like individual functions can be merged directly
    after [@andralex](https://github.com/andralex) approves
-   Refactoring or bug fixes just need approval (LGTM) from two
    reviewers and enough time passed (usually 2-3 days, depending on
    weekends and holidays) to give everyone an opportunity to shout
-   For low-level changes the other compiler devs (GDC and LLVM) should
    be consulted
-   Trivial changes (e.g. small documentation enhancements) should be marked with
	`[Trivial]` as title prefix
-   If your PR is stalled (no activity within a couple of days) and you addressed
    all concerns, don't hesitate to ping your reviewers
-   See [rebasing](https://wiki.dlang.org/Starting_as_a_Contributor#Rebasing) if you
    need to sync your fork with master

Naming guidelines
-----------------

### General advices

-   Phobos uses a distinct [naming scheme](https://wiki.dlang.org/Naming_conventions)
-   If necessary, wrap your Git explanation paragraph [to 72 chars](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
-   Do you use clear variable names?
-   Does your PR have a concise and informative title?
-   Are your Git messages clear and informative? (otherwise use `git commit --amend`
	for a single commit or `git rebase` for multiple commits)
-   Avoid having many commits per PR (commits should reflect actual changes, not design iterations) - see
    [squashing](https://wiki.dlang.org/Starting_as_a_Contributor#Someone_asked_me_to_squash_my_commits.2C_what_does_that_mean.3F) to combine commits

### Issues :fire:

-   Bug fix PRs should have a separate commit for each bugzilla issue
    that it fixes
-   The message of the commit actually fixes the bug should be
    "Fix issue X - [issue title from Bugzilla]" where X is the number of the
    corresponding [bugzilla](https://issues.dlang.org) issue. For example:

```
+ Refactor the code assist with the bug fix
+ Fix issue 17000 - map doesn't accept some range types
+ Fix issue 17001 - map doesn't work with some other range type
```

-   Unrelated fixes, refactorings or additions should preferably go
    separate pull request(s) (tightly related fixes are okay in the
    same PR)

Documentation
-------------

### Documentation style

-   The documentation is written in [ddoc](http://dlang.org/spec/ddoc.html)
-   Use complete English sentences with correct syntax, grammar, and
    punctuation
-   Use precise technical terms. Avoids colloquialisms
-   Honestly describe limitations and dangers
-   Add `Params`, `Returns` and if needed `See_Also` sections
-   Provide at least one ddoced unittest for a new method
-   Have a brief one sentence summary at the beginning of a method
-   Give a synopsis at the beginning of a module accompanied by an module-level
    example

### Documentation checks :heavy_check_mark:

-   Read your documentation text aloud - is it understandable?
-   Check the output of CyberShadows's DAutoTest of the documentation
    (or run [it yourself](https://github.com/dlang/dlang.org))
-   All user impacting changes should have a corresponding
    [changelog](https://github.com/dlang/phobos/blob/master/changelog.dd)
    entry (automatically generated for issues)
-   Did you add your method to the summary booktable or cheatsheet of a
    module? (might be in `package.d`)

### Documentation tricks :sparkles:

-   Use backticks `` `code` `` instead of `$(D` `foo)`
-   Start with a Capital letter in all blocks of the method header
-   Use `$(LREF myFun)` for links to other methods within the same file,
	and `$(REF)` for links to methods in other modules (format is `$(REF`
    `_stripLeft,` `std,` `algorithm,` `mutation)`)
-   Use `$(REF_ALTTEXT)` for a different link name (format is
    `$(REF_ALTTEXT` `your` `text,` `formattedRead,` `std,` `format)`
-   Variables will automatically be put in backticks, use an underscore
    to avoid this behavior (e.g. `_foo`)
-   Section headings are marked by a line with a single word followed by
    a colon `:`, use an underscore to avoid this behavior (e.g. `with`
    `the` `following` `\n` `code:` needs `_code` to avoid the creation
    of a section)
-   Section headings with multiple words should use underscores instead
    of spaces (e.g. `See_Also:`)
-   Don't put examples in your ddoc header - use the `///` magic to
    annotate them. Ddoc will automatically add the annotated test(s) to
    the `Examples` section of the method, e.g.:

```d
///
unittest
{
    assert(1 == 1);
}
```

-   Use `///` `ditto` to join multiple methods in the documentation

Happy hacking! :rocket:
----------------------

If you find a new gotcha, don't hesitate to edit this guide.

Thank you for your contribution!

See Also
--------

-   [Starting as a Contributor](https://wiki.dlang.org/Starting_as_a_Contributor)
-   [Get involved](https://wiki.dlang.org/Get_involved)
-   [How You Can Help](https://wiki.dlang.org/How_You_Can_Help)
-   [High-level vision for 2016 2nd half](https://wiki.dlang.org/Vision/2016H2)
