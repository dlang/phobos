/**
	Encodes and decodes punycode strings, per
	$(LINK2 https://www.ietf.org/rfc/rfc3492.txt, RFC3492).
	Punycode is primarily used for converting URIs or IRIs containing non-ASCII
	characters into URIs or IRIs that are entirely ASCII, and vice versa.
	This punycode codec is based upon the original implementation found in
	$(LINK2 https://www.ietf.org/rfc/rfc3492.txt, RFC3492).

	Authors: Shotaro Yamada (Sinkuu)
	Date: February 27, 2017
	License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
	Standards: $(LINK2 https://www.ietf.org/rfc/rfc3492.txt, RFC3492)
	Source: $(PHOBOSSRC std/net/_punycode.d)
	Version: 1.0.1
*/
module punycode;

private import std.ascii : isASCII, isUpper, isLower, isDigit;
private import std.conv : to;
private import std.exception : enforce;
private import std.traits : isSomeString;
private import std.array : insertInPlace;
private import std.algorithm.searching : all;

version (unittest)
{
	import std.exception : assertThrown, collectExceptionMsg;
}

private immutable uint base = 36;
private immutable ubyte initialN = 0x80;
private immutable uint initialBias = 72;
private immutable uint tmin = 1;
private immutable uint tmax = 26;
private immutable uint damp = 700;
private immutable uint skew = 38;

/**
	Converts an UTF string to a Punycode string.
	Params: str = A UTF-encoded string that should be encoded into Punycode
	Returns: A punycode-encoded string
	Throws: PunycodeException if an internal error occured
*/
S punyEncode(S)(in S str) @safe pure
	if (isSomeString!S)
{
	import std.functional : not;
	import std.algorithm.iteration : filter;
	import std.array : array, appender, Appender;
	import std.algorithm.sorting : sort;

	static char encodeDigit(uint x)
	{
		if (x <= 25) return cast(char)('a' + x);
		else if (x <= 35) return cast(char)('0' + x - 26);
		assert(0);
	}

	dstring dstr = str.to!dstring;
	auto ret = appender!S;
	ret ~= dstr.filter!isASCII;
	assert(ret.data.length <= uint.max);
	uint handledLength = cast(uint)ret.data.length;
	immutable uint basicLength = handledLength;
	if (handledLength > 0) ret ~= '-';
	if (handledLength == dstr.length) return ret.data;
	auto ms = (() @trusted => (cast(uint[])(dstr.filter!(not!isASCII).array)).sort!"a < b")();
	dchar n = initialN;
	uint delta = 0;
	uint bias = initialBias;
	while (handledLength < dstr.length)
	{
		dchar m = void;
		while ((m = ms.front) < n) ms.popFront();
		enforce!PunycodeException((m - n) * (handledLength + 1) <= uint.max - delta, "Arithmetic overflow");
		delta += (m - n) * (handledLength + 1);
		n = m;
		foreach (immutable(dchar) c; dstr)
		{
			if (c < n)
			{
				enforce!PunycodeException(delta != uint.max, "Arithmetic overflow");
				delta++;
			}
			else if (c == n)
			{
				uint q = delta;
				for (uint k = base;;k += base)
				{
					immutable t = k <= bias ? tmin :
						k >= bias + tmax ? tmax : k - bias;
					if (q < t) break;
					ret ~= encodeDigit(t + (q - t) % (base - t));
					q = (q - t) / (base - t);
				}
				ret ~= encodeDigit(q);
				bias = adaptBias(delta, cast(uint)handledLength + 1, handledLength == basicLength);
				delta = 0;
				handledLength++;
			}
		}
		delta++;
		n++;
	}
	return ret.data;
}

///
@safe pure
unittest
{
	assert(punyEncode("mañana") == "maana-pta");
}

/**
	Converts a Punycode string to an UTF-encoded string.
	Params: str = A Punycode-encoded string to be decoded into a UTF-encoded string
	Returns: A UTF-encoded string decoded from Punycode
	Throws:
		PunycodeException if an internal error occured
		InvalidPunycodeException if an invalid Punycode string was passed
*/
S punyDecode(S)(in S str) @safe pure
	if (isSomeString!S)
{
	import std.string : lastIndexOf;
	
	static uint decodeDigit(dchar c)
	{
		if (c.isUpper) return c - 'A';
		if (c.isLower) return c - 'a';
		if (c.isDigit) return c - '0' + 26;
		throw new InvalidPunycodeException("Invalid Punycode");
	}

	dchar[] ret;
	dchar n = initialN;
	uint i = 0;
	uint bias = initialBias;
	dstring dstr = str.to!dstring;
	assert(dstr.length <= uint.max);
	immutable ptrdiff_t delimIdx = dstr.lastIndexOf('-');
	if (delimIdx != -1)
	{
		enforce!InvalidPunycodeException(dstr[0 .. delimIdx].all!isASCII, "Invalid Punycode");
		ret = dstr[0 .. delimIdx].dup;
	}
	ptrdiff_t idx = (delimIdx == -1 || delimIdx == 0) ? 0 : delimIdx + 1;
	while (idx < dstr.length)
	{
		immutable uint oldi = i;
		uint w = 1;
		for (uint k = base;;k += base)
		{
			enforce!InvalidPunycodeException(idx < dstr.length);
			immutable digit = decodeDigit(dstr[idx]);
			idx++;
			enforce!PunycodeException(digit * w <= uint.max - i, "Arithmetic overflow");
			i += digit * w;
			immutable t = k <= bias ? tmin :
				k >= bias + tmax ? tmax : k - bias;
			if (digit < t) break;
			enforce!PunycodeException(w <= uint.max / (base - t), "Arithmetic overflow");
			w *= base - t;
		}
		enforce!PunycodeException(ret.length < uint.max-1, "Arithmetic overflow");
		bias = adaptBias(i - oldi, cast(uint) ret.length + 1, oldi == 0);
		enforce!PunycodeException(i / (ret.length + 1) <= uint.max - n, "Arithmetic overflow");
		n += i / (ret.length + 1);
		i %= ret.length + 1;
		(() @trusted => ret.insertInPlace(i, n))();
		i++;
	}
	return ret.to!S;
}

///
@safe pure
unittest
{
	assert(punyDecode("maana-pta") == "mañana");
}

@safe pure
unittest
{
	static void assertConvertible(S)(S plain, S punycode)
	{
		assert(punyEncode(plain) == punycode);
		assert(punyDecode(punycode) == plain);
	}
	assertConvertible("", "");
	assertConvertible("ASCII0123", "ASCII0123-");
	assertConvertible("Punycodeぴゅにこーど", "Punycode-p73grhua1i6jv5d");
	assertConvertible("Punycodeぴゅにこーど"w, "Punycode-p73grhua1i6jv5d"w);
	assertConvertible("Punycodeぴゅにこーど"d, "Punycode-p73grhua1i6jv5d"d);
	assertConvertible("ぴゅにこーど", "28j1be9azfq9a");
	assertConvertible("他们为什么不说中文", "ihqwcrb4cv8a8dqg056pqjye");
	assertConvertible("☃-⌘", "--dqo34k");
	assertConvertible("-> $1.00 <-", "-> $1.00 <--");
	assertThrown!InvalidPunycodeException(punyDecode("aaa-*"));
	assertThrown!InvalidPunycodeException(punyDecode("aaa-p73grhua1i6jv5dd"));
	assertThrown!InvalidPunycodeException(punyDecode("ü-"));
	assert(collectExceptionMsg(punyDecode("aaa-99999999")) == "Arithmetic overflow");
}

///	Exception thrown if there was an internal error when encoding or decoding punycode.
class PunycodeException : Exception
{
	import std.exception : basicExceptionCtors;
    mixin basicExceptionCtors;
}

/// Exception thrown if supplied punycode is invalid, and therefore cannot be decoded.
class InvalidPunycodeException : PunycodeException
{
	import std.exception : basicExceptionCtors;
    mixin basicExceptionCtors;
}

private uint adaptBias(uint delta, in uint numpoints, in bool firsttime) @safe pure nothrow /+@nogc+/
{
	uint k;
	delta = firsttime ? delta / damp : delta / 2;
	delta += delta / numpoints;
	while (delta > ((base - tmin) * tmax) / 2)
	{
		delta /= base - tmin;
		k += base;
	}
	return k + (base - tmin + 1) * delta / (delta + skew);
}
