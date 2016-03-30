Guidelines for Contributing
===========================

Welcome to the D community and thanks for your interest in contributing! To get started, please read the [Starting as a Contributor](http://wiki.dlang.org/Starting_as_a_Contributor) article on the D Wiki.

Quick links
-----------

- Fork [on Github](https://github.com/D-Programming-Language/phobos)
- Use our [Bugzilla bug tracker](http://d.puremagic.com/issues/)
- Follow the [D style](http://dlang.org/dstyle.html)
- Participate in [our forum](http://forum.dlang.org/)
- Ask questions on `#d` IRC channel on freenode.org ([web interface](https://kiwiirc.com/client/irc.freenode.net/d))
- Review Phobos additions in the [Review Queue](http://wiki.dlang.org/Review_Queue)

How to make a good submission?
------------------------------

The usual workflow is:

1. [Fork](https://help.github.com/articles/fork-a-repo/) [Phobos](https://github.com/D-Programming-Language/phobos) on Github
2. Create your [own branch](https://github.com/Kunena/Kunena-Forum/wiki/Create-a-new-branch-with-git-and-manage-branches)
3. [Work locally](http://wiki.dlang.org/Starting_as_a_Contributor#Building_D) on your new feature or fix (see the tips below)
4. [Test](#tests) your improvements locally
5. Submit your [pull request](https://help.github.com/articles/creating-a-pull-request/) (PR)

Below is a list of tips and checks that you should consider before opening your pull request:

### Code style

- [ ] Did you stick to the [style guide](http://dlang.org/dstyle.html)? (e.g. braces in their own lines (allman style) or white spaces between operators)
- Avoid unnecessarily importing other Phobos modules
- Try to not require a garbage collector (this is not a must)
- Avoid code duplication
- Maximal `@nogc`, `@safe`, `pure`, `nothrow` in _non-templated_ functions
- Don't add `@nogc`, `@safe`, `pure`, `nothrow` attributes to _templated_ functions - let the compiler infer it! However add unittest checks for these attributes if possible (e.g. `pure nothrow @nogc @safe unittest { ... }`)
- Avoid using `auto` as return type wherever possible (makes the documentation easier to read)
- Use `static` nested structs for ranges (aka [Voldemort types](http://wiki.dlang.org/Voldemort_types)) and thus store function parameters explicitly in the nested struct
- Avoid `unittest` in templates (it will generate a new unittest for each instance) - put your tests outside

### Code advice

- Don't be afraid to use the new compiler or language features (e.g. `Foo!Range` vs. `Foo!(Range)`)
- Be critical when looking at Phobos code (some parts of Phobos are a bit older and have some relics due to lacking functionality of the compiler)
- [ ] Is there an easier or more performant way to do it?
- [ ] Does your PR address only one topic? Can it be split up in smaller PRs?
- [ ] Is your code flexible enough to accommodate more use cases?
- [ ] Read through your code again - is there any part that is not understandable?

### Tests

- [Autotester](http://wiki.dlang.org/Git_Commit_Tester) will automatically compile the code in your PR and test it on all supported platforms. For your first PR you need approval from any reviewer - ping them in case they forget.
- [ ] Do all [tests pass locally](http://wiki.dlang.org/Starting_as_a_Contributor#Unittest_phobos)? You can run the tests of
	- single module or packages with `make -f posix.mak std/algorithm/comparison.test` or `make -f posix.mak std/algorithm.test`
	- all tests with `make -f posix.mak unittest` (add `-j NUMBER_OF_CORES` if you have multiple cores)
	- for small changes in a single module faster with `rdmd -main -unittest comparison.d` (be careful, this links to your current Phobos version)
	- for Windows have a look at [building Phobos under windows](http://wiki.dlang.org/Starting_as_a_Contributor#Windows_2))
- [ ] Do your tests cover all cases? (you can check code coverage in the resulting `module.lst` of `rdmd -cov -main -unittest module.d`)

### Review process

- All PRs _must_ pass all tests for all supported platforms of [autotester](http://wiki.dlang.org/Git_Commit_Tester) before they will be merged
- Big additions (new modules) should go to `std.experimental` first (after they pass the [review process](http://wiki.dlang.org/Review/Process))
- Smaller additions like individual functions can be merged directly after [@andralex](https://github.com/andralex) approves
- Refactoring or bug fixes just need approval (LGTM) from two reviewers and enough time passed (usually 2-3 days, depending on weekends and holidays) to give everyone an opportunity to shout
- For low-level changes the other compiler devs (GDC and LLVM) should be consulted
- Trivial changes (e.g. small documentation enhancements) are usually merged in less than 72h - otherwise ping for reviewers
- If your PR is stalled (no activity for 2-3 days) and you addressed all concerns, don't hesitate to ping your reviewers
- Ping [@9il](https://github.com/9il) for anything math related
- See [rebasing](#rebasing) if you need to sync your fork with master

### Naming

- Use a Capitalized short (50 chars or less) Git commit summary
- If necessary, wrap your Git explanation paragraph [to 72 chars](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
- [ ] Do you use clear variable names?
- [ ] Does your PR have a concise and informative title?
- [ ] Are your Git messages clear and informative (otherwise use `git commit --amend` for a single commit or `git rebase` for multiple commits)?
- Avoid having many commits per PR (usually one commit per PR) - see [squashing](#squashing) to combine commits

### Fixing issues

- Bug fix PRs should have a separate commit for each bugzilla issue that it fixes
- The message of the commit actually fixes the bug should start with "Fix issue X" where X is the number of the corresponding [bugzilla](https://issues.dlang.org) issue. For example:

```
+ Refactor the code assist with the bug fix
+ Fix issue 17000 - map doesn't accept some range types
+ Fix issue 17001 - map doesn't work with some other range type
```

- Unrelated fixes, refactorings or additions should preferably go separate pull request(s) (tightly related fixes are okay in the same PR)

Documentation
-------------

### Documentation style

- The documentation is written in [ddoc](http://dlang.org/spec/ddoc.html)
- Use complete English sentences with correct syntax, grammar, and punctuation
- Use precise technical terms. Avoids colloquialisms
- Honestly describe limitations and dangers
- Add `Params`, `Returns` and if needed `See_Also` sections
- Provide at least one ddoced unittest for a new method
- Have a brief one sentence summary for at the beginning of a method
- Give a synopsis at the beginning of a module accompanied by an example

### Documentation checks

- [ ] Read your documentation text aloud - is it understandable?
- [ ] Check the output of CyberShadows's DAutoTest of the documentation (or run [it](https://github.com/D-Programming-Language/dlang.org) yourself)
- [ ] All user impacting changes should have a corresponding [changelog](https://github.com/D-Programming-Language/phobos/blob/master/changelog.dd) entry
- [ ] Did you add your method to the summary booktable or cheatsheat of a module? (might be in `package.d`)

### Documentation tricks

- Use backticks `` `code` `` instead of `$(D foo)`
- Start with a Capital letter in all blocks of the method header
- Use `$(REF)` for links to other methods (format is `$(REF _stripLeft, std, algorithm, mutation)`)
- Use `$(REF_ALTTEXT)` for a different link name (format is `$(REF_ALTTEXT your text, formattedRead, std, format)`
- Variables will be automatically put in backticks, use an underscore to avoid this behavior (e.g. `_foo`)
- Section headings are marked by a line with a single word followed by a colon `:`, use an underscore to avoid this behavior (e.g. `with the following \n code:` needs `_code` to avoid the creation of a section)
- Section headings with multiple words should use underscores instead of spaces (e.g. `See_Also:`)
- Don't put examples in your ddoc header - use the `///` magic to annotate them. Ddoc will automatically add the annotated test(s) to the `Examples` section of the method, e.g.:

```
///
unittest
{
    assert(1 == 1);
}
```

- Use `/// ditto` to join multiple methods in the documentation

Squashing
---------

After receiving feedback on your PR, it's common for it to have lots of commits that don't add much by being separate. For example, consider the following git history on a PR:

```
commit [ffffff] Added new function: foobar
commit [aaaaaa] Spelling error fix in foobar docs
commit [cccccc] Clarified Docs for foobar
```

Nothing is gained from having these as three separate commits as they are all focused on one feature. Instead, they should be one commit so the history looks like this

```
commit [333333] Added new function: foobar
```

while still retaining all of your changes. In order to perform this, please consult this [guide](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History#Squashing-Commits)

You can also directly append to your last commit and force an update of your PR:

```
git commit --amend
git push -f
```

Rebasing
--------

Sometimes, if a particular change you are working on is taking a long time, or if you encounter a problem that is fixed by a new commit upstream, you may need to sync your local branch with master in order to keep the code up-to-date.

- Use `git rebase` to apply your changes on top of the latest git master, so that when you submit a pull request, the change history will be easier for the reviewers to follow.
- Using `git merge` is _not_ recommended, as it may produce a lot of merge commits that may not be relevant to your changes.

If you forked from the official D programming language repositories you may need to add an upstream remote to pull in the latest official changes. If this is the case you can add an upstream remote like this:

```
git remote add upstream git@github.com:D-Programming-Language/phobos
```

This adds another remote to your repository called upstream and only needs to be done once. In the future, you can update `upstream` by running `git fetch upstream`. Once the upstream remote is added, you can update your repository's master branch by running the following:

```
git checkout master
git pull --ff-only upstream master
```

The `--ff-only` option is to ensure that your master branch is identical to the official D sources' master branch, since otherwise you will end up with a very messy history that will be hard to clean up.

Now go back to your branch and rebase it:

```
git checkout mybranch
git rebase master
```

You may wish to read up on how git rebase works if you're not familiar with the concept.
If, during the [`git rebase`](http://git-scm.com/book/en/Git-Branching-Rebasing) command, you encounter conflicts, you may want to learn [how to resolve a conflict during git rebase](http://stackoverflow.com/questions/8780257/git-rebase-a-branch-onto-master-failed-how-to-resolve).

Now your sources should be up-to-date. Recompile and test everything to make sure it all works.

Note that after rebasing, you will need to force an update to your fork on GitHub with the -f flag, otherwise it will fail because the histories don't match anymore:

```
git push -f origin mybranch
```

Happy hacking!
--------------

If you find a new gotcha, don't hesitate to send a PR to this guide.

Thank you for your contribution!
