// Written in the D programming language.

/**
This module is a port of a growing fragment of the $(D_PARAM
functional) header in Alexander Stepanov's
$(LINK2 http://sgi.com/tech/stl, Standard Template Library).

 Macros:

 WIKI = Phobos/StdFunctional

 Author:

 Andrei Alexandrescu  
*/

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
 *  Written by Andrei Alexandrescu, www.erdani.org
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

module std.functional;

/**
   Predicate that returns $(D_PARAM a < b).
*/
bool less(T)(T a, T b) { return a < b; }

/**
   Predicate that returns $(D_PARAM a > b).
*/
bool greater(T)(T a, T b) { return a > b; }
