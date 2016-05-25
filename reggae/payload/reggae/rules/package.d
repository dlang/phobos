/**
 This package and its modules provide high-level rules for building
 software written in C, C++ and D. For obtaining object files from
 any of these, please consult targetsFromSourceFiles in common.d.
 For D-specific rules, consult d.d. For dub, dub.d.
 */

module reggae.rules;

public import reggae.core.rules;

version(minimal) {
} else {
    public import reggae.rules.common;
    public import reggae.rules.d;
    public import reggae.rules.dub;
    public import reggae.rules.c_and_cpp;
}
