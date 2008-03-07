// Written in the D programming language.

/**
Classes and functions for handling and transcoding between various encodings.
Encodings currently supported are UTF-8, UTF-16, UTF-32, ASCII, ISO-8859-1
(also known as LATIN-1), and WINDOWS-1252

Functions are provided for arbitrary encoding and decoding of single
characters, arbitrary transcoding between strings of different type, as well as
validation and sanitization.

The type EString!(Ascii) represents an ASCII string; the type EString!(Latin1)
represents an ISO-8859-1 string, and so on. In general, EString!(E) is the
string type for encoding E, and EString(Utf8), EString(Utf16) and
EString(Utf32) are aliases for string, wstring and dstring respectively.

Future directions for this module include the ability to handle arbitrary
encodings.

Authors: Janice Caron

Date: 2006.02.27

License: Public Domain

$(BIG $(B A Brief Tutorial))

There are many character sets (or more properly, character repertoires) on the
planet. Unicode is the superset of all other legacy character sets. Therefore,
$(I every) character which exists in any character repertoire, also exists in
Unicode. Every character in Unicode has an integer associated with it. That
integer is the called the character's code point. For example, the code point
of the letter 'A' is 65, or in hex, 0x41. It is important to know that a
character's code point is unchangeable. It is a permanent property of the
character, and it does not depend on how you encode it. The code point of 'A'
is 65, period.

Most character repertoires consist of 256 characters or fewer. This is because
it is convenient to use single-byte encoding schemes. In such repertoires,
every character will have an integer in the range 0 to 255 associated with it,
denoting its position within that repertoire. That number is called a code
unit. Note that, in general, code unit != code point.

For example, the Euro currency symbol has code point 0x20AC. This is a
permanent property of the character. That character does not exist in the
ASCII repertoire, and so cannot be encoded in ASCII. It also does not exist in
the Latin-1 character repertoire, and likewise cannot be encoded in Latin-1.It
$(I does) exist in the Windows-1252 character repertoire though. In that
encoding, it is represented by the byte 0x80. So in that encoding, its code
UNIT is 0x80, but its code POINT is still 0x20AC. Code points are always
measured in Unicode.

Some character repertoires contain more than 256 characters. Yet it is still
desirable to be able to store those characters as a byte sequence, so
multi-byte encodings got invented to allow that. In such encodings a single
character may require more than one byte to represent it.

The process of converting a single code point into one or more code units is
called ENCODING. The reverse process, that of converting multiple code units
into a single code point is called DECODING.

Almost all encodings use 8-bit bytes as the storage type for a single code
unit - but there are exceptions. UTF-16, for example, uses 16-bit wide code
units. (The character repertoire which it represents contains more than 2^16
characters, so some of those characters need to expressed as multiple code
units, even in UTF-16). UTF-32 uses a 32-bit wide code unit, which means, just
like in the good old days of ASCII, one code unit == one code point. UTF-32,
however, is the $(I only) encoding for which this is true.

*/

module std.encoding;

unittest
{
	ubyte[][] validStrings =
	[
		// Plain ASCII
		cast(ubyte[])"hello",

		// The Greek word 'kosme'
		cast(ubyte[])"Îºá½¹ÏƒÎ¼Îµ",

		// First possible sequence of a certain length
		[ 0x00 ],						// U+00000000	one byte
		[ 0xC2, 0x80 ],					// U+00000080	two bytes
		[ 0xE0, 0xA0, 0x80 ],			// U+00000800	three bytes
		[ 0xF0, 0x90, 0x80, 0x80 ],		// U+00010000	three bytes

		// Last possible sequence of a certain length
		[ 0x7F ],						// U+0000007F	one byte
		[ 0xDF, 0xBF ],					// U+000007FF	two bytes
		[ 0xEF,	0xBF, 0xBF ],			// U+0000FFFF	three bytes

		// Other boundary conditions
		[ 0xED, 0x9F, 0xBF ],			// U+0000D7FF	Last character before surrogates
		[ 0xEE, 0x80, 0x80 ],			// U+0000E000	First character after surrogates
		[ 0xEF, 0xBF, 0xBD ],			// U+0000FFFD	Unicode replacement character
		[ 0xF4, 0x8F, 0xBF, 0xBF ],		// U+0010FFFF	Very last character

		// Non-character code points
		/*	NOTE: These are legal in UTF, and may be converted from one UTF to
			another, however they do not represent Unicode characters. These
			code points have been reserved by Unicode as non-character code
			points. They are permissible for data exchange within an
			application, but they are are not permitted to be used as
			characters. Since this module deals with UTF, and not with Unicode
			per se, we choose to accept them here. */
		[ 0xDF, 0xBE ],					// U+0000FFFE
		[ 0xDF, 0xBF ],					// U+0000FFFF
	];

	ubyte[][] invalidStrings =
	[
		// First possible sequence of a certain length, but greater than U+10FFFF
		[ 0xF8, 0x88, 0x80, 0x80, 0x80 ],			// U+00200000	five bytes
		[ 0xFC, 0x84, 0x80, 0x80, 0x80, 0x80 ],		// U+04000000	six bytes

		// Last possible sequence of a certain length, but greater than U+10FFFF
		[ 0xF7, 0xBF, 0xBF, 0xBF ],					// U+001FFFFF	four bytes
		[ 0xFB, 0xBF, 0xBF, 0xBF, 0xBF ],			// U+03FFFFFF	five bytes
		[ 0xFD, 0xBF, 0xBF, 0xBF, 0xBF, 0xBF ],		// U+7FFFFFFF	six bytes

		// Other boundary conditions
		[ 0xF4, 0x90, 0x80, 0x80 ],					// U+00110000	First code
													// point after last character

		// Unexpected continuation bytes
		[ 0x80 ],
		[ 0xBF ],
		[ 0x20, 0x80, 0x20 ],
		[ 0x20, 0xBF, 0x20 ],
		[ 0x80, 0x9F, 0xA0 ],

		// Lonely start bytes
		[ 0xC0 ],
		[ 0xCF ],
		[ 0x20, 0xC0, 0x20 ],
		[ 0x20, 0xCF, 0x20 ],
		[ 0xD0 ],
		[ 0xDF ],
		[ 0x20, 0xD0, 0x20 ],
		[ 0x20, 0xDF, 0x20 ],
		[ 0xE0 ],
		[ 0xEF ],
		[ 0x20, 0xE0, 0x20 ],
		[ 0x20, 0xEF, 0x20 ],
		[ 0xF0 ],
		[ 0xF1 ],
		[ 0xF2 ],
		[ 0xF3 ],
		[ 0xF4 ],
		[ 0xF5 ],	// If this were legal it would start a character > U+10FFFF
		[ 0xF6 ],	// If this were legal it would start a character > U+10FFFF
		[ 0xF7 ],	// If this were legal it would start a character > U+10FFFF

		[ 0xEF, 0xBF ],				// Three byte sequence with third byte missing
		[ 0xF7, 0xBF, 0xBF ],		// Four byte sequence with fourth byte missing
		[ 0xEF, 0xBF, 0xF7, 0xBF, 0xBF ],	// Concatenation of the above

		// Impossible bytes
		[ 0xF8 ],
		[ 0xF9 ],
		[ 0xFA ],
		[ 0xFB ],
		[ 0xFC ],
		[ 0xFD ],
		[ 0xFE ],
		[ 0xFF ],
		[ 0x20, 0xF8, 0x20 ],
		[ 0x20, 0xF9, 0x20 ],
		[ 0x20, 0xFA, 0x20 ],
		[ 0x20, 0xFB, 0x20 ],
		[ 0x20, 0xFC, 0x20 ],
		[ 0x20, 0xFD, 0x20 ],
		[ 0x20, 0xFE, 0x20 ],
		[ 0x20, 0xFF, 0x20 ],

		// Overlong sequences, all representing U+002F
		/*	With a safe UTF-8 decoder, all of the following five overlong
			representations of the ASCII character slash ("/") should be
			rejected like a malformed UTF-8 sequence */
		[ 0xC0, 0xAF ],
		[ 0xE0, 0x80, 0xAF ],
		[ 0xF0, 0x80, 0x80, 0xAF ],
		[ 0xF8, 0x80, 0x80, 0x80, 0xAF ],
		[ 0xFC, 0x80, 0x80, 0x80, 0x80, 0xAF ],

		// Maximum overlong sequences
		/*	Below you see the highest Unicode value that is still resulting in
			an overlong sequence if represented with the given number of bytes.
			This is a boundary test for safe UTF-8 decoders. All five
			characters should be rejected like malformed UTF-8 sequences. */
		[ 0xC1, 0xBF ],								// U+0000007F
		[ 0xE0, 0x9F, 0xBF ],						// U+000007FF
		[ 0xF0, 0x8F, 0xBF, 0xBF ],					// U+0000FFFF
		[ 0xF8, 0x87, 0xBF, 0xBF, 0xBF ],			// U+001FFFFF
		[ 0xFC, 0x83, 0xBF, 0xBF, 0xBF, 0xBF ],		// U+03FFFFFF

		// Overlong representation of the NUL character
		/*	The following five sequences should also be rejected like malformed
			UTF-8 sequences and should not be treated like the ASCII NUL
			character. */
		[ 0xC0, 0x80 ],
		[ 0xE0, 0x80, 0x80 ],
		[ 0xF0, 0x80, 0x80, 0x80 ],
		[ 0xF8, 0x80, 0x80, 0x80, 0x80 ],
		[ 0xFC, 0x80, 0x80, 0x80, 0x80, 0x80 ],

		// Illegal code positions
		/*	The following UTF-8 sequences should be rejected like malformed
			sequences, because they never represent valid ISO 10646 characters
			and a UTF-8 decoder that accepts them might introduce security
			problems comparable to overlong UTF-8 sequences. */
		[ 0xED, 0xA0, 0x80 ],		// U+D800
		[ 0xED, 0xAD, 0xBF ],		// U+DB7F
		[ 0xED, 0xAE, 0x80 ],		// U+DB80
		[ 0xED, 0xAF, 0xBF ],		// U+DBFF
		[ 0xED, 0xB0, 0x80 ],		// U+DC00
		[ 0xED, 0xBE, 0x80 ],		// U+DF80
		[ 0xED, 0xBF, 0xBF ],		// U+DFFF
	];

	string[] sanitizedStrings =
	[
		"\uFFFD","\uFFFD",
		"\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD"," \uFFFD ",
		" \uFFFD ","\uFFFD\uFFFD\uFFFD","\uFFFD","\uFFFD"," \uFFFD "," \uFFFD ",
		"\uFFFD","\uFFFD"," \uFFFD "," \uFFFD ","\uFFFD","\uFFFD"," \uFFFD ",
		" \uFFFD ","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD",
		"\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD\uFFFD","\uFFFD","\uFFFD",
		"\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD"," \uFFFD ",
		" \uFFFD "," \uFFFD "," \uFFFD "," \uFFFD "," \uFFFD "," \uFFFD ",
		" \uFFFD ","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD",
		"\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD",
		"\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD","\uFFFD",
	];

	// Make sure everything that should be valid, is
	foreach(a;validStrings)
	{
		string s = cast(string)a;
		assert(isValid(s),"Failed to validate: "~makeReadable(s));
	}

	// Make sure everything that shouldn't be valid, isn't
	foreach(a;invalidStrings)
	{
		string s = cast(string)a;
		assert(!isValid(s),"Incorrectly validated: "~makeReadable(s));
	}

	// Make sure we can sanitize everything bad
	assert(invalidStrings.length == sanitizedStrings.length);
	for(int i=0; i<invalidStrings.length; ++i)
	{
		string s = cast(string)invalidStrings[i];
		string t = sanitize(s);
		assert(isValid(t));
		assert(t == sanitizedStrings[i]);
		ubyte[] u = cast(ubyte[])t;
		validStrings ~= u;
	}

	// Make sure all transcodings work in both directions, using both forward
	// and reverse iteration
	foreach(a;validStrings)
	{
		string s = cast(string)a;
		string s2;
		wstring ws, ws2;
		dstring ds, ds2;

		transcode(s,ws);
		assert(isValid(ws));
		transcode(ws,s2);
		assert(s == s2);

		transcode(s,ds);
		assert(isValid(ds));
		transcode(ds,s2);
		assert(s == s2);

		transcode(ws,s);
		assert(isValid(s));
		transcode(s,ws2);
		assert(ws == ws2);

		transcode(ws,ds);
		assert(isValid(ds));
		transcode(ds,ws2);
		assert(ws == ws2);

		transcode(ds,s);
		assert(isValid(s));
		transcode(s,ds2);
		assert(ds == ds2);

		transcode(ds,ws);
		assert(isValid(ws));
		transcode(ws,ds2);
		assert(ds == ds2);

		transcodeReverse(s,ws);
		assert(isValid(ws));
		transcodeReverse(ws,s2);
		assert(s == s2);

		transcodeReverse(s,ds);
		assert(isValid(ds));
		transcodeReverse(ds,s2);
		assert(s == s2);

		transcodeReverse(ws,s);
		assert(isValid(s));
		transcodeReverse(s,ws2);
		assert(ws == ws2);

		transcodeReverse(ws,ds);
		assert(isValid(ds));
		transcodeReverse(ds,ws2);
		assert(ws == ws2);

		transcodeReverse(ds,s);
		assert(isValid(s));
		transcodeReverse(s,ds2);
		assert(ds == ds2);

		transcodeReverse(ds,ws);
		assert(isValid(ws));
		transcodeReverse(ws,ds2);
		assert(ds == ds2);
	}

	// Make sure the non-UTF encodings work too
	{
		auto s = "\u20AC100";
		auto t = to!(Windows1252)(s);
		assert(t == [cast(Windows1252)0x80, '1', '0', '0']);
		auto u = to!(Utf8)(s);
		assert(s == u);
		auto v = to!(Latin1)(s);
		assert(cast(string)v == "?100");
		auto w = to!(Ascii)(v);
		assert(cast(string)w == "?100");
	}
}

//=============================================================================

template Mutable(E)
{
	static if(!is(E X == const(U),U) && !is(E X == invariant(U),U))
	{
		alias E Mutable;
	}
	else
	{
		alias U Mutable;
	}
}

/** A simple growable buffer for fast appending */
struct Buffer(E)
{
	alias Mutable!(E) T;

	private
	{
		T[] buffer;
		uint index;

		void reserve(uint spaceNeeded)
		{
			uint bufferLength = buffer.length;
			if (bufferLength < index + spaceNeeded)
			{
				if (bufferLength == 0) bufferLength = 16;
				while (bufferLength < index + spaceNeeded) bufferLength <<= 2;
				buffer.length = bufferLength;
			}
		}
	}

	void opCatAssign(E c) /// Append a single character
	{
		reserve(1);
		buffer[index++] = c;
	}

	void opCatAssign(const(E)[] a) /// Append an array of characters
	{
		reserve(a.length);
		buffer[index..index+a.length] = a[0..$];
		index += a.length;
	}

	T[] toArray() /// Return the buffer, and reset it
	{
		auto t = buffer[0..index];
		buffer = null;
		return t;
	}

	invariant(T)[] toIArray() /// Return the buffer as an invariant array, and reset it
	{
		auto t = cast(invariant(T)[])(buffer[0..index]);
		buffer = null;
		return t;
	}
}

//=============================================================================

/** Special value returned by safeDecode */
enum dchar INVALID_SEQUENCE = cast(dchar)0xFFFFFFFF;

template EncoderFunctions()
{
	// Various forms of read

	template ReadFromString()
	{
		bool canRead() { return s.length != 0; }
		E peek() { return s[0]; }
		E read() { E t = s[0]; s = s[1..$]; return t; }
	}

	template ReverseReadFromString()
	{
		bool canRead() { return s.length != 0; }
		E peek() { return s[$-1]; }
		E read() { E t = s[$-1]; s = s[0..$-1]; return t; }
	}

	// Various forms of Write

	template WriteToString()
	{
		EString s;
		void write(E c) { s ~= c; }
	}

	template WriteToBuffer()
	{
		void write(E c) { buffer ~= c; }
	}

	template WriteToDelegate()
	{
		void write(E c) { dg(c); }
	}

	// Functions we will export

	template EncodeViaWrite()
	{
		mixin encodeViaWrite;
		void encode(dchar c) { encodeViaWrite(c); }
	}

	template SkipViaRead()
	{
		mixin skipViaRead;
		void skip() { skipViaRead(); }
	}

	template DecodeViaRead()
	{
		mixin decodeViaRead;
		dchar decode() { return decodeViaRead(); }
	}

	template SafeDecodeViaRead()
	{
		mixin safeDecodeViaRead;
		dchar safeDecode() { return safeDecodeViaRead(); }
	}

	template DecodeReverseViaRead()
	{
		mixin decodeReverseViaRead;
		dchar decodeReverse() { return decodeReverseViaRead(); }
	}

	// Encoding to different destinations

	template EncodeToString()
	{
		mixin WriteToString;
		mixin EncodeViaWrite;
	}

	template EncodeToBuffer()
	{
		mixin WriteToBuffer;
		mixin EncodeViaWrite;
	}

	template EncodeToDelegate()
	{
		mixin WriteToDelegate;
		mixin EncodeViaWrite;
	}

	// Decoding functions

	template SkipFromString()
	{
		mixin ReadFromString;
		mixin SkipViaRead;
	}

	template DecodeFromString()
	{
		mixin ReadFromString;
		mixin DecodeViaRead;
	}

	template SafeDecodeFromString()
	{
		mixin ReadFromString;
		mixin SafeDecodeViaRead;
	}

	template DecodeReverseFromString()
	{
		mixin ReverseReadFromString;
		mixin DecodeReverseViaRead;
	}

	//=========================================================================

	// Below are the functions we will ultimately expose to the user
	EString encode(dchar c)
	{
		mixin EncodeToString e;
		e.encode(c);
		return e.s;
	}

	void encode(dchar c, ref EBuffer buffer)
	{
		mixin EncodeToBuffer e;
		e.encode(c);
	}

	void encode(dchar c, void delegate(E) dg)
	{
		mixin EncodeToDelegate e;
		e.encode(c);
	}

	void skip(ref EString s)
	{
		mixin SkipFromString e;
		e.skip();
	}

	dchar decode(ref EString s)
	{
		mixin DecodeFromString e;
		return e.decode();
	}

	dchar safeDecode(ref EString s)
	{
		mixin SafeDecodeFromString e;
		return e.safeDecode();
	}

	dchar decodeReverse(ref EString s)
	{
		mixin DecodeReverseFromString e;
		return e.decodeReverse();
	}
}

//=========================================================================

struct CodePoints(E)
{
	invariant(E)[] s;

	static CodePoints opCall(invariant(E)[] s)
	in
	{
		assert(isValid(s));
	}
	body
	{
		CodePoints codePoints;
		codePoints.s = s;
		return codePoints;
	}

	int opApply(int delegate(ref dchar) dg)
	{
		int result = 0;
		while (s.length != 0)
		{
			dchar c = decode(s);
			result = dg(c);
			if (result != 0) break;
		}
		return result;
	}

	int opApply(int delegate(ref uint, ref dchar) dg)
	{
		uint i = 0;
		int result = 0;
		while (s.length != 0)
		{
			uint len = s.length;
			dchar c = decode(s);
			uint j = i; // We don't want the delegate corrupting i
			result = dg(j,c);
			if (result != 0) break;
			i += len - s.length;
		}
		return result;
	}

	int opApplyReverse(int delegate(ref dchar) dg)
	{
		int result = 0;
		while (s.length != 0)
		{
			dchar c = decodeReverse(s);
			result = dg(c);
			if (result != 0) break;
		}
		return result;
	}

	int opApplyReverse(int delegate(ref uint, ref dchar) dg)
	{
		int result = 0;
		while (s.length != 0)
		{
			dchar c = decodeReverse(s);
			uint i = s.length;
			result = dg(i,c);
			if (result != 0) break;
		}
		return result;
	}
}

struct CodeUnits(E)
{
	invariant(E)[] s;

	static CodeUnits opCall(dchar d)
	in
	{
		assert(isValidCodePoint(d));
	}
	body
	{
		CodeUnits codeUnits;
		codeUnits.s = encode!(E)(d);
		return codeUnits;
	}

	int opApply(int delegate(ref E) dg)
	{
		int result = 0;
		foreach(E c;s)
		{
			result = dg(c);
			if (result != 0) break;
		}
		return result;
	}

	int opApplyReverse(int delegate(ref E) dg)
	{
		int result = 0;
		foreach_reverse(E c;s)
		{
			result = dg(c);
			if (result != 0) break;
		}
		return result;
	}
}

//=============================================================================

template EncoderInstance(E)
{
	static assert(false);
}

//=============================================================================
// 			ASCII
//=============================================================================

typedef char Ascii;

template EncoderInstance(E:Ascii)
{
	alias invariant(Ascii)[] EString;
	alias Buffer!(Ascii) EBuffer;

	string encodingName()
	{
		return "ASCII";
	}

	bool canEncode(dchar c)
	{
		return c < 0x80;
	}

	bool isValidCodeUnit(Ascii c)
	{
		return c < 0x80;
	}

	void encodeViaWrite()(dchar c)
	{
		if (!canEncode(c)) c = '?';
		write(cast(Ascii)c);
	}

	void skipViaRead()()
	{
		read();
	}

	dchar decodeViaRead()()
	{
		return read;
	}

	dchar safeDecodeViaRead()()
	{
		dchar c = read;
		return canEncode(c) ? c : INVALID_SEQUENCE;
	}

	dchar decodeReverseViaRead()()
	{
		return read;
	}

	EString replacementSequence()
	{
		return cast(EString)("?");
	}

	mixin EncoderFunctions;
}

//=============================================================================
// 			ISO-8859-1
//=============================================================================

typedef ubyte Latin1;

template EncoderInstance(E:Latin1)
{
	alias invariant(Latin1)[] EString;
	alias Buffer!(Latin1) EBuffer;

	string encodingName()
	{
		return "ISO-8859-1";
	}

	bool canEncode(dchar c)
	{
		return c < 0x100;
	}

	bool isValidCodeUnit(Latin1 c)
	{
		return true;
	}

	void encodeViaWrite()(dchar c)
	{
		if (!canEncode(c)) c = '?';
		write(cast(Latin1)c);
	}

	void skipViaRead()()
	{
		read();
	}

	dchar decodeViaRead()()
	{
		return read;
	}

	dchar safeDecodeViaRead()()
	{
		return read;
	}

	dchar decodeReverseViaRead()()
	{
		return read;
	}

	EString replacementSequence()
	{
		return cast(EString)("?");
	}

	mixin EncoderFunctions;
}

//=============================================================================
// 			WINDOWS-1252
//=============================================================================

typedef ubyte Windows1252;

template EncoderInstance(E:Windows1252)
{
	alias invariant(Windows1252)[] EString;
	alias Buffer!(Windows1252) EBuffer;

	string encodingName()
	{
		return "windows-1252";
	}

	wstring charMap =
		"\u20AC\uFFFD\u201A\u0192\u201E\u2026\u2020\u2021"
		"\u02C6\u2030\u0160\u2039\u0152\uFFFD\u017D\uFFFD"
		"\uFFFD\u2018\u2019\u201C\u201D\u2022\u2103\u2014"
		"\u02DC\u2122\u0161\u203A\u0153\uFFFD\u017E\u0178"
	;

	bool canEncode(dchar c)
	{
		if (c < 0x80 || (c >= 0xA0 && c <0x100)) return true;
		if (c >= 0xFFFD) return false;
		foreach(wchar d;charMap) { if (c == d) return true; }
		return false;
	}

	bool isValidCodeUnit(Windows1252 c)
	{
		if (c < 0x80 || c >= 0xA0) return true;
		return (charMap[c-0x80] != 0xFFFD);
	}

	void encodeViaWrite()(dchar c)
	{
		if (c < 0x80 || (c >= 0xA0 && c <0x100)) {}
		else if (c >= 0xFFFD) { c = '?'; }
		else
		{
			int n = -1;
			foreach(i,wchar d;charMap)
			{
				if (c == d)
				{
					n = i;
					break;
				}
			}
			c = n == -1 ? '?' : 0x80 + n;
		}
		write(cast(Windows1252)c);
	}

	void skipViaRead()()
	{
		read();
	}

	dchar decodeViaRead()()
	{
		Windows1252 c = read;
		return (c >= 0x80 && c < 0xA0) ? charMap[c-0x80] : c;
	}

	dchar safeDecodeViaRead()()
	{
		Windows1252 c = read;
		dchar d = (c >= 0x80 && c < 0xA0) ? charMap[c-0x80] : c;
		return d == 0xFFFD ? INVALID_SEQUENCE : d;
	}

	dchar decodeReverseViaRead()()
	{
		Windows1252 c = read;
		return (c >= 0x80 && c < 0xA0) ? charMap[c-0x80] : c;
	}

	EString replacementSequence()
	{
		return cast(EString)("?");
	}

	mixin EncoderFunctions;
}

//=============================================================================
// 			UTF-8
//=============================================================================

alias char Utf8;

template EncoderInstance(E:Utf8)
{
	alias invariant(Utf8)[] EString;
	alias Buffer!(Utf8) EBuffer;

	string encodingName()
	{
		return "UTF-8";
	}

	bool canEncode(dchar c)
	{
		return isValidCodePoint(c);
	}

	bool isValidCodeUnit(Utf8 c)
	{
		return (c < 0xC0 || (c >= 0xC2 && c < 0xF5));
	}

	byte[128] tailTable =
	[
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
		2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
		3,3,3,3,3,3,3,3,4,4,4,4,5,5,6,0,
	];

	private int tails(Utf8 c)
	in
	{
		assert(c >= 0x80);
	}
	body
	{
		return tailTable[c-0x80];
	}

	void encodeViaWrite()(dchar c)
	{
		if (c < 0x80)
		{
			write(cast(Utf8)c);
		}
		else if (c < 0x800)
		{
			write(cast(Utf8)((c >> 6) + 0xC0));
			write(cast(Utf8)((c & 0x3F) + 0x80));
		}
		else if (c < 0x10000)
		{
			write(cast(Utf8)((c >> 12) + 0xE0));
			write(cast(Utf8)(((c >> 6) & 0x3F) + 0x80));
			write(cast(Utf8)((c & 0x3F) + 0x80));
		}
		else
		{
			write(cast(Utf8)((c >> 18) + 0xF0));
			write(cast(Utf8)(((c >> 12) & 0x3F) + 0x80));
			write(cast(Utf8)(((c >> 6) & 0x3F) + 0x80));
			write(cast(Utf8)((c & 0x3F) + 0x80));
		}
	}

	void skipViaRead()()
	{
		uint c = read;
		if (c < 0xC0) return;
		int n = tails(c);
		for (uint i=0; i<n; ++i)
		{
			read();
		}
	}

	dchar decodeViaRead()()
	{
		uint c = read;
		if (c < 0xC0) return c;
		int n = tails(c);
		c &= (1 << (6 - n)) - 1;
		for (uint i=0; i<n; ++i)
		{
			c = (c << 6) + (read & 0x3F);
		}
		return c;
	}

	dchar safeDecodeViaRead()()
	{
		dchar c = read;
		if (c < 0x80) return c;
		int n = tails(c);
		if (n == 0) return INVALID_SEQUENCE;

		if (!canRead) return INVALID_SEQUENCE;
		uint d = peek;
		bool err =
		(
			(c < 0xC2)								// fail overlong 2-byte sequences
		||	(c > 0xF4)								// fail overlong 4-6-byte sequences
		||	(c == 0xE0 && ((d & 0xE0) == 0x80))		// fail overlong 3-byte sequences
		||	(c == 0xED && ((d & 0xE0) == 0xA0))		// fail surrogates
		||	(c == 0xF0 && ((d & 0xF0) == 0x80))		// fail overlong 4-byte sequences
		||	(c == 0xF4 && ((d & 0xF0) >= 0x90))		// fail code points > 0x10FFFF
		);

		c &= (1 << (6 - n)) - 1;
		for (uint i=0; i<n; ++i)
		{
			if (!canRead) return INVALID_SEQUENCE;
			d = peek;
			if ((d & 0xC0) != 0x80) return INVALID_SEQUENCE;
			c = (c << 6) + (read & 0x3F);
		}

		return err ? INVALID_SEQUENCE : c;
	}

	dchar decodeReverseViaRead()()
	{
		uint c = read;
		if (c < 0x80) return c;
		uint shift = 0;
		c &= 0x3F;
		for (uint i=0; i<4; ++i)
		{
			shift += 6;
			uint d = read;
			uint n = tails(d);
			uint mask = n == 0 ? 0x3F : (1 << (6 - n)) - 1;
			c = c + ((d & mask) << shift);
			if (n != 0) break;
		}
		return c;
	}

	EString replacementSequence()
	{
		return "\uFFFD";
	}

	mixin EncoderFunctions;
}

//=============================================================================
// 			UTF-16
//=============================================================================

alias wchar Utf16;

template EncoderInstance(E:Utf16)
{
	alias invariant(Utf16)[] EString;
	alias Buffer!(Utf16) EBuffer;

	string encodingName()
	{
		return "UTF-16";
	}

	bool canEncode(dchar c)
	{
		return isValidCodePoint(c);
	}

	bool isValidCodeUnit(Utf16 c)
	{
		return true;
	}

	void encodeViaWrite()(dchar c)
	{
		if (c < 0x10000)
		{
			write(cast(Utf16)c);
		}
		else
		{
			uint n = c - 0x10000;
			write(cast(Utf16)(0xD800 + (n >> 10)));
			write(cast(Utf16)(0xDC00 + (n & 0x3FF)));
		}
	}

	void skipViaRead()()
	{
		Utf16 c = read;
		if (c < 0xD800 || c >= 0xE000) return;
		read();
	}

	dchar decodeViaRead()()
	{
		Utf16 c = read;
		if (c < 0xD800 || c >= 0xE000) return cast(dchar)c;
		Utf16 d = read;
		c &= 0x3FF;
		d &= 0x3FF;
		return 0x10000 + (c << 10) + d;
	}

	dchar safeDecodeViaRead()()
	{
		Utf16 c = read;
		if (c < 0xD800 || c >= 0xE000) return cast(dchar)c;
		if (c >= 0xDC00) return INVALID_SEQUENCE;
		if (!canRead) return INVALID_SEQUENCE;
		Utf16 d = peek;
		if (d < 0xDC00 || d >= 0xE000) return INVALID_SEQUENCE;
		d = read;
		c &= 0x3FF;
		d &= 0x3FF;
		return 0x10000 + (c << 10) + d;
	}

	dchar decodeReverseViaRead()()
	{
		Utf16 c = read;
		if (c < 0xD800 || c >= 0xE000) return cast(dchar)c;
		Utf16 d = read;
		c &= 0x3FF;
		d &= 0x3FF;
		return 0x10000 + (d << 10) + c;
	}

	EString replacementSequence()
	{
		return "\uFFFD"w;
	}

	mixin EncoderFunctions;
}

//=============================================================================
// 			UTF-32
//=============================================================================

alias dchar Utf32;

template EncoderInstance(E:Utf32)
{
	alias invariant(Utf32)[] EString;
	alias Buffer!(Utf32) EBuffer;

	string encodingName()
	{
		return "UTF-32";
	}

	bool canEncode(dchar c)
	{
		return isValidCodePoint(c);
	}

	bool isValidCodeUnit(Utf16 c)
	{
		return isValidCodePoint(c);
	}

	void encodeViaWrite()(dchar c)
	{
		write(cast(Utf32)c);
	}

	void skipViaRead()()
	{
		read();
	}

	dchar decodeViaRead()()
	{
		return cast(dchar)read;
	}

	dchar safeDecodeViaRead()()
	{
		dchar c = read;
		return isValidCodePoint(c) ? c : INVALID_SEQUENCE;
	}

	dchar decodeReverseViaRead()()
	{
		return cast(dchar)read;
	}

	EString replacementSequence()
	{
		return "\uFFFD"d;
	}

	mixin EncoderFunctions;
}

//=============================================================================
// Below are forwarding functions which expose the function to the user

/**
 * Returns true if c is a valid code point
 *
 * Note that this includes the non-character code points U+FFFE and U+FFFF,
 * since these are valid code points (even though they are not valid
 * characters).
 *
 * Supercedes:
 * This function supercedes std.utf.startsValidDchar().
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    c = the code point to be tested
 */
bool isValidCodePoint(dchar c)
{
	return c < 0xD800 || (c >= 0xE000 && c < 0x110000);
}

/**
 * Returns the name of an encoding.
 *
 * The type of encoding cannot be deduced. Therefore, it is necessary to
 * explicitly specify the encoding type.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Examples:
 * -----------------------------------
 * writefln(encodingName!(Latin1));
 *     // writes ISO-8859-1
 * -----------------------------------
 */
string encodingName(T)()
{
	return EncoderInstance!(T).encodingName;
}

unittest
{
	assert(encodingName!(Utf8) == "UTF-8");
	assert(encodingName!(Utf16) == "UTF-16");
	assert(encodingName!(Utf32) == "UTF-32");
	assert(encodingName!(Ascii) == "ASCII");
	assert(encodingName!(Latin1) == "ISO-8859-1");
	assert(encodingName!(Windows1252) == "windows-1252");
}

/**
 * Returns true iff it is possible to represent the specifed codepoint
 * in the encoding.
 *
 * The type of encoding cannot be deduced. Therefore, it is necessary to
 * explicitly specify the encoding type.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Examples:
 * -----------------------------------
 * writefln(canEncode!(Latin1)('A'));
 *     // writes true
 * -----------------------------------
 */
bool canEncode(E)(dchar c)
{
	return EncoderInstance!(E).canEncode(c);
}

unittest
{
	assert(!canEncode!(Ascii)('\u00A0'));
	assert(canEncode!(Latin1)('\u00A0'));
	assert(canEncode!(Windows1252)('\u20AC'));
	assert(!canEncode!(Windows1252)('\u20AD'));
	assert(!canEncode!(Windows1252)('\uFFFD'));
	assert(!canEncode!(Utf8)(cast(dchar)0x110000));
}

/**
 * Returns true if the code unit is legal. For example, the byte 0x80 would
 * not be legal in ASCII, because ASCII code units must always be in the range
 * 0x00 to 0x7F.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    c = the code unit to be tested
 */
bool isValidCodeUnit(E)(E c)
{
	return EncoderInstance!(E).isValidCodeUnit(c);
}

unittest
{
	assert(!isValidCodeUnit(cast(Ascii)0xA0));
	assert( isValidCodeUnit(cast(Windows1252)0x80));
	assert(!isValidCodeUnit(cast(Windows1252)0x81));
	assert(!isValidCodeUnit(cast(Utf8)0xC0));
	assert(!isValidCodeUnit(cast(Utf8)0xFF));
	assert( isValidCodeUnit(cast(Utf16)0xD800));
	assert(!isValidCodeUnit(cast(Utf32)0xD800));
}

/**
 * Returns true if the string is encoded correctly
 *
 * Supercedes:
 * This function supercedes std.utf.validate(), however note that this
 * function returns a bool indicating whether the input was valid or not,
 * wheras the older funtion would throw an exception.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string to be tested
 */
bool isValid(E)(invariant(E)[] s)
{
	while (s.length != 0)
	{
		dchar d = EncoderInstance!(E).safeDecode(s);
		if (d == INVALID_SEQUENCE)
			return false;
	}
	return true;
}

unittest
{
	assert(isValid("\u20AC100"));
}

/**
 * Returns the length of the longest possible substring, starting from
 * the first code unit, which is validly encoded.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string to be tested
 */
uint validLength(E)(invariant(E)[] s)
{
	invariant(E)[] r = s;
	invariant(E)[] t = s;
	while (s.length != 0)
	{
		if (!EncoderInstance!(E).safeDecode(s) != INVALID_SEQUENCE)
			break;
		t = s;
	}
	return r.length - t.length;
}

/**
 * Sanitizes a string by replacing malformed code unit sequences with valid
 * code unit sequences. The result is guaranteed to be valid for this encoding.
 *
 * If the input string is already valid, this function returns the original,
 * otherwise it constructs a new string by replacing all illegal code unit
 * sequences with the encoding's replacement character, Invalid sequences will
 * be replaced with the Unicode replacement character (U+FFFD) if the
 * character repertoire contains it, otherwise invalid sequences will be
 * replaced with '?'.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string to be sanitized
 */
invariant(E)[] sanitize(E)(invariant(E)[] s)
{
	uint n = validLength(s);
	if (n == s.length) return s;

	Buffer!(E) r;
	r ~= s[0..n];
	s = s[n..$];
	while (s.length != 0)
	{
		invariant(E)[] t = s;
		dchar c = EncoderInstance!(E).safeDecode(s);
		if (c == INVALID_SEQUENCE)
		{
			r ~= EncoderInstance!(E).replacementSequence;
		}
		else
		{
			r ~= t[0..$-s.length];
		}
		n = validLength(s);
		r ~= s[0..n];
		s = s[n..$];
	}
	return r.toIArray;
}

unittest
{
	assert(sanitize("hello \xF0\x80world") == "hello \xEF\xBF\xBDworld");
}

/**
 * Returns the slice of the input string from the first character to the end
 * of the first encoded sequence. The resulting string may consist of multiple
 * code units, but it will always represent at most one character. If the input
 * is the empty string, the return value will be the empty string
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string to be sliced
 */
invariant(E)[] firstSequence(E)(invariant(E)[] s)
in
{
	assert(s.length != 0);
	invariant(E)[] u = s;
	assert(safeDecode(u) != INVALID_SEQUENCE);
}
body
{
	invariant(E)[] t = s;
	EncoderInstance!(E).skip(s);
	return t[0..$-s.length];
}

unittest
{
	assert(firstSequence("\u20AC100") == "\u20AC");
}

/**
 * Returns the slice of the input string from the start of the last encoded
 * sequence to the end of the string. The resulting string may consist of
 * multiple code units, but it will always represent at most one character.
 * If the input is the empty string, the return value will be the empty string.
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string to be sliced
 */
invariant(E)[] lastSequence(E)(invariant(E)[] s)
in
{
	assert(s.length != 0);
	assert(isValid(s));
}
body
{
	invariant(E)[] t = s;
	EncoderInstance!(E).decodeReverse(s);
	return t[$-s.length..$];
}

unittest
{
	assert(lastSequence("100\u20AC") == "\u20AC");
}

/**
 * Returns the total number of code points encoded in a string.
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * Supercedes:
 * This function supercedes std.utf.toUCSindex().
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string to be counted
 */
uint count(E)(invariant(E)[] s)
in
{
	assert(isValid(s));
}
body
{
	uint n = 0;
	while (s.length != 0)
	{
		EncoderInstance!(E).skip(s);
		++n;
	}
	return n;
}

unittest
{
	assert(count("\u20AC100") == 4);
}

/**
 * Returns the array index at which the (n+1)th code point begins.
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * Supercedes:
 * This function supercedes std.utf.toUTFindex().
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string to be counted
 */
int index(E)(invariant(E)[] s,int n)
in
{
	assert(isValid(s));
	assert(n >= 0);
}
body
{
	invariant(E)[] t = s;
	for (uint i=0; i<n; ++i) EncoderInstance!(E).skip(s);
	return t.length - s.length;
}

unittest
{
	assert(index("\u20AC100",1) == 3);
}

/**
 * Decodes a single code point.
 *
 * This function removes one or more code units from the start of a string,
 * and returns the decoded code point which those code units represent.
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * Supercedes:
 * This function supercedes std.utf.decode(), however, note that the
 * function codePoints() supercedes it more conveniently.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string whose first code point is to be decoded
 */
dchar decode(E)(ref invariant(E)[] s)
in
{
	assert(s.length != 0);
	invariant(E)[] u = s;
	assert(safeDecode(u) != INVALID_SEQUENCE);
}
body
{
	return EncoderInstance!(E).decode(s);
}

/**
 * Decodes a single code point from the end of a string.
 *
 * This function removes one or more code units from the end of a string,
 * and returns the decoded code point which those code units represent.
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string whose first code point is to be decoded
 */
dchar decodeReverse(E)(ref invariant(E)[] s)
in
{
	assert(s.length != 0);
	assert(isValid(s));
}
body
{
	return EncoderInstance!(E).decodeReverse(s);
}

/**
 * Decodes a single code point. The input does not have to be valid.
 *
 * This function removes one or more code units from the start of a string,
 * and returns the decoded code point which those code units represent.
 *
 * This function will accept an invalidly encoded string as input.
 * If an invalid sequence is found at the start of the string, this
 * function will remove it, and return the value INVALID_SEQUENCE.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string whose first code point is to be decoded
 */
dchar safeDecode(E)(ref invariant(E)[] s)
in
{
	assert(s.length != 0);
}
body
{
	return EncoderInstance!(E).safeDecode(s);
}

/**
 * Encodes a single code point.
 *
 * This function encodes a single code point into one or more code units.
 * It returns a string containing those code units.
 *
 * The input to this function MUST be a valid code point.
 * This is enforced by the function's in-contract.
 *
 * The type of the output cannot be deduced. Therefore, it is necessary to
 * explicitly specify the encoding as a template parameter.
 *
 * Supercedes:
 * This function supercedes std.utf.encode(), however, note that the
 * function codeUnits() supercedes it more conveniently.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    c = the code point to be encoded
 */
invariant(E)[] encode(E)(dchar c)
in
{
	assert(isValidCodePoint(c));
}
body
{
	return EncoderInstance!(E).encode(c);
}

/**
 * Encodes a single code point into a Buffer.
 *
 * This function encodes a single code point into one or more code units
 * The code units are stored in a growable buffer.
 *
 * The input to this function MUST be a valid code point.
 * This is enforced by the function's in-contract.
 *
 * The type of the output cannot be deduced. Therefore, it is necessary to
 * explicitly specify the encoding as a template parameter.
 *
 * Supercedes:
 * This function supercedes std.utf.encode(), however, note that the
 * function codeUnits() supercedes it more conveniently.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    c = the code point to be encoded
 */
void encode(E)(dchar c, ref Buffer!(E) buffer)
in
{
	assert(isValidCodePoint(c));
}
body
{
	EncoderInstance!(E).encode(c,buffer);
}

/**
 * Encodes a single code point to a delegate.
 *
 * This function encodes a single code point into one or more code units.
 * The code units are passed one at a time to the supplied delegate.
 *
 * The input to this function MUST be a valid code point.
 * This is enforced by the function's in-contract.
 *
 * The type of the output cannot be deduced. Therefore, it is necessary to
 * explicitly specify the encoding as a template parameter.
 *
 * Supercedes:
 * This function supercedes std.utf.encode(), however, note that the
 * function codeUnits() supercedes it more conveniently.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    c = the code point to be encoded
 */
void encode(E)(dchar c, void delegate(E) dg)
in
{
	assert(isValidCodePoint(c));
}
body
{
	EncoderInstance!(E).encode(c,dg);
}

/**
 * Returns a foreachable struct which can bidirectionally iterate over all
 * code points in a string.
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * You can foreach either
 * with or without an index. If an index is specified, it will be initialized
 * at each iteration with the offset into the string at which the code point
 * begins.
 *
 * Supercedes:
 * This function supercedes std.utf.decode().
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the string to be decoded
 *
 * Examples:
 * --------------------------------------------------------
 * string s = "hello world";
 * foreach(c;codePoints(s))
 * {
 *     // do something with c (which will always be a dchar)
 * }
 * --------------------------------------------------------
 *
 * Note that, currently, foreach(c:codePoints(s)) is superior to foreach(c;s)
 * in that the latter will fall over on encountering U+FFFF.
 */
CodePoints!(E) codePoints(E)(invariant(E)[] s)
in
{
	assert(isValid(s));
}
body
{
	return CodePoints!(E)(s);
}

unittest
{
	string s = "hello";
	string t;
	foreach(c;codePoints(s))
	{
		t ~= cast(char)c;
	}
	assert(s == t);
}

/**
 * Returns a foreachable struct which can bidirectionally iterate over all
 * code units in a code point.
 *
 * The input to this function MUST be a valid code point.
 * This is enforced by the function's in-contract.
 *
 * The type of the output cannot be deduced. Therefore, it is necessary to
 * explicitly specify the encoding type in the template parameter.
 *
 * Supercedes:
 * This function supercedes std.utf.encode().
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    d = the code point to be encoded
 *
 * Examples:
 * --------------------------------------------------------
 * dchar d = '\u20AC';
 * foreach(c;codeUnits!(Utf8)(d))
 * {
 *     writefln("%X",c)
 * }
 * // will print
 * // E2
 * // 82
 * // AC
 * --------------------------------------------------------
 */
CodeUnits!(E) codeUnits(E)(dchar c)
in
{
	assert(isValidCodePoint(c));
}
body
{
	return CodeUnits!(E)(c);
}

unittest
{
	Utf8[] a;
	foreach(c;codeUnits!(Utf8)(cast(dchar)'\u20AC'))
	{
		a ~= c;
	}
	assert(a.length == 3);
	assert(a[0] == 0xE2);
	assert(a[1] == 0x82);
	assert(a[2] == 0xAC);
}

/**
 * Convert a string from one encoding to another. (See also to!() below).
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * Supercedes:
 * This function supercedes std.utf.toUTF8(), std.utf.toUTF16() and
 * std.utf.toUTF32()
 * (but note that to!() supercedes it more conveniently).
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    s = the source string
 *    r = the destination string
 *
 * Examples:
 * --------------------------------------------------------
 * wstring ws;
 * transcode("hello world",ws);
 *     // transcode from UTF-8 to UTF-16
 *
 * EString!(Latin1) ls;
 * transcode(ws, ls);
 *     // transcode from UTF-16 to ISO-8859-1
 * --------------------------------------------------------
 */
void transcode(Src,Dst)(invariant(Src)[] s,out invariant(Dst)[] r)
in
{
	assert(isValid(s));
}
body
{
	static if(is(Src==Dst))
	{
		r = s;
	}
	else static if(is(Src==Ascii))
	{
		transcode!(char,Dst)(cast(string)s,r);
	}
	else
	{
		while (s.length != 0)
		{
			r ~= encode!(Dst)(decode(s));
		}
	}
}

/**
 * Convert a string from one encoding to another. (See also transcode() above).
 *
 * The input to this function MUST be validly encoded.
 * This is enforced by the function's in-contract.
 *
 * Supercedes:
 * This function supercedes std.utf.toUTF8(), std.utf.toUTF16() and
 * std.utf.toUTF32().
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    Dst = the destination encoding type
 *    s = the source string
 *
 * Examples:
 * -----------------------------------------------------------------------------
 * auto ws = to!(Utf16)("hello world");  // transcode from UTF-8 to UTF-16
 * auto ls = to!(Latin1)(ws);            // transcode from UTF-16 to ISO-8859-1
 * -----------------------------------------------------------------------------
 */
invariant(Dst)[] to(Dst,Src)(invariant(Src)[] s)
in
{
	assert(isValid(s));
}
body
{
	invariant(Dst)[] r;
	transcode(s,r);
	return r;
}

// Helper functions
version(unittest)
{
	void transcodeReverse(Src,Dst)(invariant(Src)[] s, out invariant(Dst)[] r)
	{
		static if(is(Src==Dst))
		{
			return s;
		}
		else static if(is(Src==Ascii))
		{
			transcodeReverse!(char,Dst)(cast(string)s,r);
		}
		else
		{
			foreach_reverse(d;codePoints(s))
			{
				foreach_reverse(c;codeUnits!(Dst)(d))
				{
					r = c ~ r;
				}
			}
		}
	}

	string makeReadable(string s)
	{
		string r = "\"";
		foreach(char c;s)
		{
			if (c >= 0x20 && c < 0x80)
			{
				r ~= c;
			}
			else
			{
				r ~= "\\x";
				r ~= toHexDigit(c >> 4);
				r ~= toHexDigit(c);
			}
		}
		r ~= "\"";
		return r;
	}

	string makeReadable(wstring s)
	{
		string r = "\"";
		foreach(wchar c;s)
		{
			if (c >= 0x20 && c < 0x80)
			{
				r ~= c;
			}
			else
			{
				r ~= "\\u";
				r ~= toHexDigit(c >> 12);
				r ~= toHexDigit(c >> 8);
				r ~= toHexDigit(c >> 4);
				r ~= toHexDigit(c);
			}
		}
		r ~= "\"w";
		return r;
	}

	string makeReadable(dstring s)
	{
		string r = "\"";
		foreach(dchar c;s)
		{
			if (c >= 0x20 && c < 0x80)
			{
				r ~= c;
			}
			else if (c < 0x10000)
			{
				r ~= "\\u";
				r ~= toHexDigit(c >> 12);
				r ~= toHexDigit(c >> 8);
				r ~= toHexDigit(c >> 4);
				r ~= toHexDigit(c);
			}
			else
			{
				r ~= "\\U00";
				r ~= toHexDigit(c >> 20);
				r ~= toHexDigit(c >> 16);
				r ~= toHexDigit(c >> 12);
				r ~= toHexDigit(c >> 8);
				r ~= toHexDigit(c >> 4);
				r ~= toHexDigit(c);
			}
		}
		r ~= "\"d";
		return r;
	}

	char toHexDigit(int n)
	{
		return "0123456789ABCDEF"[n & 0xF];
	}
}

