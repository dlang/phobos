# Phobos 3 Contributors Guide

This document refers to contributions specific to Phobos 3. For the full documentation on contributing please see the guide here: [D Contributors Guide](https://github.com/dlang/phobos/blob/master/CONTRIBUTING.md).

## Naming and Style Guidelines

Names should follow the existing naming guidelines here: [D Style Guide](https://dlang.org/dstyle.html)

When selecting a name for a type or method, a quick survey of how other popular languages name the equivalent type/method should be performed. For example, in .NET and Java, the `currTime()` method would be named `now()`. Using the same names as popular languages reduces the friction experienced by the engineer when migrating to D. Be prepared to provide examples from your survey in the Pull Request. In cases where there is no clear agreement or two examples are equally represented an alias *may* be appropriate for the purposes of moving past the block.

Prefer whole words over abbreviations and dropped letters. For example, prefer `writeLine` over `writeln`. Choose the shortest name that accurately describes the feature. Abbreviations are acceptable where the abbreviation is in common usage and/or would result in a cumbersome name. Furthermore, non-standard abbreviations make it more difficult for non-English speakers to adopt the library.

Phobos will use a 100 soft and 120 hard character column limit. This will be enforced via `dfmt` and `.editorconfig` files provided with the distribution.

## Guidelines for Reviewers

### Silence is Approval

One of the complaints the community has made about D in general and Phobos in particular is that many PRs go un-reviewed and are left to rot. Therefore, in Phobos 3, if you are listed as a reviewer on a PR and you do not respond to a within 7 days to a pull request, your silence will be considered an approval. If the required reviewer is unavailable for any reason (ex: vacation, emergency, etc.), another reviewer can bypass them. Once they return they can provide comments and submit PR's to address any feedback on the PR's assigned to them that they missed.

### Disagreement Without Providing a Fix or Alternative is Approval

Another major community complaint is that PR's are routinely abandoned because somebody disagrees with how the PR does something, or believes that it will cause a problem, causing the PR to stall out. While the reviewer may be correct, simple disagreement cannot be sufficient reason to block a PR without providing any alternative implementation. Therefore, the disagreeing reviewer must either provide a PR/patch to the primary PR or provide an alternative implementation in a new PR that addresses their concern. The disagreeing reviewer must ensure that their PR references the original PR. If no alternatives are provided, the PR will be merged and the disagreeing reviewer is welcome to base their future alternative implementation on the merged work.
