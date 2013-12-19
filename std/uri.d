// Written in the D programming language.

/**
 * Encode and decode Uniform Resource Identifiers (URIs).
 * URIs are used in internet transfer protocols.
 * Valid URI characters consist of letters, digits,
 * and the characters $(B ;/?:@&amp;=+$,-_.!~*'())
 * Reserved URI characters are $(B ;/?:@&amp;=+$,)
 * Escape sequences consist of $(B %) followed by two hex digits.
 *
 * See_Also:
 *  $(LINK2 http://www.ietf.org/rfc/rfc3986.txt, RFC 3986)<br>
 *  $(LINK2 http://en.wikipedia.org/wiki/Uniform_resource_identifier, Wikipedia)
 * Macros:
 *  WIKI = Phobos/StdUri
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_uri.d)
 */
/*          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.uri;

//debug=uri;        // uncomment to turn on debugging writefln's
debug(uri) private import std.stdio;

/* ====================== URI Functions ================ */

private import std.ascii;
private import std.c.stdlib;
private import std.utf;
import core.exception : OutOfMemoryError;
import std.exception : assumeUnique;

class URIException : Exception
{
    @safe pure nothrow this()
    {
        super("URI Exception");
    }

    @safe pure nothrow this(string msg)
    {
        super("URI Exception: " ~ msg);
    }
}

enum
{
    URI_Alpha = 1,
    URI_Reserved = 2,
    URI_Mark = 4,
    URI_Digit = 8,
    URI_Hash = 0x10,        // '#'
}

immutable char[16] hex2ascii = "0123456789ABCDEF";

__gshared ubyte[128] uri_flags;       // indexed by character

shared static this()
{
    // Initialize uri_flags[]
    static void helper(immutable char[] p, uint flags)
    {
        for (int i = 0; i < p.length; i++)
            uri_flags[p[i]] |= flags;
    }

    uri_flags['#'] |= URI_Hash;

    for (int i = 'A'; i <= 'Z'; i++)
    {
        uri_flags[i] |= URI_Alpha;
        uri_flags[i + 0x20] |= URI_Alpha;   // lowercase letters
    }
    helper("0123456789", URI_Digit);
    helper(";/?:@&=+$,", URI_Reserved);
    helper("-_.!~*'()",  URI_Mark);
}


private string URI_Encode(dstring string, uint unescapedSet)
{
    uint j;
    uint k;
    dchar V;
    dchar C;

    // result buffer
    char[50] buffer = void;
    char* R;
    uint Rlen;
    uint Rsize; // alloc'd size

    auto len = string.length;

    R = buffer.ptr;
    Rsize = buffer.length;
    Rlen = 0;

    for (k = 0; k != len; k++)
    {
        C = string[k];
        // if (C in unescapedSet)
        if (C < uri_flags.length && uri_flags[C] & unescapedSet)
        {
            if (Rlen == Rsize)
            {
                char* R2;

                Rsize *= 2;
                if (Rsize > 1024) {
                    R2 = (new char[Rsize]).ptr;
                }
                else
                {
                    R2 = cast(char *)alloca(Rsize * char.sizeof);
                    if (!R2)
                        throw new OutOfMemoryError("Alloca failure");
                }
                R2[0..Rlen] = R[0..Rlen];
                R = R2;
            }
            R[Rlen] = cast(char)C;
            Rlen++;
        }
        else
        {
            char[6] Octet;
            uint L;

            V = C;

            // Transform V into octets
            if (V <= 0x7F)
            {
                Octet[0] = cast(char) V;
                L = 1;
            }
            else if (V <= 0x7FF)
            {
                Octet[0] = cast(char)(0xC0 | (V >> 6));
                Octet[1] = cast(char)(0x80 | (V & 0x3F));
                L = 2;
            }
            else if (V <= 0xFFFF)
            {
                Octet[0] = cast(char)(0xE0 | (V >> 12));
                Octet[1] = cast(char)(0x80 | ((V >> 6) & 0x3F));
                Octet[2] = cast(char)(0x80 | (V & 0x3F));
                L = 3;
            }
            else if (V <= 0x1FFFFF)
            {
                Octet[0] = cast(char)(0xF0 | (V >> 18));
                Octet[1] = cast(char)(0x80 | ((V >> 12) & 0x3F));
                Octet[2] = cast(char)(0x80 | ((V >> 6) & 0x3F));
                Octet[3] = cast(char)(0x80 | (V & 0x3F));
                L = 4;
            }
            /+
            else if (V <= 0x3FFFFFF)
            {
                Octet[0] = cast(char)(0xF8 | (V >> 24));
                Octet[1] = cast(char)(0x80 | ((V >> 18) & 0x3F));
                Octet[2] = cast(char)(0x80 | ((V >> 12) & 0x3F));
                Octet[3] = cast(char)(0x80 | ((V >> 6) & 0x3F));
                Octet[4] = cast(char)(0x80 | (V & 0x3F));
                L = 5;
            }
            else if (V <= 0x7FFFFFFF)
            {
                Octet[0] = cast(char)(0xFC | (V >> 30));
                Octet[1] = cast(char)(0x80 | ((V >> 24) & 0x3F));
                Octet[2] = cast(char)(0x80 | ((V >> 18) & 0x3F));
                Octet[3] = cast(char)(0x80 | ((V >> 12) & 0x3F));
                Octet[4] = cast(char)(0x80 | ((V >> 6) & 0x3F));
                Octet[5] = cast(char)(0x80 | (V & 0x3F));
                L = 6;
            }
            +/
            else
            {
                throw new URIException("Undefined UTF-32 code point");
            }

            if (Rlen + L * 3 > Rsize)
            {
                char *R2;

                Rsize = 2 * (Rlen + L * 3);
                if (Rsize > 1024) {
                    R2 = (new char[Rsize]).ptr;
                }
                else
                {
                    R2 = cast(char *)alloca(Rsize * char.sizeof);
                    if (!R2)
                        throw new OutOfMemoryError("Alloca failure");
                }
                R2[0..Rlen] = R[0..Rlen];
                R = R2;
            }

            for (j = 0; j < L; j++)
            {
                R[Rlen] = '%';
                R[Rlen + 1] = hex2ascii[Octet[j] >> 4];
                R[Rlen + 2] = hex2ascii[Octet[j] & 15];

                Rlen += 3;
            }
        }
    }

    return R[0..Rlen].idup;
}

uint ascii2hex(dchar c)
{
    return (c <= '9') ? c - '0' :
        (c <= 'F') ? c - 'A' + 10 :
        c - 'a' + 10;
}

private dstring URI_Decode(string string, uint reservedSet)
{
    uint j;
    uint k;
    uint V;
    dchar C;

    // Result array, allocated on stack
    dchar* R;
    uint Rlen;

    auto len = string.length;
    auto s = string.ptr;

    // Preallocate result buffer R guaranteed to be large enough for result
    auto Rsize = len;
    if (Rsize > 1024 / dchar.sizeof) {
        R = (new dchar[Rsize]).ptr;
    }
    else
    {
        R = cast(dchar *)alloca(Rsize * dchar.sizeof);
        if (!R)
            throw new OutOfMemoryError("Alloca failure");
    }
    Rlen = 0;

    for (k = 0; k != len; k++)
    {
        char B;
        uint start;

        C = s[k];
        if (C != '%')
        {
            R[Rlen] = C;
            Rlen++;
            continue;
        }
        start = k;
        if (k + 2 >= len)
            throw new URIException("Unexpected end of URI");
        if (!isHexDigit(s[k + 1]) || !isHexDigit(s[k + 2]))
            throw new URIException("Expected two hexadecimal digits after '%'");
        B = cast(char)((ascii2hex(s[k + 1]) << 4) + ascii2hex(s[k + 2]));
        k += 2;
        if ((B & 0x80) == 0)
        {
            C = B;
        }
        else
        {
            uint n;

            for (n = 1; ; n++)
            {
                if (n > 4)
                    throw new URIException("UTF-32 code point size too large");
                if (((B << n) & 0x80) == 0)
                {
                    if (n == 1)
                        throw new URIException("UTF-32 code point size too small");
                    break;
                }
            }

            // Pick off (7 - n) significant bits of B from first byte of octet
            V = B & ((1 << (7 - n)) - 1);   // (!!!)

            if (k + (3 * (n - 1)) >= len)
                throw new URIException("UTF-32 unaligned String");
            for (j = 1; j != n; j++)
            {
                k++;
                if (s[k] != '%')
                    throw new URIException("Expected: '%'");
                if (!isHexDigit(s[k + 1]) || !isHexDigit(s[k + 2]))
                    throw new URIException("Expected two hexadecimal digits after '%'");
                B = cast(char)((ascii2hex(s[k + 1]) << 4) + ascii2hex(s[k + 2]));
                if ((B & 0xC0) != 0x80)
                    throw new URIException("Incorrect UTF-32 multi-byte sequence");
                k += 2;
                V = (V << 6) | (B & 0x3F);
            }
            if (V > 0x10FFFF)
                throw new URIException("Unknown UTF-32 code point");
            C = V;
        }
        if (C < uri_flags.length && uri_flags[C] & reservedSet)
        {
            // R ~= s[start .. k + 1];
            int width = (k + 1) - start;
            for (int ii = 0; ii < width; ii++)
                R[Rlen + ii] = s[start + ii];
            Rlen += width;
        }
        else
        {
            R[Rlen] = C;
            Rlen++;
        }
    }
    assert(Rlen <= Rsize);  // enforce our preallocation size guarantee

    // Copy array on stack to array in memory
    return R[0..Rlen].idup;
}

/*************************************
 * Decodes the URI string encodedURI into a UTF-8 string and returns it.
 * Escape sequences that resolve to reserved URI characters are not replaced.
 * Escape sequences that resolve to the '#' character are not replaced.
 */

string decode(string encodedURI)
{
    auto s = URI_Decode(encodedURI, URI_Reserved | URI_Hash);
    return std.utf.toUTF8(s);
}

/*******************************
 * Decodes the URI string encodedURI into a UTF-8 string and returns it. All
 * escape sequences are decoded.
 */

string decodeComponent(string encodedURIComponent)
{
    auto s = URI_Decode(encodedURIComponent, 0);
    return std.utf.toUTF8(s);
}

/*****************************
 * Encodes the UTF-8 string uri into a URI and returns that URI. Any character
 * not a valid URI character is escaped. The '#' character is not escaped.
 */

string encode(string uri)
{
    auto s = std.utf.toUTF32(uri);
    return URI_Encode(s, URI_Reserved | URI_Hash | URI_Alpha | URI_Digit | URI_Mark);
}

/********************************
 * Encodes the UTF-8 string uriComponent into a URI and returns that URI.
 * Any character not a letter, digit, or one of -_.!~*'() is escaped.
 */

string encodeComponent(string uriComponent)
{
    auto s = std.utf.toUTF32(uriComponent);
    return URI_Encode(s, URI_Alpha | URI_Digit | URI_Mark);
}

/***************************
 * Does string s[] start with a URL?
 * Returns:
 *  -1    it does not
 *  len  it does, and s[0..len] is the slice of s[] that is that URL
 */

size_t uriLength(string s)
{
    /* Must start with one of:
     *  http://
     *  https://
     *  www.
     */
    import std.string : icmp;

    size_t i;

    if (s.length <= 4)
        return -1;

    if (s.length > 7 && std.string.icmp(s[0 .. 7], "http://") == 0) {
        i = 7;
    }
    else
    {
        if (s.length > 8 && std.string.icmp(s[0 .. 8], "https://") == 0)
            i = 8;
        else
            return -1;
    }
    //    if (icmp(s[0 .. 4], "www.") == 0)
    //  i = 4;

    size_t lastdot;
    for (; i < s.length; i++)
    {
        auto c = s[i];
        if (isAlphaNum(c))
            continue;
        if (c == '-' || c == '_' || c == '?' ||
                c == '=' || c == '%' || c == '&' ||
                c == '/' || c == '+' || c == '#' ||
                c == '~' || c == '$')
            continue;
        if (c == '.')
        {
            lastdot = i;
            continue;
        }
        break;
    }
    //if (!lastdot || (i - lastdot != 3 && i - lastdot != 4))
    if (!lastdot)
        return -1;

    return i;
}

unittest
{
    string s1 = "http://www.digitalmars.com/~fred/fredsRX.html#foo end!";
    assert (uriLength(s1) == 49);
    string s2 = "no uri here";
    assert (uriLength(s2) == -1);
}


/***************************
 * Does string s[] start with an email address?
 * Returns:
 *  -1    it does not
 *  len   it does, and s[0..i] is the slice of s[] that is that email address
 * References:
 *  RFC2822
 */
size_t emailLength(string s)
{
    size_t i;

    if (!isAlpha(s[0]))
        return -1;

    for (i = 1; 1; i++)
    {
        if (i == s.length)
            return -1;
        auto c = s[i];
        if (isAlphaNum(c))
            continue;
        if (c == '-' || c == '_' || c == '.')
            continue;
        if (c != '@')
            return -1;
        i++;
        break;
    }

    /* Now do the part past the '@'
     */
    size_t lastdot;
    for (; i < s.length; i++)
    {
        auto c = s[i];
        if (isAlphaNum(c))
            continue;
        if (c == '-' || c == '_')
            continue;
        if (c == '.')
        {
            lastdot = i;
            continue;
        }
        break;
    }
    if (!lastdot || (i - lastdot != 3 && i - lastdot != 4))
        return -1;

    return i;
}

unittest
{
    string s1 = "my.e-mail@www.example-domain.com with garbage added";
    assert (emailLength(s1) == 32);
    string s2 = "no email address here";
    assert (emailLength(s2) == -1);
}


unittest
{
    debug(uri) writeln("uri.encodeURI.unittest");

    string s = "http://www.digitalmars.com/~fred/fred's RX.html#foo";
    string t = "http://www.digitalmars.com/~fred/fred's%20RX.html#foo";

    auto r = encode(s);
    debug(uri) writefln("r = '%s'", r);
    assert(r == t);
    r = decode(t);
    debug(uri) writefln("r = '%s'", r);
    assert(r == s);

    r = encode( decode("%E3%81%82%E3%81%82") );
    assert(r == "%E3%81%82%E3%81%82");

    r = encodeComponent("c++");
    assert(r == "c%2B%2B");

    auto str = new char[10_000_000];
    str[] = 'A';
    r = encodeComponent(assumeUnique(str));
    foreach (char c; r)
        assert(c == 'A');

    r = decode("%41%42%43");
    debug(uri) writeln(r);
}
