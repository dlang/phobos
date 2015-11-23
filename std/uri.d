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
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
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
private import core.stdc.stdlib;
private import std.utf;
private import std.traits : isSomeChar;
import core.exception : OutOfMemoryError;
import std.exception : assumeUnique;

/** This Exception is thrown if something goes wrong when encoding or
decoding a URI.
*/
class URIException : Exception
{
    import std.array : empty;
    @safe pure nothrow this(string msg, string file = __FILE__,
        size_t line = __LINE__, Throwable next = null)
    {
        super("URI Exception" ~ (!msg.empty ? ": " ~ msg : ""), file, line,
            next);
    }
}

private enum
{
    URI_Alpha = 1,
    URI_Reserved = 2,
    URI_Mark = 4,
    URI_Digit = 8,
    URI_Hash = 0x10,        // '#'
}

immutable char[16] hex2ascii = "0123456789ABCDEF";

immutable ubyte[128] uri_flags =      // indexed by character
    ({
        ubyte[128] uflags;

        // Compile time initialize
        uflags['#'] |= URI_Hash;

        foreach (c; 'A' .. 'Z' + 1)
        {
            uflags[c] |= URI_Alpha;
            uflags[c + 0x20] |= URI_Alpha;   // lowercase letters
        }
        foreach (c; '0' .. '9' + 1) uflags[c] |= URI_Digit;
        foreach (c; ";/?:@&=+$,")   uflags[c] |= URI_Reserved;
        foreach (c; "-_.!~*'()")    uflags[c] |= URI_Mark;
        return uflags;
    })();

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

private dstring URI_Decode(Char)(in Char[] uri, uint reservedSet) if (isSomeChar!Char)
{
    uint j;
    uint k;
    uint V;
    dchar C;

    // Result array, allocated on stack
    dchar* R;
    uint Rlen;

    auto len = uri.length;
    auto s = uri.ptr;

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

string decode(Char)(in Char[] encodedURI) if (isSomeChar!Char)
{
    auto s = URI_Decode(encodedURI, URI_Reserved | URI_Hash);
    return std.utf.toUTF8(s);
}

/*******************************
 * Decodes the URI string encodedURI into a UTF-8 string and returns it. All
 * escape sequences are decoded.
 */

string decodeComponent(Char)(in Char[] encodedURIComponent) if (isSomeChar!Char)
{
    auto s = URI_Decode(encodedURIComponent, 0);
    return std.utf.toUTF8(s);
}

/*****************************
 * Encodes the UTF-8 string uri into a URI and returns that URI. Any character
 * not a valid URI character is escaped. The '#' character is not escaped.
 */

string encode(Char)(in Char[] uri) if (isSomeChar!Char)
{
    auto s = std.utf.toUTF32(uri);
    return URI_Encode(s, URI_Reserved | URI_Hash | URI_Alpha | URI_Digit | URI_Mark);
}

/********************************
 * Encodes the UTF-8 string uriComponent into a URI and returns that URI.
 * Any character not a letter, digit, or one of -_.!~*'() is escaped.
 */

string encodeComponent(Char)(in Char[] uriComponent) if (isSomeChar!Char)
{
    auto s = std.utf.toUTF32(uriComponent);
    return URI_Encode(s, URI_Alpha | URI_Digit | URI_Mark);
}

/***************************
 * Does string s[] start with a URL?
 * Returns:
 *  -1   it does not
 *  len  it does, and s[0..len] is the slice of s[] that is that URL
 */

ptrdiff_t uriLength(Char)(in Char[] s) if (isSomeChar!Char)
{
    /* Must start with one of:
     *  http://
     *  https://
     *  www.
     */
    import std.uni : icmp;

    ptrdiff_t i;

    if (s.length <= 4)
        return -1;

    if (s.length > 7 && icmp(s[0 .. 7], "http://") == 0) {
        i = 7;
    }
    else
    {
        if (s.length > 8 && icmp(s[0 .. 8], "https://") == 0)
            i = 8;
        else
            return -1;
    }
    //    if (icmp(s[0 .. 4], "www.") == 0)
    //  i = 4;

    ptrdiff_t lastdot;
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

///
unittest
{
    string s1 = "http://www.digitalmars.com/~fred/fredsRX.html#foo end!";
    assert (uriLength(s1) == 49);
    string s2 = "no uri here";
    assert (uriLength(s2) == -1);
    assert (uriLength("issue 14924") < 0);
}


/***************************
 * Does string s[] start with an email address?
 * Returns:
 *  -1    it does not
 *  len   it does, and s[0..i] is the slice of s[] that is that email address
 * References:
 *  RFC2822
 */
ptrdiff_t emailLength(Char)(in Char[] s) if (isSomeChar!Char)
{
    ptrdiff_t i;

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
    ptrdiff_t lastdot;
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

///
unittest
{
    string s1 = "my.e-mail@www.example-domain.com with garbage added";
    assert (emailLength(s1) == 32);
    string s2 = "no email address here";
    assert (emailLength(s2) == -1);
    assert (emailLength("issue 14924") < 0);
}


unittest
{
    debug(uri) writeln("uri.encodeURI.unittest");

    string source = "http://www.digitalmars.com/~fred/fred's RX.html#foo";
    string target = "http://www.digitalmars.com/~fred/fred's%20RX.html#foo";

    auto result = encode(source);
    debug(uri) writefln("result = '%s'", result);
    assert(result == target);
    result = decode(target);
    debug(uri) writefln("result = '%s'", result);
    assert(result == source);

    result = encode(decode("%E3%81%82%E3%81%82"));
    assert(result == "%E3%81%82%E3%81%82");

    result = encodeComponent("c++");
    assert(result == "c%2B%2B");

    auto str = new char[10_000_000];
    str[] = 'A';
    result = encodeComponent(str);
    foreach (char c; result)
        assert(c == 'A');

    result = decode("%41%42%43");
    debug(uri) writeln(result);

    import std.meta : AliasSeq;
    foreach (StringType; AliasSeq!(char[], wchar[], dchar[], string, wstring, dstring))
    {
        import std.conv : to;
        StringType decoded1 = source.to!StringType;
        string encoded1 = encode(decoded1);
        assert(decoded1 == source.to!StringType); // check that `decoded1` wasn't changed
        assert(encoded1 == target);
        assert(decoded1 == decode(encoded1).to!StringType);

        StringType encoded2 = target.to!StringType;
        string decoded2 = decode(encoded2);
        assert(encoded2 == target.to!StringType); // check that `encoded2` wasn't changed
        assert(decoded2 == source);
        assert(encoded2 == encode(decoded2).to!StringType);
    }
}


/* ====================== URI Struct ================ */
void enforceURI(bool chk, lazy string msg) pure
{
    if (!chk)
    {
        throw new URIException(msg);
    }
}

/** URI struct
 */
struct URI
{
    private
    {
        struct Opt
        {
            bool  reqDSlash;
            bool  reqAuthority;
        }
        string      _scheme;
        string      _fragment;
        string      _host;
        string      _username;
        string      _password;
        string      _path;
        ushort      _port;
        URIQuery    _query;


        static pure auto takeOpt(const(char)[] s)
        {
            Opt opt;
            switch(s)
            {
                case "ftp", "sftp", "http", "https", "spdy":
                    opt.reqDSlash    = true;
                    opt.reqAuthority = true;
                    break;
                case "file":
                    opt.reqDSlash    = true;
                    break;
                case "mailto":
                    opt.reqAuthority = true;
                    break;
                default:
            }
            return opt;
        }
    }

    /// Create URI from string
    this (string uri)
    {
        opAssign(uri);
    }
    ///
    unittest
    {
        import std.conv;
        auto u = URI("http://dlang.org/");
        assert(to!string(u) == "http://dlang.org/");
    }

    ///Allows assign string to uri
    void opAssign(string src)
    {
        this = URI.init;

        enforceURI(src.length != 0, "URI string is empty");

        if ( src[0] != '/' )
        {
            bool hasDSlash = false;
            auto idx = src.indexOf(':');
            scheme = (idx < 0) ? "" : src[0 .. idx];
            src = src[idx + 1 .. $];

            if (src.startsWith("//"))
            {
                hasDSlash = true;
                src = src[2 .. $];
            }

            auto opt = takeOpt(_scheme);
            if (opt.reqDSlash && !hasDSlash)
            {
                throw new URIException(text("URI must start with '", _scheme, "://'"));
            }

            auto pathIdx = src.indexOf('/');
            if ( pathIdx < 0 )
            {
                pathIdx = src.length;
            }

            if (opt.reqAuthority && src[0 .. pathIdx].empty)
            {
                throw new URIException(text("Schema '", _scheme,"' requires authority"));
            }
            authority = src[0 .. pathIdx];
            src = src[pathIdx  .. $];
        }

        auto fragIdx = src.indexOf('#');
        if( fragIdx >= 0 )
        {
            _fragment = src[fragIdx + 1 .. $];
            src = src[0 .. fragIdx];
        }

        auto qIdx = src.indexOf('?');

        if( qIdx >= 0 )
        {
            query = src[qIdx + 1 .. $];
            src   = src[0 .. qIdx];
        }
        path  = src;
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org/";
        assert(to!string(u) == "http://dlang.org/");
        u = "http://code.dlang.org/404";
        assert(to!string(u) == "http://code.dlang.org/404");
    }

    /// Get/set URI scheme
    @property string scheme() const pure nothrow
    {
        return _scheme;
    }
    /// ditto
    @property string scheme(string src) pure
    {
        enforceURI(src.length != 0, "URI scheme is empty");
        return _scheme = src;
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org/";
        assert(u.scheme == "http");
        u.scheme = "https";
        assert(to!string(u) == "https://dlang.org/");
    }

    /// Get/set URI username
    @property string username() const pure nothrow
    {
        return _username;
    }
    /// ditto
    @property string username(string u) pure nothrow
    {
        return _username = u;
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org/";
        assert(u.username == "");
        u.username = "anon";
        assert(to!string(u) == "http://anon@dlang.org/");
    }

    /// Get/set URI password
    @property string password() const pure nothrow
    {
        return _password;
    }
    /// ditto
    @property string password(string p) pure nothrow
    {
        return _password = p;
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://anon:1234@dlang.org/";
        assert(u.password == "1234");
        u.password = "qwert";
        assert(to!string(u) == "http://anon:qwert@dlang.org/");
    }

    /// Get/set URI host
    @property string host() const pure nothrow
    {
        return _host;
    }
    /// ditto
    @property string host(string h) pure nothrow
    {
        return _host = h;
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org/";
        assert(u.host == "dlang.org");
        u.host = "code.dlang.org";
        assert(to!string(u) == "http://code.dlang.org/");
    }

    /// Get/set URI fragment
    @property string fragment() const pure nothrow
    {
        return _fragment;
    }
    /// ditto
    @property string fragment(string f) pure nothrow
    {
        return _fragment = f;
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org/#first";
        assert(u.fragment == "first");
        u.fragment = "second";
        assert(to!string(u) == "http://dlang.org/#second");
    }

    /// Get/set URI port.
    /// Returns $(B 0) if port not set
    @property ushort port() const pure nothrow
    {
        return _port;
    }
    /// ditto
    @property ushort port(ushort p) pure nothrow
    {
        return _port = p;
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org/";
        assert(u.port == 0);  // Port not set
        u.port = 81;
        assert(to!string(u) == "http://dlang.org:81/");
    }

    /// Get/set URI path.
    @property string path() const pure nothrow
    {
        return _path;
    }
    /// ditto
    @property string path(string p)
    {
        return _path = decode(p);
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org";
        assert(u.path == "");
        u.path = "/download.html";  // converted to "/download.html"
        assert(to!string(u) == "http://dlang.org/download.html");
        assert(u.path == "/download.html");
    }

    // May be usefull for HTTP requests where first line is "METHOD path?query HTTP/ver"
    // Or may be replace with template wrap
    //@property auto pathAndQuery() const
    //{
    //  auto tmp = appender!string;
    //  tmp.put(path);
    //  auto q = query;
    //  if (!q.empty) {
    //    tmp.put('?');
    //    tmp.put(q);
    //  }
    //  return tmp.data;
    //}

    /// Reference to URIQuery
    @property ref URIQuery query() pure
    {
        return _query;
    }

    /// Get/set URI userInfo
    @property string userInfo() const pure nothrow
    {
        auto tmp = appender!string;
        tmp.put(_username);
        if (_password.length)
        {
            tmp.put(':');
            tmp.put(_password);
        }
        return tmp.data;
    }
    /// ditto
    @property void userInfo(string src) pure
    {
        auto passIdx = src.indexOf(':');
        if ( passIdx >= 0 )
        {
            _username = src[0 ..  passIdx];
            _password = src[passIdx + 1 .. $];
        }
        else
        {
            _username = src;
        }
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org/";
        assert(u.userInfo == "");
        u.userInfo = "anon:1234";
        assert(to!string(u) == "http://anon:1234@dlang.org/");
    }

    /// Get/set URI resource info
    @property string resource() const pure nothrow
    {
        auto tmp = appender!string;
        tmp.put(_host);
        if (_port)
        {
            tmp.put(':');
            tmp.put(to!string(_port));
        }
        return tmp.data;
    }
    /// ditto
    @property void resource(string src) pure
    {
        auto portIdx = src.indexOf(':');
        if ( portIdx >= 0 )
        {
            _host = src[0 .. portIdx];

            enforceURI(src[portIdx + 1 .. $].length !=0, "Empty port part");

            _port = to!ushort(src[portIdx + 1 .. $]);
        }
        else
        {
            _host = src;
        }
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "http://dlang.org:81/";
        assert(u.resource == "dlang.org:81");
        u.resource = "code.dlang.org:82";
        assert(to!string(u) == "http://code.dlang.org:82/");
    }

    /// Get/set
    @property string authority() const pure nothrow
    {
        auto tmp = appender!string;
        tmp.put(userInfo);
        auto tmp2 = resource;

        if (!tmp.data.empty)
            tmp.put('@');

        if (tmp2.length)
            tmp.put(tmp2);

        return tmp.data;
    }
    /// ditto
    @property void authority(string src) pure
    {
        auto atIdx = src.indexOf('@');
        if ( atIdx >= 0 ) {
            userInfo = src[0 .. atIdx];
            resource = src[atIdx + 1 .. $];
        } else {
            resource = src;
        }
    }
    ///
    unittest
    {
        import std.conv;
        URI u = "mailto:noreply@dlang.org";
        assert(u.authority == "noreply@dlang.org");
        u.authority = "non-exists@dlang.org";
        assert(to!string(u) == "mailto:non-exists@dlang.org");
    }

    /// To string representation
    void toString(scope void delegate(const(char)[]) sink) const
    {
        auto opt = takeOpt(_scheme);
        sink(_scheme);
        sink(":");
        auto a = authority;
        auto q = to!string(_query);
        if (a.length)
        {
            if (opt.reqDSlash)
            {
                sink("//");
            }
            sink(a);
        }
        if (!_path.empty)
        {
            sink(_path);
        }
        if (!q.empty)
        {
            sink("?");
            sink(q);
        }
        if (_fragment.length)
        {
            sink("#");
            sink(_fragment);
        }
    }
    ///
    unittest
    {
        import std.conv;
        URI  u = "http://en.wikipedia.org/wiki/D_%28programming_language%29";
        assert(to!string(u) == "http://en.wikipedia.org/wiki/D_(programming_language)");
    }

    /// To encoded string representation
    string toEncoded() const
    {
        return encode(to!string(this));
    }
    ///
    unittest
    {
        auto s = "http://ru.wikipedia.org/wiki/D_(%D1%8F%D0%B7%D1%8B%D0%BA_%D0%BF%D1%80%D0%BE%D0%B3%D1%80%D0%B0%D0%BC%D0%BC%D0%B8%D1%80%D0%BE%D0%B2%D0%B0%D0%BD%D0%B8%D1%8F)";
        URI  e = s;
        assert(e.path == "/wiki/D_(язык_программирования)");
        assert(to!string(e) == "http://ru.wikipedia.org/wiki/D_(язык_программирования)");
        assert(e.toEncoded() == s);
    }
    /// TODO: campare operator
}
///
unittest
{
    import std.conv;
    // Basic
    URI u = "scheme://user:pass@hostname:1234/path?query=string#_fragment_";
    assert(u.scheme == "scheme");
    assert(u.authority == "user:pass@hostname:1234");
    assert(u.userInfo == "user:pass");
    assert(u.resource == "hostname:1234");
    assert(u.username == "user");
    assert(u.password == "pass");
    assert(u.host == "hostname");
    assert(u.port == 1234);
    assert(u.path == "/path");
    assert(to!string(u.query) == "query=string");
    assert(u.query["query"] == "string");
    assert(u.query.get("query") == "string");
    assert(u.fragment == "_fragment_");
}


/** URIQuery struct
 * Storage for query key-value pairs.
 * Also can be used as storage for HTTP form fields.
 * Represent multivalued associative array with decoding on assign.
 */
struct URIQuery
{
    private
    {
        string[][string]    _data;
    }

    /// Create URIQuery from string
    this(string uri)
    {
        opAssign(uri);
    }
    ///
    void opAssign(string q)
    {
        _data = null;

        foreach (pairs; split(q, "&"))
        {
            auto kv = split(pairs, "=");

            if (kv.length && kv[0].length)
            {
                insert(kv[0], kv.length > 1 ? kv[1] : "");
            }
        }
    }
    ///
    unittest
    {
        import std.conv;

        auto q1 = URIQuery("x=1");
        assert(q1["x"] == "1");
        assert(to!string(q1) == "x=1");

        URIQuery q2 = "y=2";
        assert(q2["y"] == "2");
        assert(to!string(q2) == "y=2");
    }

    /// Returns $(B true) if key present in storage
    bool has(string key) const pure nothrow
    {
        return (key in _data) !is null;
    }
    ///
    unittest
    {
        URIQuery q = "x=1";
        assert(q.has("x") == true);
        assert(q.has("z") == false);
    }

    /// Returns all values for $(B key).
    /// If key not present in storage returns empty list.
    /// Values order same as in original string.
    string[] all(string key) const pure nothrow
    {
        string[] result;
        auto tmp = key in _data;
        if (tmp !is null)
        {
            result = (*tmp).dup;
        }
        return result;
    }
    ///
    unittest
    {
        URIQuery q = "x=1&x=a";
        assert(q.all("x") == ["1","a"]);
        assert(q.all("z") == []);
    }

    /// Returns key list
    string[] keys() const pure nothrow
    {
        return _data.keys;
    }
    ///
    unittest
    {
        URIQuery q = "x=1&x=a";
        assert(q.keys == ["x"]);
    }

    /// Get query value with name $(B key), returns defVal for non exists keys
    string get(string key, lazy string defVal = "") const pure
    {
        auto tmp = key in _data;
        return tmp !is null ? (*tmp)[$ - 1] : defVal;
    }
    ///
    unittest
    {
        URIQuery q = "x=1&y=2";
        assert(q.get("x") == "1");
        assert(q.get("y", "7") == "2");
        assert(q.get("z", "42") == "42");
    }

    /// Insert one or more values with same $(B key)
    /// Decodes key/value at insert
    /// Keeps insert order
    void insert(string key, string val)
    {
        _data[decode(key)] ~= decode(val);
    }
    ///
    unittest
    {
        URIQuery q;
        q.insert("x", "1");
        q.insert("x", "2");
        assert(q.all("x") == ["1","2"]);
    }

    /// Remove all values for $(B key)
    void remove(string key) pure nothrow
    {
        _data.remove(key);
    }
    ///
    unittest
    {
        import std.conv;
        URIQuery q = "x=1&x=a&y=5";
        q.remove("x");
        assert(to!string(q) == "y=5");
    }

    /// Get value by $(B key), throw exception for non exists keys
    string opIndex(string key) const pure
    {
        auto val = get(key, null);
        enforceURI(val !is null, text("Key '", key, "' not exists"));
        return val;
    }
    ///
    unittest
    {
        URIQuery q = "x=1";
        assert(q["x"] == "1");

        try
        {
            assert(q["z"] == "");
        }
        catch(Exception e)
        {
            assert(e.msg == "URI Exception: Key 'z' not exists");
        }
    }

    /// Set query by $(B key), if some values by this key are defined, replaces last value
    void opIndexAssign(string val, string key)
    {
        auto k = decode(key);
        auto v = decode(val);
        auto tmp = k in _data;
        if (tmp is null)
        {
            _data[k] = [v];
        }
        else
        {
            _data[k][$ - 1] = v;
        }
    }
    ///
    unittest
    {
        URIQuery q = "x=1&x=2&y=3";
        q["x"] = "3";          // Replace last "x" value
        q["y"] = "1";          // Replace "y" value
        q["z"] = "0";          // Add "z" value

        assert(q["x"] == "3");
        assert(q.all("x") == ["1","3"]);
        assert(q["y"] == "1");
        assert(q.all("y") == ["1"]);
        assert(q["z"] == "0");
        assert(q.all("z") == ["0"]);
    }

    /// Sink-based toString method
    void toString(scope void delegate(const(char)[]) sink) const
    {
        bool isFirst = true;
        foreach (key, values; _data)
        {
            if (!key.length)
            {
                continue;
            }

            if (isFirst)
            {
                isFirst = false;
            }
            else
            {
                sink("&");
            }

            foreach (value; values)
            {
                sink(key);
                sink("=");
                sink(value);
            }
        }
    }
    ///
    unittest
    {
        import std.conv;
        URIQuery q = "x=1";
        assert(to!string(q) == "x=1");
    }


    /// Encoded values string
    string toEncoded() const
    {
        auto tmp = appender!string;
        foreach (key, values; _data)
        {
            if (!key.length)
            {
                continue;
            }
            if (!tmp.data.empty)
            {
                tmp.put("&");
            }
            foreach (value; values)
            {
                tmp.put(encode(key));
                tmp.put('=');
                tmp.put(encode(value));
            }
        }
        return tmp.data;
    }
    ///
    unittest
    {
        URIQuery q = "%D0%B8%D0%BC%D1%8F=%D0%B7%D0%BD%D0%B0%D1%87%D0%B5%D0%BD%D0%B8%D0%B5";
        assert(q["имя"] == "значение");
        assert(q.toEncoded == "%D0%B8%D0%BC%D1%8F=%D0%B7%D0%BD%D0%B0%D1%87%D0%B5%D0%BD%D0%B8%D0%B5");
    }
}
