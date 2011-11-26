// Written in the D programming language.

/**
 * Identify the compiler used and its various features.
 *
 * Macros:
 *      WIKI = Phobos/StdCompiler
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_compiler.d)
 */
/*          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.compiler;

pragma(msg, "std.compiler has been deprecated in favor of core.compiler in druntime");

public import core.compiler;

alias core.compiler.compilerName name;
alias core.compiler.compilerVendor vendor;

alias core.compiler.compilerMajor version_major;
alias core.compiler.compilerMinor version_minor;

alias core.compiler.languageMajor D_major;
alias core.compiler.languageMinor D_minor;
