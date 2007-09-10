
/*
 *  Copyright (C) 2006 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
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

module internal.match;

import std.regexp;

/******************************
 * Return handle to results if input[] matches regular expression pattern[],
 * null if not.
 */

extern (C) _Match* _d_match(char[] pattern, char[] input)
{
    return cast(_Match*)std.regexp.search(input, pattern);
}

/******************************
 * Returns !=null for next match.
 */

extern (C) _Match* _d_match_next(_Match* h)
{
    RegExp r = cast(RegExp)h;
    return r.test() ? h : null;
}
