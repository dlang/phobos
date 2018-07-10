/**
Allows a more seamless integration of RCString into Phobos.
*/
module std.experimental.collections.rcstring_phobos;

import std.experimental.collections.rcstring;

// TODO: Still WIP and needs more introspection

private string defaultTemplate(string moduleName, string functionName)
{
    return q{
        auto }~functionName~q{(T)(rcstring rs, T rhs)
        }~'{'~q{
            import }~moduleName~" : " ~ functionName ~ q{;
            static if (is(T : rcstring))
                return rs.chars.}~functionName~q{(rhs.by!char);
            else
                return rs.chars.}~functionName~q{(rhs);
        }~'}';
}

private enum symbolList = [
    ["std.algorithm.comparison", "equal"],
    ["std.algorithm.searching", "find"],
];

static foreach (symbol; symbolList)
{
    //pragma(msg, defaultTemplate(symbol[0], symbol[1]));
    mixin(defaultTemplate(symbol[0], symbol[1]));
}

@safe unittest
{
    auto s = "aaa".rcstring;
    auto s2 = "bbb".rcstring;
    assert(!s.equal(s));
    assert(s.equal(s));
}

@safe unittest
{
    auto s = "aaa".rcstring;
    auto s2 = "bbb".rcstring;
    assert(!s.find(s).empty);
    assert(s.find(s).empty);
}

//auto writeln(T...)(rcstring rs, T rhs)
//{
    //import std.stdio : writeln;
    //return rs.chars.writeln(rhs);
//}
