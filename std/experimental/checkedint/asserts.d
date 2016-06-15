/**
Aliases for the $(MREF std,experimental, checkedint) module using `IntFlagPolicy.asserts`.

Copyright: Copyright Thomas Stuart Bockman 2015
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors: Thomas Stuart Bockman
Source:  $(PHOBOSSRC std/checkedint/_asserts.d)
**/
module std.experimental.checkedint.asserts;

import std.traits, std.typecons;

@safe: pragma(inline, true):

static import ciFlags = std.experimental.checkedint.flags;
public import std.experimental.checkedint.flags :
    IntFlagPolicy,
    IntFlag,
    IntFlags,
    CheckedIntException;
private alias IFP = IntFlagPolicy;

alias raise = ciFlags.raise!(IFP.asserts);

static import checkedint = std.experimental.checkedint;

alias SmartInt(N, Flag!"bitOps" bitOps = Yes.bitOps) = checkedint.SmartInt!(N, IFP.asserts, bitOps);
SmartInt!(N, bitOps) smartInt(Flag!"bitOps" bitOps = Yes.bitOps, N)(N num) pure nothrow @nogc
    if (isIntegral!N || isCheckedInt!N)
{
    return typeof(return)(num.bscal);
}
alias smartOp = checkedint.smartOp!(IFP.asserts);

alias DebugInt(N, Flag!"bitOps" bitOps = Yes.bitOps) = checkedint.DebugInt!(N, IFP.asserts, bitOps);

alias SafeInt(N, Flag!"bitOps" bitOps = Yes.bitOps) = checkedint.SafeInt!(N, IFP.asserts, bitOps);
SafeInt!(N, bitOps) safeInt(Flag!"bitOps" bitOps = Yes.bitOps, N)(N num) pure nothrow @nogc
    if (isIntegral!N || isCheckedInt!N)
{
    return typeof(return)(num.bscal);
}
alias safeOp = checkedint.safeOp!(IFP.asserts);

alias to(T) = checkedint.to!(T, IFP.asserts);

Select!(isSigned!(BasicScalar!N), ptrdiff_t, size_t) idx(N)(const N num) pure nothrow @nogc
    if (isScalarType!N || isCheckedInt!N)
{
    return checkedint.to!(typeof(return), IFP.asserts)(num.bscal);
}

public import std.experimental.checkedint :
    bscal,
    bits,
    isSafeInt,
    isSmartInt,
    isCheckedInt,
    hasBitOps,
    intFlagPolicyOf,
    BasicScalar;
