/**
Aliases for the $(MREF std,experimental, checkedint) module using `IntFlagPolicy.noex`.

Copyright: Copyright Thomas Stuart Bockman 2015
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors: Thomas Stuart Bockman
Source:  $(PHOBOSSRC std/checkedint/_noex.d)
**/
module std.experimental.checkedint.noex;

import std.traits, std.typecons;

@safe: pragma(inline, true):

static import ciFlags = std.experimental.checkedint.flags;
public import std.experimental.checkedint.flags :
    IntFlagPolicy,
    IntFlag,
    IntFlags,
    CheckedIntException;
private alias IFP = IntFlagPolicy;

alias raise = ciFlags.raise!(IFP.noex);

static import checkedint = std.experimental.checkedint;

alias SmartInt(N, Flag!"bitOps" bitOps = Yes.bitOps) = checkedint.SmartInt!(N, IFP.noex, bitOps);
SmartInt!(N, bitOps) smartInt(Flag!"bitOps" bitOps = Yes.bitOps, N)(N num) nothrow @nogc
    if (isIntegral!N || isCheckedInt!N)
{
    return typeof(return)(num.bscal);
}
alias smartOp = checkedint.smartOp!(IFP.noex);

alias DebugInt(N, Flag!"bitOps" bitOps = Yes.bitOps) = checkedint.DebugInt!(N, IFP.noex, bitOps);

alias SafeInt(N, Flag!"bitOps" bitOps = Yes.bitOps) = checkedint.SafeInt!(N, IFP.noex, bitOps);
SafeInt!(N, bitOps) safeInt(Flag!"bitOps" bitOps = Yes.bitOps, N)(N num) nothrow @nogc
    if (isIntegral!N || isCheckedInt!N)
{
    return typeof(return)(num.bscal);
}
alias safeOp = checkedint.safeOp!(IFP.noex);

alias to(T) = checkedint.to!(T, IFP.noex);

Select!(isSigned!(BasicScalar!N), ptrdiff_t, size_t) idx(N)(const N num) nothrow @nogc
    if (isScalarType!N || isCheckedInt!N)
{
    return checkedint.to!(typeof(return), IFP.noex)(num.bscal);
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
