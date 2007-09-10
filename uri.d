
//debug=uri;		// uncomment to turn on debugging printf's

/* ====================== URI Functions ================ */

import ctype;
import c.stdlib;
import utf;

class URIerror : Error
{
    this()
    {
	super("URI error");
    }
}

enum
{
    URI_Alpha = 1,
    URI_Reserved = 2,
    URI_Mark = 4,
    URI_Digit = 8,
    URI_Hash = 0x10,		// '#'
}

char[16] hex2ascii = "0123456789ABCDEF";

ubyte[128] uri_flags;		// indexed by character

static this()
{
    // Initialize uri_flags[]

    static void helper(char[] p, uint flags)
    {	int i;

	for (i = 0; i < p.length; i++)
	    uri_flags[p[i]] |= flags;
    }

    uri_flags['#'] |= URI_Hash;

    for (int i = 'A'; i <= 'Z'; i++)
    {	uri_flags[i] |= URI_Alpha;
	uri_flags[i + 0x20] |= URI_Alpha;	// lowercase letters
    }
    helper("0123456789", URI_Digit);
    helper(";/?:@&=+$,", URI_Reserved);
    helper("-_.!~*'()",  URI_Mark);
}


private char[] URI_Encode(dchar[] string, uint unescapedSet)
{   uint len;
    uint j;
    uint k;
    dchar V;
    dchar C;

    // result buffer
    char *R;
    uint Rlen;
    uint Rsize;	// alloc'd size
    char buffer[50];

    len = string.length;

    R = buffer;
    Rsize = buffer.length;
    Rlen = 0;

    for (k = 0; k != len; k++)
    {
	C = string[k];
	// if (C in unescapedSet)
	if (C < uri_flags.length && uri_flags[C] & unescapedSet)
	{
	    if (Rlen == Rsize)
	    {	char* R2;

		Rsize *= 2;
		R2 = (char *)alloca(Rsize * char.size);
		if (!R2)
		    goto LthrowURIerror;
		R2[0..Rlen] = R[0..Rlen];
		R = R2;
	    }
	    R[Rlen] = cast(char)C;
	    Rlen++;
	}
	else
	{   char[6] Octet;
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
	    {	goto LthrowURIerror;		// undefined UCS code
	    }

	    if (Rlen + L * 3 > Rsize)
	    {	char *R2;

		Rsize = 2 * (Rlen + L * 3);
		R2 = (char *)alloca(Rsize * char.size);
		if (!R2)
		    goto LthrowURIerror;
		R2[0..Rlen] = R[0..Rlen];
		R = R2;
	    }

	    while (L--)
	    {
		R[Rlen] = '%';
		R[Rlen + 1] = hex2ascii[Octet[j] >> 4];
		R[Rlen + 2] = hex2ascii[Octet[j] & 15];

		Rlen += 3;
	    }
	}
    }

    char[] result = new char[Rlen];
    result[] = R[0..Rlen];
    return result;

LthrowURIerror:
    throw new URIerror();
    return null;
}

uint ascii2hex(dchar c)
{
    return (c <= '9') ? c - '0' :
	   (c <= 'F') ? c - 'A' + 10 :
			c - 'a' + 10;
}

private dchar[] URI_Decode(char[] string, uint reservedSet)
{   uint len;
    uint j;
    uint k;
    uint V;
    dchar C;
    char* s;

    //printf("URI_Decode('%.*s')\n", string);

    // Result array, allocated on stack
    dchar* R;
    uint Rlen;
    uint Rsize;	// alloc'd size

    len = string.length;
    s = string;

    // Preallocate result buffer R guaranteed to be large enough for result
    Rsize = len;
    R = cast(dchar *)alloca(Rsize * dchar.size);
    if (!R)
	goto LthrowURIerror;
    Rlen = 0;

    for (k = 0; k != len; k++)
    {	char B;
	uint start;

	C = s[k];
	if (C != '%')
	{   R[Rlen] = C;
	    Rlen++;
	    continue;
	}
	start = k;
	if (k + 2 >= len)
	    goto LthrowURIerror;
	if (!isxdigit(s[k + 1]) || !isxdigit(s[k + 2]))
	    goto LthrowURIerror;
	B = cast(char)((ascii2hex(s[k + 1]) << 4) + ascii2hex(s[k + 2]));
	k += 2;
	if ((B & 0x80) == 0)
	{
	    C = B;
	}
	else
	{   uint n;

	    for (n = 1; ; n++)
	    {
		if (n > 4)
		    goto LthrowURIerror;
		if (((B << n) & 0x80) == 0)
		{
		    if (n == 1)
			goto LthrowURIerror;
		    break;
		}
	    }

	    // Pick off (7 - n) significant bits of B from first byte of octet
	    V = B & ((1 << (7 - n)) - 1);	// (!!!)

	    if (k + (3 * (n - 1)) >= len)
		goto LthrowURIerror;
	    for (j = 1; j != n; j++)
	    {
		k++;
		if (s[k] != '%')
		    goto LthrowURIerror;
		if (!isxdigit(s[k + 1]) || !isxdigit(s[k + 2]))
		    goto LthrowURIerror;
		B = cast(char)((ascii2hex(s[k + 1]) << 4) + ascii2hex(s[k + 2]));
		if ((B & 0xC0) != 0x80)
		    goto LthrowURIerror;
		k += 2;
		V = (V << 6) | (B & 0x3F);
	    }
	    if (V > 0x10FFFF)
		goto LthrowURIerror;
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
    assert(Rlen <= Rsize);	// enforce our preallocation size guarantee

    // Copy array on stack to array in memory
    dchar[] d = new dchar[Rlen];
    d[] = R[0..Rlen];
    return d;


LthrowURIerror:
    throw new URIerror();
    return null;
}

char[] decode(char[] encodedURI)
{
    dchar[] s;

    s = URI_Decode(encodedURI, URI_Reserved | URI_Hash);
    return utf.toUTF8(s);
}

char[] decodeComponent(char[] encodedURIComponent)
{
    dchar[] s;

    s = URI_Decode(encodedURIComponent, 0);
    return utf.toUTF8(s);
}

char[] encode(char[] uri)
{
    dchar[] s;

    s = utf.toUTF32(uri);
    return URI_Encode(s, URI_Reserved | URI_Hash | URI_Alpha | URI_Digit | URI_Mark);
}

char[] encodeComponent(char[] uriComponent)
{
    dchar[] s;

    s = utf.toUTF32(uriComponent);
    return URI_Encode(s, URI_Alpha | URI_Digit | URI_Mark);
}

unittest
{
    debug(uri) printf("uri.encodeURI.unittest\n");

    char[] s = "http://www.digitalmars.com/~fred/fred's RX.html#foo";
    char[] t = "http://www.digitalmars.com/~fred/fred's%20RX.html#foo";
    char[] r;

    r = encode(s);
    //printf("r = '%.*s'\n", r);
    assert(r == t);
    r = decode(t);
    //printf("r = '%.*s'\n", r);
    assert(r == s);
}
