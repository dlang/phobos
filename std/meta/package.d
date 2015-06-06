// Written in the D programming language.
/**
 * Templates to manipulate $(LINK2 ../template.html#TemplateArgumentList, template argument lists)).
 * Those are also commonly called "type lists" if only contain type arguments. In some contexts
 * terms "expression tuple" and "type tuple" may be used but those are discouraged to avoid
 * any confusion with $(LINK2 std_typecons.html#tuple, std.typecons.tuple).
 *
 * Some operations on such argument lists are built into the language. This
 * is explained in more details in the $(LINK2 ../ctarguments.html, website).
 *
 * Several templates in this module use or operate on eponymous templates that
 * take a single argument and evaluate to a boolean constant. Such templates
 * are referred to as $(I template predicates).
 *
 * References:
 *  Based on ideas in Table 3.1 from
 *  $(LINK2 http://amazon.com/exec/obidos/ASIN/0201704315/ref=ase_classicempire/102-2957199-2585768,
 *      Modern C++ Design),
 *   Andrei Alexandrescu (Addison-Wesley Professional, 2001)
 * Macros:
 *  WIKI = Phobos/StdArguments
 *
 * Copyright: Copyright Digital Mars 2005 - 2015.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:
 *     $(WEB digitalmars.com, Walter Bright),
 *     $(WEB klickverbot.at, David Nadlinger)
 * Source:    $(PHOBOSSRC std/_meta/package.d)
 */

module std.meta;

public import std.meta.arglist;
