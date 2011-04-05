// Written in the D programming language
// written by Walter Bright
// www.digitalmars.com
// Placed into the public domain

/**
 * $(RED This module has been deprecated. Use $(LINK2 core_bitop.html,
 * core.bitop) instead.)
 *
 * These functions are built-in intrinsics to the compiler.
 *
        Intrinsic functions are functions built in to the compiler,
        usually to take advantage of specific CPU features that
        are inefficient to handle via external functions.
        The compiler's optimizer and code generator are fully
        integrated in with intrinsic functions, bringing to bear
        their full power on them.
        This can result in some surprising speedups.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Walter Bright
 * Source:    $(PHOBOSSRC std/_intrinsic.d)
 * Macros:
 *      WIKI=Phobos/StdIntrinsic
 */

module std.intrinsic;

deprecated:

pragma(msg, "std.intrinsic has been moved. Please import core.bitop instead.");

public import core.bitop;

