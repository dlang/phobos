/**
 This file is never actually used in production. It owes its existence
 to allowing the UTs to build and flycheck to not complain.
 */

module reggae.config;

import reggae.types;
import reggae.options;
import reggae.ctaa;

version(minimal) {
    enum isDubProject = false;
} else {
    enum isDubProject = true;
}

immutable Options gDefaultOptions = Options(Backend.ninja,
            "",
            "",
            "",
            "gcc",
            "g++",
            "dmd",
            false,
            false,
            true, //perModule only for UTs, false in real world
            isDubProject,
            false,
);

Options gOptions = gDefaultOptions.dup;

Options options() @safe nothrow {
    return gOptions;
}

void setOptions(Options options) {
    gOptions = options;
}

void setDefaultOptions() {
    gOptions = gDefaultOptions.dup;
}

enum userVars = AssocList!(string, string)();

version(minimal) {}
else {
    import reggae.dub.info;
    import reggae.ctaa;

    enum dubInfo = ["default": DubInfo() ];
    enum configToDubInfo = AssocList!(string, DubInfo)();
}
