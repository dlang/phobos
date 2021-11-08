module std2xalpha.algorithm.comparison;

// This will be an often-used idiom to fetch the prev version of a module.
import v1 = std.algorithm.comparison;

/**
[@@@TODO@@@ Documentation specific for version 2. It should be appended to the default as
implementation notes for this specific version.]
*/
alias mismatch = v1.canon!"std2xalpha".mismatch;

///
unittest
{
    // `ö` and `ü` are two bytes wide and both start with 0xC3
    auto s1 = "öabc", s2 = "üabc";
    auto a = v1.mismatch(s1, s2);
    // With autodecoding, the mismatch will be on the first element
    assert(a[0] is s1 && a[1] is s2);
    auto b = mismatch("öabc", "üabc");
    // Without autodecoding, the mismatch will skip the first byte!
    assert(b[0] is s1[1 .. $] && b[1] is s2[1 .. $]);
}
