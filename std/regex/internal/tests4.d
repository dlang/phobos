/*
    Regualar expressions package test suite part 4.
*/
module std.regex.internal.tests4;

package(std.regex):

import std.algorithm, std.array, std.regex;

// bugzilla 17066
unittest
{
    string message = "fix issue 16319 and fix std.traits.isInnerClass";
    static auto matchToRefs(M)(M m)
    {
        // ctRegex throws a weird error in unittest compilation
        enum splitRE = regex(`[^\d]+`);
        return m.captures[5].splitter(splitRE);
    }

    enum issueRE = ctRegex!(`((close|fix|address)e?(s|d)? )` ~
        `?(ticket|bug|tracker item|issue)s?:? *([\d ,\+&#and]+)`, "i");
    auto r = message.matchAll(issueRE);
    r.map!matchToRefs.joiner.array;
}
