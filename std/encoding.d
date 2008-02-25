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

Date: 2006.02.21

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
	foreach(a;invalidStrings)
	{
		string s = cast(string)a;
		string t = sanitize(s);
		assert(isValid(t));
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

// Unit tests over. Now for the code...

template Encoding(T)
{
	static if (is(T==char))
	{
		enum MAX_SEQUENCE_LENGTH = 4;

		invariant(char)[] encodingName = "UTF-8";

		byte[256] tailTable =
		[
			-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
			-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
			-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
			-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
			-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
			-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
			-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
			-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
			0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
			-1,-1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
			1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
			2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
			3,3,3,3,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
		];

		bool isValidCodeUnit(T c)
		{
			return c < 0x80 || tails(c) >= 0;
		}

		int tails(T c)
		{
			return tailTable[c];
		}

		bool isSingle(T c)
		{
			return c < 0x80;
		}

		bool isHead(T c)
		{
			return tails(c) > 0;
		}

		bool isTail(T c)
		{
			return tails(c) == 0;
		}

		bool badTail(const(T)[] s, uint n)
		{
			if (n > s.length) return true;
			for (uint i=0; i<n; ++i)
			{
				if (!isTail(s[i])) return true;
			}
			return false;
		}

		bool isInvalidHeadTail(T c, T d)
		{
			switch(c)								// Deal with special cases
			{
			case 0xE0: return (d & 0xE0) == 0x80;	// fail overlong 3-byte sequences
			case 0xED: return (d & 0xE0) == 0xA0;	// fail surrogates
			case 0xF0: return (d & 0xF0) == 0x80;	// fail overlong 4-byte sequences
			case 0xF4: return (d & 0xF0) >= 0x90;	// fail code points > 0x10FFFF
			default:   return false;
			}
		}

		uint encode(dchar c,T[] buffer)
		in
		{
			assert(isValidCodePoint(c));
			assert(buffer.length >= MAX_SEQUENCE_LENGTH);
		}
		body
		{
			if (c < 0x80)
			{
				buffer[0] = c;
				return 1;
			}
			else if (c < 0x800)
			{
				buffer[0] = (c >> 6) + 0xC0;
				buffer[1] = (c & 0x3F) + 0x80;
				return 2;
			}
			else if (c < 0x10000)
			{
				buffer[0] = (c >> 12) + 0xE0;
				buffer[1] = ((c >> 6) & 0x3F) + 0x80;
				buffer[2] = (c & 0x3F) + 0x80;
				return 3;
			}
			else
			{
				buffer[0] = (c >> 18) + 0xF0;
				buffer[1] = ((c >> 12) & 0x3F) + 0x80;
				buffer[2] = ((c >> 6) & 0x3F) + 0x80;
				buffer[3] = (c & 0x3F) + 0x80;
				return 4;
			}
		}

		dchar decodeSingleSequence(ref string s)
		in
		{
			assert(s.length != 0);
			assert(!isSingle(s[0]));
			assert(isValid(firstSequence(s)));
		}
		body
		{
			uint c = s[0];
			int n = tails(c);
			assert(n > 0);
			c &= (1 << (6 - n)) - 1;
			foreach(T d;s[1..n+1])
			{
				c = (c << 6) + (d & 0x3F);
			}
			s = s[n+1..$];
			return c;
		}

		dchar decodeSingleSequenceReverse(ref string s)
		in
		{
			assert(s.length != 0);
			assert(!isSingle(s[$-1]));
			assert(isValid(lastSequence(s)));
		}
		body
		{
			uint c = s[$-1];
			uint i;
			uint shift = 0;
			c &= 0x3F;
			for (i=s.length-2; i>=0; --i)
			{
				shift += 6;
				assert(shift < 24);
				uint d = s[i];
				uint n = tails(d);
				uint mask = n == 0 ? 0x3F : (1 << (6 - n)) - 1;
				c = c + ((d & mask) << shift);
				if (n != 0) break;
			}
			s = s[0..i];
			return c;
		}

		void appendReplacementChar(ref string s)
		{
			s ~= "\xEF\xBF\xBD";
		}
	}
	else static if (is(T==wchar))
	{
		alias wstring string;

		invariant(char)[] encodingName = "UTF-16";

		bool isValidCodeUnit(T c)
		{
			return true;
		}

		enum MAX_SEQUENCE_LENGTH = 2;

		bool isSingle(T c)
		{
			return c < 0xD800 || c >= 0xE000;
		}

		int tails(T c)
		{
			return 1;
		}

		bool isHead(T c)
		{
			return c >= 0xD800 && c < 0xDC00;
		}

		bool isTail(T c)
		{
			return c >= 0xDC00 && c < 0xE000;
		}

		bool badTail(const(T)[] s, uint n)
		{
			return (!isTail(s[0]));
		}

		bool isInvalidHeadTail(T c, T d)
		{
			return false;
		}

		uint encode(dchar c,T[] buffer)
		in
		{
			assert(isValidCodePoint(c));
			assert(buffer.length >= MAX_SEQUENCE_LENGTH);
		}
		body
		{
			if (c < 0x10000)
			{
				buffer[0] = c;
				return 1;
			}
			else
			{
				c -= 0x10000;
				buffer[0] = (c >> 10) + 0xD800;
				buffer[1] = (c & 0x3FF) + 0xDC00;
				return 2;
			}
		}

		dchar decodeSingleSequence(ref string s)
		in
		{
			assert(s.length != 0);
			assert(!isSingle(s[0]));
			assert(isValid(firstSequence(s)));
		}
		body
		{
			uint c = s[0];
			uint d = s[1];
			s = s[2..$];
			return ((c & 0x3FF) << 10) + (d & 0x3FF) + 0x10000;
		}

		dchar decodeSingleSequenceReverse(ref string s)
		in
		{
			assert(s.length != 0);
			assert(!isSingle(s[$-1]));
			assert(isValid(lastSequence(s)));
		}
		body
		{
			uint c = s[$-1];
			uint d = s[$-2];
			s = s[0..$-2];
			return ((d & 0x3FF) << 10) + (c & 0x3FF) + 0x10000;
		}

		void appendReplacementChar(ref string s)
		{
			s ~= cast(T)0xFFFD;
		}
	}
	else static if (is(T==dchar))
	{
		alias dstring string;

		enum MAX_SEQUENCE_LENGTH = 1;

		invariant(char)[] encodingName = "UTF-32";

		alias isValidCodePoint isValidCodeUnit;

		alias isValidCodePoint isSingle;

		int tails(T c)
		{
			return -1;
		}

		bool isHead(T c)
		{
			return false;
		}

		alias isHead isTail;

		bool badTail(const(T)[] s, uint n)
		{
			return false;
		}

		bool isInvalidHeadTail(T c, T d)
		{
			return false;
		}

		uint encode(dchar c,T[] buffer)
		in
		{
			assert(isValidCodePoint(c));
			assert(buffer.length >= MAX_SEQUENCE_LENGTH);
		}
		body
		{
			buffer[0] = c;
			return 1;
		}

		dchar decodeSingleSequence(ref string s)
		in
		{
			assert(false);
		}
		body
		{
			return 0;
		}

		dchar decodeSingleSequenceReverse(ref string s)
		in
		{
			assert(false);
		}
		body
		{
			return 0;
		}

		void appendReplacementChar(ref string s)
		{
			s ~= cast(T)0xFFFD;
		}
	}
	else static if (is(T:Ascii))
	{
		alias invariant(Ascii)[] string;

		enum MAX_SEQUENCE_LENGTH = 1;

		invariant(char)[] encodingName = "ASCII";

		bool isValidCodeUnit(T c)
		{
			return c < 0x80;
		}

		alias isValidCodeUnit isSingle;

		int tails(T c)
		{
			return -1;
		}

		bool isHead(T c)
		{
			return false;
		}

		alias isHead isTail;

		bool badTail(const(T)[] s, uint n)
		{
			return false;
		}

		bool isInvalidHeadTail(T c, T d)
		{
			return false;
		}

		uint encode(dchar c,T[] buffer)
		in
		{
			assert(isValidCodePoint(c));
			assert(buffer.length >= MAX_SEQUENCE_LENGTH);
		}
		body
		{
			buffer[0] = cast(T)(c < 0x80 ? c : '?');
			return 1;
		}

		dchar decodeSingleSequence(ref string s)
		in
		{
			assert(false);
		}
		body
		{
			return 0;
		}

		dchar decodeSingleSequenceReverse(ref string s)
		in
		{
			assert(false);
		}
		body
		{
			return 0;
		}

		void appendReplacementChar(ref string s)
		{
			s ~= cast(T)'?';
		}
	}
	else static if (is(T:Latin1))
	{
		alias invariant(Latin1)[] string;

		enum MAX_SEQUENCE_LENGTH = 1;

		invariant(char)[] encodingName = "ISO-8859-1";

		bool isValidCodeUnit(T c)
		{
			return true;
		}

		alias isValidCodeUnit isSingle;

		int tails(T c)
		{
			return -1;
		}

		bool isHead(T c)
		{
			return false;
		}

		alias isHead isTail;

		bool badTail(const(T)[] s, uint n)
		{
			return false;
		}

		bool isInvalidHeadTail(T c, T d)
		{
			return false;
		}

		uint encode(dchar c,T[] buffer)
		in
		{
			assert(isValidCodePoint(c));
			assert(buffer.length >= MAX_SEQUENCE_LENGTH);
		}
		body
		{
			buffer[0] = cast(T)(c < 0x100 ? c : '?');
			return 1;
		}

		dchar decodeSingleSequence(ref string s)
		in
		{
			assert(false);
		}
		body
		{
			return 0;
		}

		dchar decodeSingleSequenceReverse(ref string s)
		in
		{
			assert(false);
		}
		body
		{
			return 0;
		}

		void appendReplacementChar(ref string s)
		{
			s ~= cast(T)'?';
		}
	}
	else static if (is(T:Windows1252))
	{
		alias invariant(Windows1252)[] string;

		enum MAX_SEQUENCE_LENGTH = 1;

		invariant(char)[] encodingName = "WINDOWS-1252";

		wstring charMap =
			"\u20AC\uFFFD\u201A\u0192\u201E\u2026\u2020\u2021"
			"\u02C6\u2030\u0160\u2039\u0152\uFFFD\u017D\uFFFD"
			"\uFFFD\u2018\u2019\u201C\u201D\u2022\u2103\u2014"
			"\u02DC\u2122\u0161\u203A\u0153\uFFFD\u017E\u0178"
		;

		dchar win2uni(T c)
		{
			return isSingle(c) ? c : charMap[c-0x80];
		}

		T uni2win(dchar c)
		{
			if (c < 0x80 || (c >= 0xA0 && c < 0x100)) return cast(T)c;
			if (c != 0xFFFD)
			{
				foreach(n,d;charMap)
				{
					if (c == d) return cast(T)(n + 0x80);
				}
			}
			return '?';
		}

		bool isValidCodeUnit(T c)
		{
			return(win2uni(c) != 0xFFFD);
		}

		bool isSingle(T c)
		{
			return c < 0x80 || c >= 0xA0;
		}

		int tails(T c)
		{
			return isSingle(c) ? -1 : 0;
		}

		bool isHead(T c)
		{
			return isSingle(c) ? false : isValidCodeUnit(c);
		}

		bool isTail(T c)
		{
			return false;
		}

		bool badTail(const(T)[] s, uint n)
		{
			return false;
		}

		bool isInvalidHeadTail(T c, T d)
		{
			return false;
		}

		uint encode(dchar c,T[] buffer)
		in
		{
			assert(isValidCodePoint(c));
			assert(buffer.length >= MAX_SEQUENCE_LENGTH);
		}
		body
		{
			buffer[0] = uni2win(c);
			return 1;
		}

		dchar decodeSingleSequence(ref string s)
		in
		{
			assert(s.length != 0);
		}
		body
		{
			dchar c = win2uni(s[0]);
			s = s[1..$];
			return c;
		}

		dchar decodeSingleSequenceReverse(ref string s)
		in
		{
			assert(s.length != 0);
		}
		body
		{
			dchar c = win2uni(s[$-1]);
			s = s[0..$-1];
			return c;
		}

		void appendReplacementChar(ref string s)
		{
			s ~= cast(T)'?';
		}
	}
	// NOTE: The "else" case is commented out because it doesn't work (yet?)
	// because of some template issues which have yet to be resolved. Expect
	// this to work in some future release.
/+
	else // The generic case. All other encodings.
	{
		alias invariant(T)[] string;

		static if(is(T.MAX_SEQUENCE_LENGTH))
		{
			enum MAX_SEQUENCE_LENGTH = T.MAX_SEQUENCE_LENGTH;
		}
		else
		{
			enum MAX_SEQUENCE_LENGTH = 1;
		}

		invariant(char)[] encodingName()
		{
			return T.encodingName;
		}

		bool isValidCodeUnit(T c)
		{
			return c.isValidCodeUnit;
		}

		bool isSingle(T c)
		{
			static if (is(T.isSingle == function))
			{
				return c.isSingle;
			}
			else
			{
				return c.isValidCodeUnit;
			}
		}

		int tails(T c)
		{
			static if (is(T.tails == function))
			{
				return c.tails();
			}
			else
			{
				return -1;
			}
		}

		bool isHead(T c)
		{
			static if(is(T.isHead == function))
			{
				return c.isHead;
			}
			else
			{
				return false;
			}
		}

		bool isTail(T c)
		{
			static if(is(T.isTail == function))
			{
				return c.isTail;
			}
			else
			{
				return false;
			}
		}

		bool badTail(const(T)[] s, uint n)
		{
			static if(is(T.badTail == function))
			{
				return T.badTail(s,n);
			}
			else
			{
				return false;
			}
		}

		bool isInvalidHeadTail(T c, T d)
		{
			static if(is(T.isInvalidHeadTail == function))
			{
				return c.isInvalidHeadTail(d);
			}
			else
			{
				return false;
			}
		}

		uint encode(dchar c,T[] buffer)
		in
		{
			assert(isValidCodePoint(c));
			assert(buffer.length >= MAX_SEQUENCE_LENGTH);
		}
		body
		{
			return encode(c,buffer);
		}

		dchar decodeSingleSequence(ref string s)
		{
			static if(is(T.decodeSingleSequence == function))
			{
				return T.decodeSingleSequence(s);
			}
			else
			{
				assert(false);
				return 0;
			}
		}

		dchar decodeSingleSequenceReverse(ref string s)
		{
			static if(is(T.decodeSingleSequenceReverse == function))
			{
				return T.decodeSingleSequenceReverse(s);
			}
			else
			{
				assert(false);
				return 0;
			}
		}

		void appendReplacementChar(ref string s)
		{
			if (is(T.replacementChar == function))
			{
				s ~= T.replacementChar();
			}
			else
			{
				s ~= cast(T)'?';
			}
		}
	}
+/

	uint pseudoSequenceLength(string s)
	{
		assert(s.length != 0);
		if (!isValidCodeUnit(s[0])) return 1;
		int i = isHead(s[0]) ? 1 : 0;
		for (; i < s.length; ++i)
		{
			if (!isTail(s[i])) break;
		}
		assert(i != 0);
		return i;
	}

	string firstSequence(string s)
	{
		foreach(i,T c;s[1..$])
		{
			if (!isTail(c)) return s[0..i+1];
		}
		return s;
	}

	string lastSequence(string s)
	{
		foreach_reverse(i,T c;s)
		{
			if (!isTail(c)) return s[i..$];
		}
		return s;
	}

	// find the first invalid code unit
	uint validatePartial(const(T)[] s)
	{
		uint i;
		for (i=0; i<s.length; ++i)
		{
			T c = s[i];
			if (isSingle(c)) continue;
			uint n = tails(c);
			if (n <= 0) return i;						// fail with illegal code units
			if (i + n >= s.length) return i;			// fail if we exceed the length of the string
			if (isInvalidHeadTail(c,s[i+1])) return i;	// fail with invalid head/tail combinations
			if (badTail(s[i+1..$],n)) return i;			// fail incomplete sequences
			i += n;										// step over whole sequence
		}
		return i;
	}

	bool isValid(const(T)[] s)
	{
		return validatePartial(s) == s.length;
	}

	string sanitize(string s)
	out(r)
	{
		assert(isValid(r));
	}
	body
	{
		uint i = validatePartial(s);
		if (i == s.length) return s;	// If string is valid, return the original

		string r = s[0..i].idup;
		while (i < s.length)
		{
			appendReplacementChar(r);
			i += pseudoSequenceLength(s[i..$]);
			uint n = validatePartial(s[i..$]);
			r ~= s[i..i+n];
			i += n;
		}
		return r;
	}

	uint count(string s)
	in
	{
		assert(isValid(s));
	}
	body
	{
		uint i = 0;
		foreach(T c;s)
		{
			if (!isTail(c)) ++i;
		}
		return i;
	}

	int index(string s, int n)
	in
	{
		assert(isValid(s));
		assert(n >= 0);
	}
	body
	{
		uint i = 0;
		foreach(j,T c;s)
		{
			if (!isTail(c))
			{
				if (i == n) return j;
				++i;
			}
		}
		return i == n ? s.length : -1;
	}

	dchar decode(ref string s)
	in
	{
		assert(s.length != 0);
		assert(isValid(firstSequence(s)));
	}
	body
	{
		T c = s[0];
		if (isSingle(c))
		{
			s = s[1..$];
			return c;
		}
		return decodeSingleSequence(s);
	}

	dchar decodeSingleReverse(ref string s)
	in
	{
		assert(s.length != 0);
		assert(isValid(lastSequence(s)));
	}
	body
	{
		T c = s[$-1];
		if (isSingle(c))
		{
			s = s[0..$-1];
			return c;
		}
		return decodeSingleSequenceReverse(s);
	}

	struct CodePoints
	{
		string s;

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
				dchar c = decodeSingleReverse(s);
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
				dchar c = decodeSingleReverse(s);
				uint i = s.length;
				result = dg(i,c);
				if (result != 0) break;
			}
			return result;
		}
	}

	CodePoints codePoints(string s)
	{
		CodePoints ci;
		ci.s = s;
		return ci;
	}

	struct CodeUnits
	{
		T[MAX_SEQUENCE_LENGTH] buffer;
		uint len;

		int opApply(int delegate(ref T) dg)
		{
			int result = 0;
			foreach(T c;buffer[0..len])
			{
				result = dg(c);
				if (result != 0) break;
			}
			return result;
		}

		int opApplyReverse(int delegate(ref T) dg)
		{
			int result = 0;
			foreach_reverse(T c;buffer[0..len])
			{
				result = dg(c);
				if (result != 0) break;
			}
			return result;
		}
	}

	CodeUnits codeUnits(dchar d)
	in
	{
		assert(isValidCodePoint(d));
	}
	body
	{
		CodeUnits codeUnits;
		codeUnits.len = encode(d,codeUnits.buffer);
		return codeUnits;
	}
}

alias char Utf8;			/// A type representing the UTF-8 encoding (an alias of char)
alias wchar Utf16;			/// A type representing the UTF-16 encoding	(an alias of wchar)
alias dchar Utf32;			/// A type representing the UTF-32 encoding	(an alias of dchar)
typedef char Ascii;			/// A type representing the ASCII encoding (a typedef of char)
typedef ubyte Latin1;		/// A type representing the ISO-8859-1 (aka Latin-1) encoding (a typedef of ubyte)
typedef ubyte Windows1252;	/// A type representing the WINDOWS-1252 encoding (a typedef of ubyte)

/**
 * A type representing a string of some specified encoding. The encoding is specified by the template parameter.
 */
template EString(T)
{
	alias invariant(T)[] EString;
}

/**
 * Returns the name of an encoding.
 *
 * The type of the output cannot be deduced. Therefore, it is necessary to
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
	return Encoding!(T).encodingName;
}

unittest
{
	assert(encodingName!(Utf8) == "UTF-8");
	assert(encodingName!(Utf16) == "UTF-16");
	assert(encodingName!(Utf32) == "UTF-32");
	assert(encodingName!(Ascii) == "ASCII");
	assert(encodingName!(Latin1) == "ISO-8859-1");
}

/**
 * Returns true if c is a valid code point
 *
 * Note that this includes the non-character code points U+FFFE and U+FFFF,
 * since these are valid code points (even though they are not valid
 * characters).
 *
 * Supercedes:
 * This function supercedes std.utf.isValidDchar().
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
 * Returns true if the code unit is legal. For example, the byte 0x80 would
 * not be legal in ASCII, because ASCII code units must always be in the range
 * 0x00 to 0x7F.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    c = the code unit to be tested
 */
bool isValidCodeUnit(T)(T c)
{
	return Encoding!(T).isValidCodeUnit(c);
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
bool isValid(T)(const(T)[] s)
{
	return Encoding!(T).isValid(s);
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
invariant(T)[] sanitize(T)(invariant(T)[] s)
{
	return Encoding!(T).sanitize(s);
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
invariant(T)[] firstSequence(T)(invariant(T)[] s)
{
	return Encoding!(T).firstSequence(s);
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
invariant(T)[] lastSequence(T)(invariant(T)[] s)
{
	return Encoding!(T).lastSequence(s);
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
uint count(T)(invariant(T)[] s)
{
	return Encoding!(T).count(s);
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
int index(T)(invariant(T)[] s,int n)
{
	return Encoding!(T).index(s,n);
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
dchar decode(T)(ref invariant(T)[] s)
{
	return Encoding!(T).decode(s);
}

/**
 * Encodes a single code point.
 *
 * This function encodes a single code point into one or more code units.
 * It returns a string containing those code units.
 *
 * The input to this function MUST be a valid code point.
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
invariant(T)[] encode(T)(dchar c)
{
	T[] buffer = new T[4];
	uint len = encode(c,buffer);
	return cast(invariant(T)[])(buffer[0..len]);
}

/**
 * Encodes a single code point into a user-supplied buffer.
 *
 * The input to this function MUST be a valid code point.
 *
 * The user-supplied buffer needs to be of type T[], where T is the encoding
 * type (currently one of Utf8, Utf16, Utf32, Ascii, Latin1 or Windows1252).
 * Note that Utf8, Utf16 and Utf32 are aliases for char, wchar and dchar
 * respectively.
 *
 * Supercedes:
 * This function supercedes std.utf.encode(), however, note that the
 * function codeUnits() supercedes it more conveniently.
 *
 * Standards: Unicode 5.0, ASCII, ISO-8859-1, WINDOWS-1252
 *
 * Params:
 *    c = the code point to be encoded
 *    buffer = where to store the output
 */
uint encode(T)(dchar c,T[] buffer)
in
{
	assert(buffer.length >= 4);
}
body
{
	return Encoding!(T).encode(cast(uint)c,buffer);
}

template CodePoints(T)
{
	alias Encoding!(T).CodePoints CodePoints;
}

template CodeUnits(T)
{
	alias Encoding!(T).CodeUnits CodeUnits;
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
CodePoints!(T) codePoints(T)(invariant(T)[] s)
{
	return Encoding!(T).codePoints(s);
}

/**
 * Returns a foreachable struct which can bidirectionally iterate over all
 * code units in a code point.
 *
 * The input to this function MUST be a valid code point.
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
CodeUnits!(T) codeUnits(T)(dchar d)
{
	return Encoding!(T).codeUnits(d);
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
void transcode(T,U)(invariant(T)[] s,out invariant(U)[] r)
{
	static if(is(T==U))
	{
		r = s;
	}
	else static if(is(T==Ascii))
	{
		transcode!(char,U)(cast(string)s,r);
	}
	else
	{
		foreach(d;codePoints(s))
		{
			foreach(c;codeUnits!(U)(d))
			{
				r ~= c;
			}
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
 *    U = the destination encoding type
 *    s = the source string
 *
 * Examples:
 * -----------------------------------------------------------------------------
 * auto ws = to!(Utf16)("hello world");  // transcode from UTF-8 to UTF-16
 * auto ls = to!(Latin1)(ws);            // transcode from UTF-16 to ISO-8859-1
 * -----------------------------------------------------------------------------
 */
invariant(U)[] to(U,T)(invariant(T)[] s)
{
	invariant(U)[] r;
	transcode(s,r);
	return r;
}

// Helper functions
debug
{
	void transcodeReverse(T,U)(invariant(T)[] s, out invariant(U)[] r)
	{
		static if(is(T==U))
		{
			return s;
		}
		else static if(is(T==Ascii))
		{
			transcodeReverse!(char,U)(cast(string)s,r);
		}
		else
		{
			foreach_reverse(d;codePoints(s))
			{
				foreach_reverse(c;codeUnits!(U)(d))
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
