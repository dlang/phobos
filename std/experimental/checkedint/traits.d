/**
Templates to facilitate treating $(REF SmartInt, std,experimental,checkedint) and $(REF SafeInt, std,experimental,checkedint) like the built-in
numeric types in generic code.

Copyright: Copyright Thomas Stuart Bockman 2015
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors: Thomas Stuart Bockman
Source:  $(PHOBOSSRC std/checkedint/_traits.d)

This module wraps various templates from $(MREF std, _traits) to make them `checkedint`-aware. For example,
`std.traits.isSigned!(SmartInt!int)` is `false`, but `checkedint.traits.isSigned!(SmartInt!int)` is `true`.

This module is separate from `checkedint` because it is only useful in generic code, and its symbols (deliberately)
conflict with some from `std.traits`.
**/
module std.experimental.checkedint.traits;
version(unittest)
{
    import std.experimental.checkedint.asserts : SmartInt;
    import std.meta : AliasSeq;
}

// checkedint.flags //////////////////////////////////////
static import ciFlags = std.experimental.checkedint.flags;

    /// See $(REF _intFlagPolicyOf, std,experimental,checkedint,flags)
    alias intFlagPolicyOf = ciFlags.intFlagPolicyOf;


// checkedint ////////////////////////////////////////////
static import chkd = std.experimental.checkedint;

    /// See $(REF _isSafeInt, std,experimental,checkedint)
    alias isSafeInt = chkd.isSafeInt;

    /// See $(REF _isSmartInt, std,experimental,checkedint)
    alias isSmartInt = chkd.isSmartInt;

    /// See $(REF _isCheckedInt, std,experimental,checkedint)
    alias isCheckedInt = chkd.isCheckedInt;

    /// See $(REF _hasBitOps, std,experimental,checkedint)
    alias hasBitOps = chkd.hasBitOps;

    /// See $(REF _BasicScalar, std,experimental,checkedint)
    alias BasicScalar = chkd.BasicScalar;


// std.traits ////////////////////////////////////////////
static import bsct = std.traits;

    private template isEx(alias Predicate, T)
    {
        static if (isCheckedInt!T)
            enum isEx = Predicate!(BasicScalar!T);
        else
            enum isEx = Predicate!T;
    }

    /// See $(REF isScalarType, std,traits)
    alias isBasicScalar = bsct.isScalarType;
    /// `checkedint`-aware wrapper for $(REF _isScalarType, std,traits)
    template isScalarType(T)
    {
        alias isScalarType = isEx!(isBasicScalar, T);
    }
    ///
    unittest
    {
        foreach (T; AliasSeq!(int, ushort, double, bool))
            assert(isBasicScalar!T && isScalarType!T);

        assert(!isBasicScalar!(SmartInt!int));
        assert( isScalarType!(SmartInt!int));

        foreach (T; AliasSeq!(int[]))
            assert(!(isBasicScalar!T || isScalarType!T));
    }

    /// See $(REF isNumeric, std,traits)
    alias isBasicNum = bsct.isNumeric;
    /// `checkedint`-aware wrapper for $(REF _isNumeric, std,traits)
    template isNumeric(T)
    {
        alias isNumeric = isEx!(isBasicNum, T);
    }
    ///
    unittest
    {
        foreach (T; AliasSeq!(int, ushort, double))
            assert(isBasicNum!T && isNumeric!T);

        assert(!isBasicNum!(SmartInt!int));
        assert( isNumeric!(SmartInt!int));

        foreach (T; AliasSeq!(int[], bool))
            assert(!(isBasicNum!T || isNumeric!T));
    }

    /// See $(REF _isFloatingPoint, std,traits)
    alias isFloatingPoint = bsct.isFloatingPoint;
/+
    /// See $(REF isFixedPoint, std,traits)
    alias isBasicFixed = bsct.isFixedPoint;
    /// `checkedint`-aware wrapper for $(REF isFixedPoint, std,traits)
    template isFixedPoint(T)
    {
        alias isFixedPoint = isEx!(isBasicFixed, T);
    }
    ///
    unittest
    {
        foreach (T; AliasSeq!(int, ushort, bool))
            assert(isBasicFixed!T && isFixedPoint!T);

        assert(!isBasicFixed!(SmartInt!int));
        assert( isFixedPoint!(SmartInt!int));

        foreach (T; AliasSeq!(double, int[]))
            assert(!(isBasicFixed!T || isFixedPoint!T));
    }
+/
    /// See $(REF isIntegral, std,traits)
    alias isBasicInt = bsct.isIntegral;
    /// `checkedint`-aware wrapper for $(REF _isIntegral, std,traits)
    template isIntegral(T)
    {
        alias isIntegral = isEx!(isBasicInt, T);
    }
    ///
    unittest
    {
        foreach (T; AliasSeq!(int, ushort))
            assert(isBasicInt!T && isIntegral!T);

        assert(!isBasicInt!(SmartInt!int));
        assert( isIntegral!(SmartInt!int));

        foreach (T; AliasSeq!(double, int[], bool))
            assert(!(isBasicInt!T || isIntegral!T));
    }

    /// See $(REF _isSomeChar, std,traits)
    alias isSomeChar = bsct.isSomeChar;
    /// See $(REF _isBoolean, std,traits)
    alias isBoolean = bsct.isBoolean;

    /// See $(REF isSigned, std,traits)
    alias isBasicSigned = bsct.isSigned;
    /// `checkedint`-aware wrapper for $(REF _isSigned, std,traits)
    template isSigned(T)
    {
        alias isSigned = isEx!(isBasicSigned, T);
    }
    ///
    unittest
    {
        foreach (T; AliasSeq!(int, double))
            assert(isBasicSigned!T && isSigned!T);

        assert(!isBasicSigned!(SmartInt!int));
        assert( isSigned!(SmartInt!int));

        foreach (T; AliasSeq!(ushort, int[], bool))
            assert(!(isBasicSigned!T || isSigned!T));
    }

    /// See $(REF isUnsigned, std,traits)
    alias isBasicUnsigned = bsct.isUnsigned;
    /// `checkedint`-aware wrapper for $(REF _isUnsigned, std,traits)
    template isUnsigned(T)
    {
        alias isUnsigned = isEx!(isBasicUnsigned, T);
    }
    ///
    unittest
    {
        foreach (T; AliasSeq!(ushort))
            assert(isBasicUnsigned!T && isUnsigned!T);

        assert(!isBasicUnsigned!(SmartInt!uint));
        assert( isUnsigned!(SmartInt!uint));

        foreach (T; AliasSeq!(double, int[], bool))
            assert(!(isBasicUnsigned!T || isUnsigned!T));
    }

    /// `checkedint`-aware version of $(REF _mostNegative, std,traits)
    template mostNegative(T)
        if (isNumeric!T)
    {
        static if (isFloatingPoint!T)
            enum mostNegative = -T.max;
        else
            enum mostNegative =  T.min;
    }
    ///
    unittest
    {
        assert(mostNegative!int == int.min);
        static assert(is(typeof(mostNegative!int) == int));
        assert(mostNegative!(SmartInt!int) == SmartInt!(int).min);
        static assert(is(typeof(mostNegative!(SmartInt!int)) == SmartInt!int));
    }

    private template TransEx(alias TypeTransform, T)
    {
        static if (isCheckedInt!T)
        {
            import std.experimental.checkedint : SmartInt, SafeInt;
            import std.traits : CopyTypeQualifiers, Select;

            alias TTB = TypeTransform!(CopyTypeQualifiers!(T, BasicScalar!T));
            alias CheckedInt = Select!(isSmartInt!T, SmartInt, SafeInt);
            alias TransEx = CopyTypeQualifiers!(TTB, CheckedInt!(TTB, intFlagPolicyOf!T, hasBitOps!T));
        } else
            alias TransEx = TypeTransform!T;
    }

    /// `checkedint`-aware wrapper for $(REF _Signed, std,traits)
    template Signed(T)
    {
        alias Signed = TransEx!(bsct.Signed, T);
    }
    ///
    unittest
    {
        static assert(is(Signed!int == int));
        static assert(is(Signed!(SmartInt!int) == SmartInt!int), Signed!(SmartInt!int).stringof);
        static assert(is(Signed!ulong == long));
        static assert(is(Signed!(SmartInt!ulong) == SmartInt!long));
    }

    /// `checkedint`-aware wrapper for $(REF _Unsigned, std,traits)
    template Unsigned(T)
    {
        alias Unsigned = TransEx!(bsct.Unsigned, T);
    }
    ///
    unittest
    {
        static assert(is(Unsigned!int == uint));
        static assert(is(Unsigned!(SmartInt!int) == SmartInt!uint));
        static assert(is(Unsigned!ulong == ulong));
        static assert(is(Unsigned!(SmartInt!ulong) == SmartInt!ulong));
    }
/+
    /// `checkedint`-aware wrapper for $(REF Promoted, std,traits)
    template Promoted(T)
    {
        alias Promoted = TransEx!(bsct.Promoted, T);
    }
    ///
    unittest
    {
        static assert(is(Promoted!byte == int));
        static assert(is(Promoted!(SmartInt!byte) == SmartInt!int));
        static assert(is(Promoted!int == int));
        static assert(is(Promoted!(SmartInt!int) == SmartInt!int));
    }
+/
