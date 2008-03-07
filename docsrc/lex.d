Ddoc

$(SPEC_S Lexical,

	In D, the lexical analysis is independent of the syntax parsing and the
	semantic analysis. The lexical analyzer splits the source text up into
	tokens. The lexical grammar describes what those tokens are. The D
	lexical grammar is designed to be suitable for high speed scanning, it
	has a minimum of special case rules, there is only one phase of
	translation, and to make it easy to write a correct scanner
	for. The tokens are readily recognizable by those familiar with C and
	C++.

<h3>Phases of Compilation</h3>

	The process of compiling is divided into multiple phases. Each phase
	has no dependence on subsequent phases. For example, the scanner is
	not perturbed by the semantic analyzer. This separation of the passes
	makes language tools like syntax 
	directed editors relatively easy to produce.
	It also is possible to compress D source by storing it in
	'tokenized' form.

$(OL
	$(LI $(B source character set)$(BR)

	The source file is checked to see what character set it is,
	and the appropriate scanner is loaded. ASCII and UTF
	formats are accepted.
	)

	$(LI $(B script line) $(BR)

	If the first line starts with $(GREEN #!) then the first line
	is ignored.
	)

	$(LI $(B lexical analysis)$(BR)

	The source file is divided up into a sequence of tokens.
	$(LINK2 #specialtokens, Special tokens) are replaced with other tokens.
	$(LINK2 #specialtokenseq, Special token sequences)
	are processed and removed.
	)

	$(LI $(B syntax analysis)$(BR)

	The sequence of tokens is parsed to form syntax trees.
	)

	$(LI $(B semantic analysis)$(BR)

	The syntax trees are traversed to declare variables, load symbol tables, assign 
	types, and in general determine the meaning of the program.
	)

	$(LI $(B optimization)$(BR)

	Optimization is an optional pass that tries to rewrite the program
	in a semantically equivalent, but faster executing, version.
	)

	$(LI $(B code generation)$(BR)

	Instructions are selected from the target architecture to implement
	the semantics of the program. The typical result will be
	an object file, suitable for input to a linker.
	)
)


<h3>Source Text</h3>

	D source text can be in one of the following formats:

	$(UL 
	$(LI ASCII)
	$(LI UTF-8)
	$(LI UTF-16BE)
	$(LI UTF-16LE)
	$(LI UTF-32BE)
	$(LI UTF-32LE)
	)

	UTF-8 is a superset of traditional 7-bit ASCII.
	One of the
	following UTF BOMs (Byte Order Marks) can be present at the beginning
	of the source text:
	<p>

	$(TABLE1
	$(TR
	$(TH Format)
	$(TH BOM)
	)
	$(TR
	$(TD UTF-8)
	$(TD EF BB BF)
	)
	$(TR
	$(TD UTF-16BE)
	$(TD FE FF)
	)
	$(TR
	$(TD UTF-16LE)
	$(TD FF FE)
	)
	$(TR
	$(TD UTF-32BE)
	$(TD 00 00 FE FF)
	)
	$(TR
	$(TD UTF-32LE)
	$(TD FF FE 00 00)
	)
	$(TR
	$(TD ASCII)
	$(TD no BOM)
	)
	)

	$(P If the source file does not start with a BOM, then the first
	character must be less than or equal to U0000007F.)

	$(P There are no digraphs or trigraphs in D.)

	$(P The source text is decoded from its source representation
	into Unicode $(I Character)s.
	The $(I Character)s are further divided into:

	$(LINK2 #whitespace, white space),
	$(LINK2 #endofline, end of lines),
	$(LINK2 #comment, comments),
	$(LINK2 #specialtokens, special token sequences),
	$(LINK2 #tokens, tokens),
	all followed by $(LINK2 #eof, end of file).
	)

	$(P The source text is split into tokens using the maximal munch
	technique, i.e., the
	lexical analyzer tries to make the longest token it can. For example
	<code>>></code> is a right shift token,
	not two greater than tokens.
	)

<h3>$(LNAME2 eof, End of File)</h3>

$(GRAMMAR
$(I EndOfFile):
	$(I physical end of the file)
	\u0000
	\u001A
)

	The source text is terminated by whichever comes first.

<h3>$(LNAME2 endofline, End of Line)</h3>

$(GRAMMAR
$(I EndOfLine):
	\u000D
	\u000A
	\u000D \u000A
	$(I EndOfFile)
)

	There is no backslash line splicing, nor are there any limits
	on the length of a line.

<h3>$(LNAME2 whitespace, White Space)</h3>

$(GRAMMAR
$(I WhiteSpace):
	$(I Space)
	$(I Space) $(I WhiteSpace)

$(I Space):
	\u0020
	\u0009
	\u000B
	\u000C
)


<h3>$(LNAME2 comment, Comments)</h3>

$(GRAMMAR
$(I Comment):
	$(B /*) $(I Characters) $(B */)
	$(B //) $(I Characters) $(I EndOfLine)
	$(I NestingBlockComment)

$(I Characters):
	$(I Character)
	$(I Character) $(I Characters)

$(I NestingBlockComment):
	$(B /+) $(I NestingBlockCommentCharacters) $(B +/)

$(I NestingBlockCommentCharacters):
	$(I NestingBlockCommentCharacter)
	$(I NestingBlockCommentCharacter) $(I NestingBlockCommentCharacters)

$(I NestingBlockCommentCharacter):
	$(I Character)
	$(I NestingBlockComment)
)

	D has three kinds of comments:
	$(OL 
	$(LI Block comments can span multiple lines, but do not nest.)
	$(LI Line comments terminate at the end of the line.)
	$(LI Nesting comments can span multiple lines and can nest.)
	)

	$(P
	The contents of strings and comments are not tokenized.  Consequently,
	comment openings occurring within a string do not begin a comment, and
	string delimiters within a comment do not affect the recognition of
	comment closings and nested "/+" comment openings.  With the exception
	of "/+" occurring within a "/+" comment, comment openings within a
	comment are ignored.
	)

-------------
a = /+ // +/ 1;		// parses as if 'a = 1;'
a = /+ "+/" +/ 1";	// parses as if 'a = " +/ 1";'
a = /+ /* +/ */ 3;	// parses as if 'a = */ 3;'
-------------

	Comments cannot be used as token concatenators, for example,
	<code>abc/**/def</code> is two tokens, $(TT abc) and $(TT def),
	not one $(TT abcdef) token.

<h3>$(LNAME2 tokens, Tokens)</h3>

$(GRAMMAR
$(I Token):
	$(LINK2 #identifier, $(I Identifier))
	$(LINK2 #StringLiteral, $(I StringLiteral))
	$(LINK2 #characterliteral, $(I CharacterLiteral))
	$(LINK2 #integerliteral, $(I IntegerLiteral))
	$(LINK2 #floatliteral, $(I FloatLiteral))
	$(LINK2 #keyword, $(I Keyword))
	$(B /)
	$(B /=)
	$(B .)
	$(B ..)
	$(B ...)
	$(B &)
	$(B &=)
	$(B &&)
	$(B |)
	$(B |=)
	$(B ||)
	$(B -)
	$(B -=)
	$(B --)
	$(B +)
	$(B +=)
	$(B ++)
	$(B &lt;)
	$(B &lt;=)
	$(B &lt;&lt;)
	$(B &lt;&lt;=)
	$(B &lt;&gt;)
	$(B &lt;&gt=)
	$(B &gt;)
	$(B &gt;=)
	$(B &gt;&gt;=)
	$(B &gt;&gt;&gt;=)
	$(B &gt;&gt;)
	$(B &gt;&gt;&gt;)
	$(B !)
	$(B !=)
	$(B !&lt;&gt;)
	$(B !&lt;&gt;=)
	$(B !&lt;)
	$(B !&lt;=)
	$(B !&gt;)
	$(B !&gt;=)
	$(B $(LPAREN))
	$(B $(RPAREN))
	$(B [)
	$(B ])
	$(B {)
	$(B })
	$(B ?)
	$(B ,)
	$(B ;)
	$(B :)
	$(B $)
	$(B =)
	$(B ==)
	$(B *)
	$(B *=)
	$(B %)
	$(B %=)
	$(B ^)
	$(B ^=)
	$(B ~)
	$(B ~=)
)

<h3>$(LNAME2 identifier, Identifiers)</h3>

$(GRAMMAR
$(I Identifier):
	$(I IdentiferStart)
	$(I IdentiferStart) $(I IdentifierChars)

$(I IdentifierChars):
	$(I IdentiferChar)
	$(I IdentiferChar) $(I IdentifierChars)

$(I IdentifierStart):
	$(B _)
	$(I Letter)
	$(I UniversalAlpha)

$(I IdentifierChar):
	$(I IdentiferStart)
	$(B 0)
	$(I NonZeroDigit)
)


	Identifiers start with a letter, $(B _), or universal alpha,
	and are followed by any number
	of letters, $(B _), digits, or universal alphas.
	Universal alphas are as defined in ISO/IEC 9899:1999(E) Appendix D.
	(This is the C99 Standard.)
	Identifiers can be arbitrarily long, and are case sensitive.
	Identifiers starting with $(B __) (two underscores) are reserved.

<h3>$(LNAME2 StringLiteral, String Literals)</h3>

$(GRAMMAR
$(I StringLiteral):
	$(I WysiwygString)
	$(I AlternateWysiwygString)
	$(I DoubleQuotedString)
	$(I EscapeSequence)
	$(I HexString)
$(V2
	$(I DelimitedString)
	$(I TokenString))

$(I WysiwygString):
	$(B r") $(I WysiwygCharacters) $(B ") $(I Postfix<sub>opt</sub>)

$(I AlternateWysiwygString):
	$(B `) $(I WysiwygCharacters) $(B `) $(I Postfix<sub>opt</sub>)

$(I WysiwygCharacters):
	$(I WysiwygCharacter)
	$(I WysiwygCharacter) $(I WysiwygCharacters)

$(I WysiwygCharacter):
	$(I Character)
	$(I EndOfLine)

$(I DoubleQuotedString):
	$(B ") $(I DoubleQuotedCharacters) $(B ") $(I Postfix<sub>opt</sub>)

$(I DoubleQuotedCharacters):
	$(I DoubleQuotedCharacter)
	$(I DoubleQuotedCharacter) $(I DoubleQuotedCharacters)

$(I DoubleQuotedCharacter):
	$(I Character)
	$(I EscapeSequence)
	$(I EndOfLine)

$(LNAME2 EscapeSequence, $(I EscapeSequence)):
	$(B \')
	$(B \")
	$(B \?)
	$(B \\)
	$(B \a)
	$(B \b)
	$(B \f)
	$(B \n)
	$(B \r)
	$(B \t)
	$(B \v)
	$(B \) $(I EndOfFile)
	$(B \x) $(I HexDigit) $(I HexDigit)
	$(B \) $(I OctalDigit)
	$(B \) $(I OctalDigit) $(I OctalDigit)
	$(B \) $(I OctalDigit) $(I OctalDigit) $(I OctalDigit)
	$(B \u) $(I HexDigit) $(I HexDigit) $(I HexDigit) $(I HexDigit)
	$(B \U) $(I HexDigit) $(I HexDigit) $(I HexDigit) $(I HexDigit) $(I HexDigit) $(I HexDigit) $(I HexDigit) $(I HexDigit)
	$(B \&amp;) $(LINK2 entity.html, $(I NamedCharacterEntity)) $(B ;)

$(I HexString):
	$(B x") $(I HexStringChars) $(B ") $(I Postfix<sub>opt</sub>)

$(I HexStringChars):
	$(I HexStringChar)
	$(I HexStringChar) $(I HexStringChars)

$(I HexStringChar):
	$(I HexDigit)
	$(I WhiteSpace)
	$(I EndOfLine)

$(I Postfix):
	$(B c)
	$(B w)
	$(B d)

$(V2
$(I DelimitedString):
	$(B q") $(I Delimiter) $(I WysiwygCharacters) $(I MatchingDelimiter) $(B ")

$(I TokenString):
	$(B q{) $(I Tokens) $(B })
)
)

	$(P
	A string literal is either a double quoted string, a wysiwyg quoted
	string, an escape sequence,
	$(V2 a delimited string, a token string,)
	or a hex string.
	)

<h4>Wysiwyg Strings</h4>

	$(P
	Wysiwyg quoted strings are enclosed by r" and ".
	All characters between
	the r" and " are part of the string except for $(I EndOfLine) which is
	regarded as a single \n character.
	There are no escape sequences inside r" ":
	)

---------------
r"hello"
r"c:\root\foo.exe"
r"ab\n"			// string is 4 characters, 'a', 'b', '\', 'n'
---------------

	$(P
	An alternate form of wysiwyg strings are enclosed by backquotes,
	the ` character. The ` character is not available on some keyboards
	and the font rendering of it is sometimes indistinguishable from
	the regular ' character. Since, however, the ` is rarely used,
	it is useful to delineate strings with " in them.
	)

---------------
`hello`
`c:\root\foo.exe`
`ab\n`			// string is 4 characters, 'a', 'b', '\', 'n'
---------------

<h4>Double Quoted Strings</h4>

	Double quoted strings are enclosed by "". Escape sequences can be
	embedded into them with the typical \ notation.
	$(I EndOfLine) is regarded as a single \n character.

---------------
"hello"
"c:\\root\\foo.exe"
"ab\n"			// string is 3 characters, 'a', 'b', and a linefeed
"ab
"			// string is 3 characters, 'a', 'b', and a linefeed
---------------

<h4>Escape Strings</h4>

	$(P Escape strings start with a \ and form an escape character sequence.
	Adjacent escape strings are concatenated:
	)

<pre>
\n			the linefeed character
\t			the tab character
\"			the double quote character
\012			octal
\x1A			hex
\u1234			wchar character
\U00101234		dchar character
\&amp;reg;			&reg; dchar character
\r\n			carriage return, line feed
</pre>

	$(P Undefined escape sequences are errors.
	Although string literals are defined to be composed of
	UTF characters, the octal and hex escape sequences allow
	the insertion of arbitrary binary data.
	\u and \U escape sequences can only be used to insert
	valid UTF characters.
	)

<h4>Hex Strings</h4>

	$(P Hex strings allow string literals to be created using hex data.
	The hex data need not form valid UTF characters.
	)

--------------
x"0A"			// same as "\x0A"
x"00 FBCD 32FD 0A"	// same as "\x00\xFB\xCD\x32\xFD\x0A"
--------------

	Whitespace and newlines are ignored, so the hex data can be
	easily formatted.
	The number of hex characters must be a multiple of 2.
	<p>

	Adjacent strings are concatenated with the ~ operator, or by simple
	juxtaposition:

--------------
"hello " ~ "world" ~ \n	// forms the string 'h','e','l','l','o',' ',
			// 'w','o','r','l','d',linefeed
--------------

	The following are all equivalent:

-----------------
"ab" "c"
r"ab" r"c"
r"a" "bc"
"a" ~ "b" ~ "c"
\x61"bc"
-----------------

	The optional $(I Postfix) character gives a specific type
	to the string, rather than it being inferred from the context.
	This is useful when the type cannot be unambiguously inferred,
	such as when overloading based on string type. The types corresponding
	to the postfix characters are:
	<p>

	$(TABLE1
	$(TR
	$(TH Postfix)
	$(TH Type)
	)
	$(TR
	$(TD $(B c))
	$(TD char[ ])
	)
	$(TR
	$(TD $(B w))
	$(TD wchar[ ])
	)
	$(TR
	$(TD $(B d))
	$(TD dchar[ ])
	)
	)

---
"hello"c          // char[]
"hello"w          // wchar[]
"hello"d          // dchar[]
---

	$(P String literals are read only. Writes to string literals
	cannot always be detected, but cause undefined behavior.)

$(V2
<h4>Delimited Strings</h4>

	$(P Delimited strings use various forms of delimiters.
	A $(I nesting delimiter) nests, and is one of the
	following characters:
	)

	$(TABLE1
	<caption>Nesting Delimiters</caption>
	$(TR
	$(TH Delimiter)
	$(TH Matching Delimiter)
	)
	$(TR
	$(TD [)
	$(TD ])
	)
	$(TR
	$(TD $(LPAREN))
	$(TD $(RPAREN))
	)
	$(TR
	$(TD &lt;)
	$(TD &gt;)
	)
	$(TR
	$(TD {)
	$(TD })
	)
	)

---
q"(foo(xxx))"   // "foo(xxx)"
q"[foo{]"       // "foo{"
---

	$(P If the delimiter is an identifier, the identifier must
	be immediately followed by a newline, and the matching
	delimiter is the same identifier starting at the beginning
	of the line:
	)
---
writefln(q"EOS
This
is a multi-line
heredoc string
EOS"
);
---
	$(P The newline following the opening identifier is not part
	of the string, but the last newline before the closing
	identifier is part of the string.
	)

	$(P Otherwise, the matching delimiter is the same as
	the delimiter character:)

---
q"/foo]/"       // "foo]"
q"/abc/def/"    // error
---

<h4>Token Strings</h4>

	$(P Token strings open with the characters $(B q{) and close with
	the token $(B }). In between must be valid D tokens.
	The $(B {) and $(B }) tokens nest.
	The string is formed of all the characters between the opening
	and closing of the token string, including comments.
	)

---
q{foo}               // "foo"
q{/*}*/ }            // "/*}*/ "
q{ foo(q{hello}); }  // " foo(q{hello}); "
q{ @ }               // error, @ is not a valid D token
q{ __TIME__ }        // " __TIME__ ", i.e. it is not replaced with the time
q{ __EOF__ }         // error, as __EOF__ is not a token, it's end of file
---

)

<h3>$(LNAME2 characterliteral, Character Literals)</h3>

$(GRAMMAR
$(I CharacterLiteral):
	$(B ') $(I SingleQuotedCharacter) $(B ')

$(I SingleQuotedCharacter):
	$(I Character)
	$(I EscapeSequence)
)

	Character literals are a single character or escape sequence
	enclosed by single quotes, ' '.

<h3>$(LNAME2 integerliteral, Integer Literals)</h3>

$(GRAMMAR
$(I IntegerLiteral):
	$(I Integer)
	$(I Integer) $(I IntegerSuffix)

$(I Integer):
	$(I Decimal)
	$(I Binary)
	$(I Octal)
	$(I Hexadecimal)

$(I IntegerSuffix):
	$(B L)
	$(B u)
	$(B U)
	$(B Lu)
	$(B LU)
	$(B uL)
	$(B UL)

$(I Decimal):
	$(B 0)
	$(I NonZeroDigit)
	$(I NonZeroDigit) $(I DecimalDigits)

$(I Binary):
	$(B 0b) $(I BinaryDigits)
	$(B 0B) $(I BinaryDigits)

$(I Octal):
	$(B 0) $(I OctalDigits)

$(I Hexadecimal):
	$(B 0x) $(I HexDigits)
	$(B 0X) $(I HexDigits)

$(I NonZeroDigit):
	$(B 1)
	$(B 2)
	$(B 3)
	$(B 4)
	$(B 5)
	$(B 6)
	$(B 7)
	$(B 8)
	$(B 9)

$(I DecimalDigits):
	$(I DecimalDigit)
	$(I DecimalDigit) $(I DecimalDigits)

$(I DecimalDigit):
	$(B 0)
	$(I NonZeroDigit)
	$(B _)

$(I BinaryDigits):
	$(I BinaryDigit)
	$(I BinaryDigit) $(I BinaryDigits)

$(I BinaryDigit):
	$(B 0)
	$(B 1)
	$(B _)

$(I OctalDigits):
	$(I OctalDigit)
	$(I OctalDigit) $(I OctalDigits)

$(I OctalDigit):
	$(B 0)
	$(B 1)
	$(B 2)
	$(B 3)
	$(B 4)
	$(B 5)
	$(B 6)
	$(B 7)
	$(B _)

$(I HexDigits):
	$(I HexDigit)
	$(I HexDigit) $(I HexDigits)

$(I HexDigit):
	$(I DecimalDigit)
	$(B a)
	$(B b)
	$(B c)
	$(B d)
	$(B e)
	$(B f)
	$(B A)
	$(B B)
	$(B C)
	$(B D)
	$(B E)
	$(B F)
	$(B _)
)

	Integers can be specified in decimal, binary, octal, or hexadecimal.
<p>
	Decimal integers are a sequence of decimal digits.
<p>
	Binary integers are a sequence of binary digits preceded
	by a '0b'.
<p>
	Octal integers are a sequence of octal digits preceded by a '0'.
<p>
	Hexadecimal integers are a sequence of hexadecimal digits preceded
	by a '0x'.
<p>
	Integers can have embedded '_' characters, which are ignored.
	The embedded '_' are useful for formatting long literals, such
	as using them as a thousands separator:

-------------
123_456		// 123456
1_2_3_4_5_6_	// 123456
-------------

	Integers can be immediately followed by one 'L' or one 'u' or both.
<p>
	The type of the integer is resolved as follows:
	<p>

	$(TABLE1
	$(TR
	$(TH Decimal Literal)
	$(TH Type)
	)
	$(TR
	$(TD 0 .. 2_147_483_647)
	$(TD int)
	)
	$(TR
	$(TD 2_147_483_648 .. 9_223_372_036_854_775_807L)
	$(TD long)
	)
	$(TR
	$(TH Decimal Literal, L Suffix)
	$(TH Type)
	)
	$(TR
	$(TD 0L .. 9_223_372_036_854_775_807L)
	$(TD long)
	)
	$(TR
	$(TH Decimal Literal, U Suffix)
	$(TH Type)
	)
	$(TR
	$(TD 0U .. 4_294_967_296U)
	$(TD uint)
	)
	$(TR
	$(TD 4_294_967_296U .. 18_446_744_073_709_551_615UL)
	$(TD ulong)
	)
	$(TR
	$(TH Decimal Literal, UL Suffix)
	$(TH Type)
	)
	$(TR
	$(TD 0UL .. 18_446_744_073_709_551_615UL)
	$(TD ulong)
	)

	$(TR
	$(TH Non-Decimal Literal)
	$(TH Type)
	)
	$(TR
	$(TD 0x0 .. 0x7FFF_FFFF)
	$(TD int)
	)
	$(TR
	$(TD 0x8000_0000 .. 0xFFFF_FFFF)
	$(TD uint)
	)
	$(TR
	$(TD 0x1_0000_0000 .. 0x7FFF_FFFF_FFFF_FFFF)
	$(TD long)
	)
	$(TR
	$(TD 0x8000_0000_0000_0000 .. 0xFFFF_FFFF_FFFF_FFFF)
	$(TD ulong)
	)
	$(TR
	$(TH Non-Decimal Literal, L Suffix)
	$(TH Type)
	)
	$(TR
	$(TD 0x0L .. 0x7FFF_FFFF_FFFF_FFFFL)
	$(TD long)
	)
	$(TR
	$(TD 0x8000_0000_0000_0000L .. 0xFFFF_FFFF_FFFF_FFFFL)
	$(TD ulong)
	)
	$(TR
	$(TH Non-Decimal Literal, U Suffix)
	$(TH Type)
	)
	$(TR
	$(TD 0x0U .. 0xFFFF_FFFFU)
	$(TD uint)
	)
	$(TR
	$(TD 0x1_0000_0000UL .. 0xFFFF_FFFF_FFFF_FFFFUL)
	$(TD ulong)
	)
	$(TR
	$(TH Non-Decimal Literal, UL Suffix)
	$(TH Type)
	)
	$(TR
	$(TD 0x0UL .. 0xFFFF_FFFF_FFFF_FFFFUL)
	$(TD ulong)
	)

	)


<h3>$(LNAME2 floatliteral, Floating Literals)</h3>

$(GRAMMAR
$(I FloatLiteral):
	$(I Float)
	$(I Float) $(I Suffix)
	$(I Integer) $(I ImaginarySuffix)
	$(I Integer) $(I FloatSuffix) $(I ImaginarySuffix)
	$(I Integer) $(I RealSuffix) $(I ImaginarySuffix)

$(I Float):
	$(I DecimalFloat)
	$(I HexFloat)

$(I DecimalFloat):
	$(I DecimalDigits) $(B .)
	$(I DecimalDigits) $(B .) $(I DecimalDigits)
	$(I DecimalDigits) $(B .) $(I DecimalDigits) $(I DecimalExponent)
	$(B .) $(I Decimal)
	$(B .) $(I Decimal) $(I DecimalExponent)
	$(I DecimalDigits) $(I DecimalExponent)

$(I DecimalExponent)
	$(B e) $(I DecimalDigits)
	$(B E) $(I DecimalDigits)
	$(B e+) $(I DecimalDigits)
	$(B E+) $(I DecimalDigits)
	$(B e-) $(I DecimalDigits)
	$(B E-) $(I DecimalDigits)

$(I HexFloat):
	$(I HexPrefix) $(I HexDigits) $(B .) $(I HexDigits) $(I HexExponent)
	$(I HexPrefix) $(B .) $(I HexDigits) $(I HexExponent)
	$(I HexPrefix) $(I HexDigits) $(I HexExponent)

$(I HexPrefix):
	$(B 0x)
	$(B 0X)

$(I HexExponent):
	$(B p) $(I DecimalDigits)
	$(B P) $(I DecimalDigits)
	$(B p+) $(I DecimalDigits)
	$(B P+) $(I DecimalDigits)
	$(B p-) $(I DecimalDigits)
	$(B P-) $(I DecimalDigits)

$(I Suffix):
	$(I FloatSuffix)
	$(I RealSuffix)
	$(I ImaginarySuffix)
	$(I FloatSuffix) $(I ImaginarySuffix)
	$(I RealSuffix) $(I ImaginarySuffix)

$(I FloatSuffix):
	$(B f)
	$(B F)

$(I RealSuffix):
	$(B L)

$(I ImaginarySuffix):
	$(B i)
)

	Floats can be in decimal or hexadecimal format,
	as in standard C.
	<p>

	Hexadecimal floats are preceded with a $(B 0x) and the
	exponent is a $(B p)
	or $(B P) followed by a decimal number serving as the exponent
	of 2.
	<p>

	Floating literals can have embedded '_' characters, which are ignored.
	The embedded '_' are useful for formatting long literals to
	make them more readable, such
	as using them as a thousands separator:

---------
123_456.567_8		// 123456.5678
1_2_3_4_5_6_._5_6_7_8	// 123456.5678
1_2_3_4_5_6_._5e-6_	// 123456.5e-6
---------

	Floating literals with no suffix are of type double.
	Floats can be followed by one $(B f), $(B F),
	or $(B L) suffix.
	The $(B f) or $(B F) suffix means it is a
	float, and $(B L) means it is a real.
	<p>

	If a floating literal is followed by $(B i), then it is an
	$(I ireal) (imaginary) type.
	<p>

	Examples:

---------
0x1.FFFFFFFFFFFFFp1023		// double.max
0x1p-52				// double.epsilon
1.175494351e-38F		// float.min
6.3i				// idouble 6.3
6.3fi				// ifloat 6.3
6.3Li				// ireal 6.3
---------

	It is an error if the literal exceeds the range of the type.
	It is not an error if the literal is rounded to fit into
	the significant digits of the type.
	<p>

	Complex literals are not tokens, but are assembled from
	real and imaginary expressions in the semantic analysis:

---------
4.5 + 6.2i		// complex number
---------

<h3>$(LNAME2 keyword, Keywords)</h3>

	Keywords are reserved identifiers.

$(GRAMMAR
$(I Keyword):
	$(B abstract)
	$(B alias)
	$(B align)
	$(B asm)
	$(B assert)
	$(B auto)

	$(B body)
	$(B bool)
	$(B break)
	$(B byte)

	$(B case)
	$(B cast)
	$(B catch)
	$(B cdouble)
	$(B cent)
	$(B cfloat)
	$(B char)
	$(B class)
	$(B const)
	$(B continue)
	$(B creal)

	$(B dchar)
	$(B debug)
	$(B default)
	$(B delegate)
	$(B delete)
	$(B deprecated)
	$(B do)
	$(B double)

	$(B else)
	$(B enum)
	$(B export)
	$(B extern)

	$(B false)
	$(B final)
	$(B finally)
	$(B float)
	$(B for)
	$(B foreach)
	$(B foreach_reverse)
	$(B function)

	$(B goto)

	$(B idouble)
	$(B if)
	$(B ifloat)
	$(B import)
	$(B in)
	$(B inout)
	$(B int)
	$(B interface)
	$(B invariant)
	$(B ireal)
	$(B is)

	$(B lazy)
	$(B long)

	$(B macro)
	$(B mixin)
	$(B module)

	$(B new)
	$(B null)

	$(B out)
	$(B override)

	$(B package)
	$(B pragma)
	$(B private)
	$(B protected)
	$(B public)

	$(B real)
	$(B ref)
	$(B return)

	$(B scope)
	$(B short)
	$(B static)
	$(B struct)
	$(B super)
	$(B switch)
	$(B synchronized)

	$(B template)
	$(B this)
	$(B throw)
	$(B __traits)
	$(B true)
	$(B try)
	$(B typedef)
	$(B typeid)
	$(B typeof)

	$(B ubyte)
	$(B ucent)
	$(B uint)
	$(B ulong)
	$(B union)
	$(B unittest)
	$(B ushort)

	$(B version)
	$(B void)
	$(B volatile)

	$(B wchar)
	$(B while)
	$(B with)
)

<h3>$(LNAME2 specialtokens, Special Tokens)</h3>

	$(P
	These tokens are replaced with other tokens according to the following
	table:
	)

	$(TABLE1
	$(TR
	$(TH Special Token)
	$(TH Replaced with...)
	)
	$(TR
	$(TD $(B __FILE__))
	$(TD string literal containing source file name)
	)
	$(TR
	$(TD $(B __LINE__))
	$(TD integer literal of the current source line number)
	)
	$(TR
	$(TD $(B __DATE__))
	$(TD string literal of the date of compilation "$(I mmm dd yyyy)")
	)
	$(TR
	$(TD $(B __TIME__))
	$(TD string literal of the time of compilation "$(I hh:mm:ss)")
	)
	$(TR
	$(TD $(B __TIMESTAMP__))
	$(TD string literal of the date and time of compilation "$(I www mmm dd hh:mm:ss yyyy)")
	)
	$(TR
	$(TD $(B __VENDOR__))
	$(TD Compiler vendor string, such as "Digital Mars D")
	)
	$(TR
	$(TD $(B __VERSION__))
	$(TD Compiler version as an integer, such as 2001)
	)
	)

<h3>$(LNAME2 specialtokenseq, Special Token Sequences)</h3>

	Special token sequences are processed by the lexical analyzer, may
	appear between any other tokens, and do not affect the syntax
	parsing.
	<p>

	There is currently only one special token sequence, $(TT #line).

$(GRAMMAR
$(I SpecialTokenSequence):
	$(B # line) $(I Integer) $(I EndOfLine)
	$(B # line) $(I Integer) $(I Filespec) $(I EndOfLine)

$(I Filespec):
	$(B ") $(I Characters) $(B ")
)

	This sets the source line number to $(I Integer),
	and optionally the source file 	name to $(I Filespec),
	beginning with the next line of source text.
	The source file and line number is used for printing error messages
	and for mapping generated code back to the source for the symbolic
	debugging output.
	<p>

	For example:

-----------------
int #line 6 "foo\bar"
x;			// this is now line 6 of file foo\bar
-----------------

	Note that the backslash character is not treated specially inside
	$(I Filespec) strings.

)

Macros:
	TITLE=Lexical
	WIKI=Lex

