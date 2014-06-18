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
 * Authors:   $(WEB digitalmars.com, Walter Bright), Anton Dutov
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
private import std.traits : isSomeChar;
import core.exception : OutOfMemoryError;
import std.exception : assumeUnique;

// Extra imports
import std.algorithm;
import std.array;
import std.conv;
import std.regex;
import std.path;
import std.typetuple;

private auto uriRegex = ctRegex!(`^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?`);

import std.socket;

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

size_t uriLength(Char)(in Char[] s) if (isSomeChar!Char)
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
size_t emailLength(Char)(in Char[] s) if (isSomeChar!Char)
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

    import std.typetuple : TypeTuple;
    foreach (StringType; TypeTuple!(char[], wchar[], dchar[], string, wstring, dstring))
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

/** URI struct
 * Examples:
 * --------------------
 * URI uri = "scheme://user:pass@hostname:1234/path?query=string#_fragment_";
 * auto s1 = uri.scheme;        // s1 = "scheme"
 * auto s2 = uri.authority;     // s2 = "user:pass@hostname:1234"
 * auto s3 = uri.auth;          // s3 = "user:pass"
 * auto s4 = uri.resource;      // s4 = "hostname:1234"
 * auto s5 = uri.pathAndQuery;  // s5 = "/path?query=string"
 * auto s6 = uri.username;      // s6 = "user"
 * auto s7 = uri.password;      // s7 = "user"
 * auto s8 = uri.host;          // s8 = "hostname"
 * auto p1 = uri.port;          // p1 = 1234
 * auto s9 = uri.path;          // s9 = "/path"
 * auto s10 = uri.query;        // s10 = "query=string"
 * auto s11 = uri.fragment;     // s11 = "_fragment_"
 * --------------------
 */
struct URI {
  private {
    struct Pair {
      string key;
      string val;
    }
    string  _scheme;
    string  _fragment;
    string  _host;
    string  _username;
    string  _password;
    string  _path;
    ushort  _port;
    Pair*[] _query;
  }
  /**
   * Create URI from string
   * Examples:
   * --------------------
   * auto uri = URI("http://dlang.org/");
   * --------------------
   */
  this(string uri) {
    opAssign(uri);
  }
  /**
   * Allows assign string to uri
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/";
   * uri = "http://code.dlang.org/";
   * --------------------
   */
  auto opAssign(string uri) {
    auto m = match(decode(uri), uriRegex);
    if (!m.empty) {
      _scheme   = m.front[2];
      authority = m.front[4];
      query     = m.front[7];
      path      = m.front[5];
      _fragment = m.front[9];
    }
  }

  /**
   * Return default port for this scheme.
   * if $(B fast) is true returns defined values for scheme: http, https for other schemas return $(B 0). else uses $(B std.socket.Service) to determine port
   * --------------------
   * URI uri = "http://dlang.org/";
   * auto p1 = uri.defaultPort();       // p1 = 80;
   * uri.scheme = "ftp";                // "ftp://dlang.org/"
   * auto p2 = uri.defaultPort();       // p2 = 0, because fast algorithm nothink know about "ftp"
   * auto p3 = uri.defaultPort!false(); // p3 = 21 (at most OS where service is defined)
   * --------------------
   */
  @property auto defaultPort(bool fast = true)() const {
    ushort p = 0;
    static if (fast) {
      switch(_scheme) {
      case "http":  p = 80;  break;
      case "https": p = 443; break;
      default:
      }
    } else {
      auto   s = new Service;
      if (s.getServiceByName(_scheme, "tcp")) {
        p = s.port;
      }
      delete s;
    }
    return p;
  }

  /**
   * Get/set URI scheme
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/";
   * auto s1 = uri.scheme;     // s1 = "http"
   * uri.scheme = "https";
   * auto s2 = uri.toString(); // "https://dlang.org/"
   * --------------------
   */
  @property auto scheme() const     { return _scheme; }
  /// ditto
  @property auto scheme(string s)   { return _scheme = s; }

  /**
   * Get/set URI username
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/";
   * auto s1 = uri.username;   // s1 = ""
   * uri.username = "anon";
   * auto s2 = uri.toString(); // s2 = "http://anon@dlang.org/"
   * --------------------
   */
  @property auto username() const   { return _username; }
  /// ditto
  @property auto username(string u) { return _username = u; }

  /**
   * Get/set URI username
   * Examples:
   * --------------------
   * URI uri = "http://anon:1234@dlang.org/";
   * auto s1 = uri.password;   // s1 = "1234"
   * uri.password = "qwert";
   * auto s2 = uri.toString(); // s2 = "http://anon:qwert@dlang.org/"
   * --------------------
   */
  @property auto password() const   { return _password; }
  /// ditto
  @property auto password(string p) { return _password = p; }

  /**
   * Get/set URI host
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/";
   * auto s1 = uri.host;          // s1 = "dlang.org"
   * uri.host = "code.dlang.org";
   * auto s2 = uri.toString();    // s2 = "http://code.dlang.org/"
   * --------------------
   */
  @property auto host() const       { return _host; }
  /// ditto
  @property auto host(string h)     { return _host = h; }

  /**
   * Get/set URI host
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/#first";
   * auto s1 = uri.fragment;   // s1 = "first"
   * uri.fragment = "second";
   * auto s2 = uri.toString(); // s2 = "http://dlang.org/#second"
   * --------------------
   */
  @property auto fragment() const   { return _fragment; }
  /// ditto
  @property auto fragment(string f) { return _fragment = f; }

  /**
   * Get/set URI port.
   * Returns $(B 0) if port not set
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/";
   * auto p1 = uri.port;       // p1 = 0
   * uri.port = 81;
   * auto s1 = uri.toString(); // s1 = "http://dlang.org:81/"
   * --------------------
   */
  @property auto port() const       { return _port; }
  /// ditto
  @property auto port(ushort p)     { return _port = p; }

  /**
   * Get/set URI path.
   * If path isn't empty string and not starts with $(B /), then append $(B /) at string start
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org";
   * auto s1 = uri.path;          // s1 = ""
   * uri.path = "download.html";  // converted to "/download.html"
   * auto s2 = uri.toString();    // s2 = "http://dlang.org/download.html"
   * auto s3 = uri.path;          // s3 = "/download.html"
   * --------------------
   */
  @property auto path() const       { return _path; }
  /// ditto
  @property auto path(string p)     { return _path = absolutePath(p, "/"); }

  /// Get
  @property auto pathAndQuery() const {
    auto tmp = appender!string;
    tmp.put(path);
    auto q = query;
    if (!q.empty) {
      tmp.put('?');
      tmp.put(q);
    }
    return tmp.data;
  }

  /**
   * Get/set URI query as string representation.
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/?x=1";
   * auto s1 = uri.query;        // s1 = "x=1"
   * uri.query = "z=2&y=4";
   * auto s2 = uri.toString();    // s2 = "http://dlang.org/?z=2&y=4"
   * --------------------
   */
  @property auto query() const {
    auto tmp = appender!string;
    foreach (p; _query) {
      if (p.key) {
        if (!tmp.data.empty)
          tmp.put("&");
        tmp.put(p.key);
        tmp.put('=');
        tmp.put(p.val);
      }
    }
    return tmp.data;
  }
  /// ditto
  @property auto query(string q) {
    _query = [];
    auto tmp = replace(q, "&amp;", "&");
    foreach(p; split(tmp, "&")) {
      auto kv = split(p, "=");
      if (kv.length && kv[0].length) {
        auto pair = new Pair;
        pair.key  = kv[0];
        pair.val  = kv.length > 1 ? kv[1] : "";
        _query ~= pair;
      }
    }
    return query;
  }
  @property auto queryEncoded() const {
    auto tmp = appender!string;
    foreach(p; _query) {
      if (p.key) {
        if (!tmp.data.empty)
          tmp.put('&');
        tmp.put(encodeComponent(p.key));
        tmp.put('=');
        tmp.put(encodeComponent(p.val));
      }
    }
    return tmp.data;
  }

  /**
   * Get/set URI authorization info
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/";
   * auto s1 = uri.auth;       // s1 = ""
   * uri.auth = "anon:1234";
   * auto s2 = uri.toString(); // s2 = "http://anon:1234@dlang.org/"
   * --------------------
   */
  @property string auth() const {
    auto tmp = appender!string;
    tmp.put(_username);
    if (_password.length) {
      tmp.put(':');
      tmp.put(_password);
    }
    return tmp.data;
  }

  /// ditto
  @property string auth(string a) {
    auto tmp = split(a, ":");
    _username = (tmp.length > 0) ? tmp[0] : "";
    _password = (tmp.length > 1) ? tmp[1] : "";
    return auth;
  }

  /**
   * Get/set URI resource info
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org:81/";
   * auto s1 = uri.auth;       // s1 = "dlang.org:81"
   * uri.auth = "code.dlang.org:82";
   * auto s2 = uri.toString(); // s2 = "http://code.dlang.org:82/"
   * --------------------
   */
  @property string resource() const {
    auto tmp = appender!string;
    tmp.put(_host);
    if (_port && _port != defaultPort) {
      tmp.put(':');
      tmp.put(to!string(_port));
    }
    return tmp.data;
  }
  /// ditto
  @property string resource(string r) {
    auto tmp = split(r, ":");
    _host = (tmp.length > 0) ? tmp[0] : "";
    try {
      _port = to!ushort((tmp.length > 1) ? tmp[1] : "0");
    } catch {}
    return resource;
  }

  /// Get/set
  @property string authority() const {
    auto tmp = appender!string;
    tmp.put(auth);
    auto tmp2 = resource;

    if (!tmp.data.empty)
      tmp.put('@');

    if (tmp2.length)
      tmp.put(tmp2);

    return tmp.data;
  }
  /// ditto
  @property string authority(string a) {
    auto tmp = split(a, "@");
    resource = (tmp.length == 1) ? tmp[0] : (tmp.length > 1) ? tmp[1] : "";
    auth     = (tmp.length >  1) ? tmp[0] : "";
    return authority;
  }

  /**
   * Returns all values for $(B key)
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/?x=1&x=a";
   * auto x = uri.all("x"); // x = ["1","a"]
   * auto z = uri.all("z"); // z = []
   * --------------------
   */
  string[] all(string key) {
    auto tmp = appender!(string[]);
    foreach(p; _query) {
      if (p.key == key) {
        tmp.put(p.val);
      }
    }
    return tmp.data;
  }

  /**
   * Insert one more value with name $(B key)es for $(B key)
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/?x=1&x=a";
   * uri.insert("x", "1");
   * uri.insert("x", "2");
   * auto x = uri.all("x"); // x = ["1","2"]
   * --------------------
   */
  void insert(string key, string val) {
    _query ~= new URI.Pair(key, val);
  }

  /**
   * Remove all values with name $(B key)
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/?x=1&x=a";
   * uri.remove("x");
   * auto s = uri.toString(); // s = "http://dlang.org/"
   * --------------------
   */
  void remove(string key) {
    long pos = 0;
    while (pos >= 0) {
      auto e = _query.find!("a.key == b")(key);
      if (!e.length)
        break;
      pos = _query.countUntil(e[0]);
      _query = std.algorithm.remove(_query, pos);
    }
  }

  /**
   * Get query value with name $(B key), $(B returns empty string for non exists values)
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/?x=1";
   * auto x = uri["x"]; // x = "1";
   * auto z = uri["z"]; // z = "";
   * --------------------
   */
  string opIndex(string key) {
    foreach(p; _query) {
      if (p.key == key) {
        return p.val;
      }
    }
    return "";
  }
  /**
   * Set query value with name $(B key), if some values by this key are defined, replaces first value
   * Examples:
   * --------------------
   * URI uri = "http://dlang.org/?x=1&x=2&y=3";
   * uri["x"] = "3";          // Replace first "x" value
   * uri["y"] = "1";          // Replace "y" value
   * uri["z"] = "0";          // Add "z" value
   * auto s = uri.toString(); // s = "http://dlang.org/?x=3&x=2&y=1&z=0"
   * --------------------
   */
  void opIndexAssign(string val, string key) {
    auto len = _query.length;
    for (auto i = 0; i < len; ++i){
      if (_query[i].key == key) {
        _query[i].val = val;
        return;
      }
    }
    _query ~= new Pair(key, val);
  }
  string toString() const {
    string tmp;
    if (_scheme.length) {
      tmp ~= _scheme ~ ":";
    }
    auto a = authority;
    auto q = query;
    if (a.length) {
      if (tmp.length) {
        tmp ~= "//";
      }
      tmp ~= a;
    }
    if (_path) {
      tmp ~= _path;
    }
    if (q.length) {
      tmp ~= "?" ~ q;
    }
    if (_fragment.length) {
      tmp ~= "#" ~ _fragment;
    }
    return tmp;
  }
  string toEncoded() const {
    return std.uri.encode(toString);
  }

  ///
  unittest {
    auto i = URI("http://foo:bar@baz:1234/to?key=val&array=e1&array=e2#id1");
    assert(i.scheme       == "http");
    assert(i.username     == "foo");
    assert(i.password     == "bar");
    assert(i.host         == "baz");
    assert(i.port         == 1234);
    assert(i.path         == "/to");
    assert(i.pathAndQuery == "/to?key=val&array=e1&array=e2");
    assert(i.query        == "key=val&array=e1&array=e2");
    assert(i["key"]       == "val");
    assert(i.all("array") == ["e1","e2"]);
    assert(i.fragment     == "id1");
    assert(i.auth         == "foo:bar");
    assert(i.resource     == "baz:1234");
    assert(i.authority    == "foo:bar@baz:1234");
    assert(to!string(i)   == "http://foo:bar@baz:1234/to?key=val&array=e1&array=e2#id1");
    i.remove("array");
    assert(to!string(i)   == "http://foo:bar@baz:1234/to?key=val#id1");
    i["key"] = "val1";
    i.insert("key","val2");
    assert(to!string(i)   == "http://foo:bar@baz:1234/to?key=val1&key=val2#id1");

    auto url = "http://ru.wikipedia.org/wiki/D_(%D1%8F%D0%B7%D1%8B%D0%BA_%D0%BF%D1%80%D0%BE%D0%B3%D1%80%D0%B0%D0%BC%D0%BC%D0%B8%D1%80%D0%BE%D0%B2%D0%B0%D0%BD%D0%B8%D1%8F)";
    auto e = URI(url);
    assert(e.path == "/wiki/D_(язык_программирования)");
    assert(e.toString() == "http://ru.wikipedia.org/wiki/D_(язык_программирования)");
    assert(e.toEncoded() == url);
  }
}
