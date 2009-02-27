
// Written in the D programming language.

/**
 * This module implements the workhorse functionality for string and
 * I/O formatting.  It's comparable to C99's vsprintf().
 *
 * Macros:
 *	WIKI = Phobos/StdFormat
 */

/*
 *  Copyright (C) 2004-2006 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright and Andrei Alexandrescu
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

module std.format;

//debug=format;		// uncomment to turn on debugging printf's

import std.stdarg;	// caller will need va_list

private import std.utf;
private import std.c.stdio;
private import std.c.stdlib;
private import std.c.string;
private import std.string;
import std.ctype;
import std.conv;
import std.traits;
import std.typetuple;
import std.stdio; // for debugging only
import std.contracts;
import std.system;

version (Windows)
{
    version (DigitalMars)
    {
	version = DigitalMarsC;
    }
}

version (DigitalMarsC)
{
    // This is DMC's internal floating point formatting function
    extern (C)
    {
	extern char* function(int c, int flags, int precision, real* pdval,
	    char* buf, int* psl, int width) __pfloatfmt;
    }
    alias std.c.stdio._snprintf snprintf;
}
else
{
    // Use C99 snprintf
    extern (C) int snprintf(char* s, size_t n, const char* format, ...);
}

/**********************************************************************
 * Signals a mismatch between a format and its corresponding argument.
 */
class FormatError : Error
{
    this()
    {
	super("std.format");
    }

    this(string msg)
    {
	super("std.format " ~ msg);
    }
}


enum Mangle : char
{
    Tvoid     = 'v',
    Tbool     = 'b',
    Tbyte     = 'g',
    Tubyte    = 'h',
    Tshort    = 's',
    Tushort   = 't',
    Tint      = 'i',
    Tuint     = 'k',
    Tlong     = 'l',
    Tulong    = 'm',
    Tfloat    = 'f',
    Tdouble   = 'd',
    Treal     = 'e',

    Tifloat   = 'o',
    Tidouble  = 'p',
    Tireal    = 'j',
    Tcfloat   = 'q',
    Tcdouble  = 'r',
    Tcreal    = 'c',

    Tchar     = 'a',
    Twchar    = 'u',
    Tdchar    = 'w',

    Tarray    = 'A',
    Tsarray   = 'G',
    Taarray   = 'H',
    Tpointer  = 'P',
    Tfunction = 'F',
    Tident    = 'I',
    Tclass    = 'C',
    Tstruct   = 'S',
    Tenum     = 'E',
    Ttypedef  = 'T',
    Tdelegate = 'D',

    Tconst    = 'x',
    Tinvariant = 'y',
}

// return the TypeInfo for a primitive type and null otherwise.
// This is required since for arrays of ints we only have the mangled
// char to work from. If arrays always subclassed TypeInfo_Array this
// routine could go away.
private TypeInfo primitiveTypeInfo(Mangle m) 
{
  TypeInfo ti;

  switch (m)
    {
    case Mangle.Tvoid:
      ti = typeid(void);break;
    case Mangle.Tbool:
      ti = typeid(bool);break;
    case Mangle.Tbyte:
      ti = typeid(byte);break;
    case Mangle.Tubyte:
      ti = typeid(ubyte);break;
    case Mangle.Tshort:
      ti = typeid(short);break;
    case Mangle.Tushort:
      ti = typeid(ushort);break;
    case Mangle.Tint:
      ti = typeid(int);break;
    case Mangle.Tuint:
      ti = typeid(uint);break;
    case Mangle.Tlong:
      ti = typeid(long);break;
    case Mangle.Tulong:
      ti = typeid(ulong);break;
    case Mangle.Tfloat:
      ti = typeid(float);break;
    case Mangle.Tdouble:
      ti = typeid(double);break;
    case Mangle.Treal:
      ti = typeid(real);break;
    case Mangle.Tifloat:
      ti = typeid(ifloat);break;
    case Mangle.Tidouble:
      ti = typeid(idouble);break;
    case Mangle.Tireal:
      ti = typeid(ireal);break;
    case Mangle.Tcfloat:
      ti = typeid(cfloat);break;
    case Mangle.Tcdouble:
      ti = typeid(cdouble);break;
    case Mangle.Tcreal:
      ti = typeid(creal);break;
    case Mangle.Tchar:
      ti = typeid(char);break;
    case Mangle.Twchar:
      ti = typeid(wchar);break;
    case Mangle.Tdchar:
      ti = typeid(dchar);
    default:
      ti = null;
    }
  return ti;
}

/************************************
 * Interprets variadic argument list pointed to by argptr whose types are given
 * by arguments[], formats them according to embedded format strings in the
 * variadic argument list, and sends the resulting characters to putc.
 *
 * The variadic arguments are consumed in order.
 * Each is formatted into a sequence of chars, using the default format
 * specification for its type, and the
 * characters are sequentially passed to putc.
 * If a char[], wchar[], or dchar[]
 * argument is encountered, it is interpreted as a format string. As many
 * arguments as specified in the format string are consumed and formatted
 * according to the format specifications in that string and passed to putc. If
 * there are too few remaining arguments, a FormatError is thrown. If there are
 * more remaining arguments than needed by the format specification, the default
 * processing of arguments resumes until they are all consumed.
 *
 * Params:
 *	putc =	Output is sent do this delegate, character by character.
 *	arguments = Array of TypeInfo's, one for each argument to be formatted.
 *	argptr = Points to variadic argument list.
 *
 * Throws:
 *	Mismatched arguments and formats result in a FormatError being thrown.
 *
 * Format_String:
 *	<a name="format-string">$(I Format strings)</a>
 *	consist of characters interspersed with
 *	$(I format specifications). Characters are simply copied
 *	to the output (such as putc) after any necessary conversion
 *	to the corresponding UTF-8 sequence.
 *
 *	A $(I format specification) starts with a '%' character,
 *	and has the following grammar:

<pre>
$(I FormatSpecification):
    $(B '%%')
    $(B '%') $(I Flags) $(I Width) $(I Precision) $(I FormatChar)

$(I Flags):
    $(I empty)
    $(B '-') $(I Flags)
    $(B '+') $(I Flags)
    $(B '#') $(I Flags)
    $(B '0') $(I Flags)
    $(B ' ') $(I Flags)

$(I Width):
    $(I empty)
    $(I Integer)
    $(B '*')

$(I Precision):
    $(I empty)
    $(B '.')
    $(B '.') $(I Integer)
    $(B '.*')

$(I Integer):
    $(I Digit)
    $(I Digit) $(I Integer)

$(I Digit):
    $(B '0')
    $(B '1')
    $(B '2')
    $(B '3')
    $(B '4')
    $(B '5')
    $(B '6')
    $(B '7')
    $(B '8')
    $(B '9')

$(I FormatChar):
    $(B 's')
    $(B 'b')
    $(B 'd')
    $(B 'o')
    $(B 'x')
    $(B 'X')
    $(B 'e')
    $(B 'E')
    $(B 'f')
    $(B 'F')
    $(B 'g')
    $(B 'G')
    $(B 'a')
    $(B 'A')
</pre>
    <dl>
    <dt>$(I Flags)
    <dl>
	<dt>$(B '-')
	<dd>
	Left justify the result in the field.
	It overrides any $(B 0) flag.

	<dt>$(B '+')
	<dd>Prefix positive numbers in a signed conversion with a $(B +).
	It overrides any $(I space) flag.

	<dt>$(B '#')
	<dd>Use alternative formatting:
	<dl>
	    <dt>For $(B 'o'):
	    <dd> Add to precision as necessary so that the first digit
	    of the octal formatting is a '0', even if both the argument
	    and the $(I Precision) are zero.
	    <dt> For $(B 'x') ($(B 'X')):
	    <dd> If non-zero, prefix result with $(B 0x) ($(B 0X)).
	    <dt> For floating point formatting:
	    <dd> Always insert the decimal point.
	    <dt> For $(B 'g') ($(B 'G')):
	    <dd> Do not elide trailing zeros.
	</dl>

	<dt>$(B '0')
	<dd> For integer and floating point formatting when not nan or
	infinity, use leading zeros
	to pad rather than spaces.
	Ignore if there's a $(I Precision).

	<dt>$(B ' ')
	<dd>Prefix positive numbers in a signed conversion with a space.
    </dl>

    <dt>$(I Width)
    <dd>
    Specifies the minimum field width.
    If the width is a $(B *), the next argument, which must be
    of type $(B int), is taken as the width.
    If the width is negative, it is as if the $(B -) was given
    as a $(I Flags) character.

    <dt>$(I Precision)
    <dd> Gives the precision for numeric conversions.
    If the precision is a $(B *), the next argument, which must be
    of type $(B int), is taken as the precision. If it is negative,
    it is as if there was no $(I Precision).

    <dt>$(I FormatChar)
    <dd>
    <dl>
	<dt>$(B 's')
	<dd>The corresponding argument is formatted in a manner consistent
	with its type:
	<dl>
	    <dt>$(B bool)
	    <dd>The result is <tt>'true'</tt> or <tt>'false'</tt>.
	    <dt>integral types
	    <dd>The $(B %d) format is used.
	    <dt>floating point types
	    <dd>The $(B %g) format is used.
	    <dt>string types
	    <dd>The result is the string converted to UTF-8.
	    A $(I Precision) specifies the maximum number of characters
	    to use in the result.
	    <dt>classes derived from $(B Object)
	    <dd>The result is the string returned from the class instance's
	    $(B .toString()) method.
	    A $(I Precision) specifies the maximum number of characters
	    to use in the result.
	    <dt>non-string static and dynamic arrays
	    <dd>The result is [s<sub>0</sub>, s<sub>1</sub>, ...]
	    where s<sub>k</sub> is the kth element 
	    formatted with the default format.
	</dl>

	<dt>$(B 'b','d','o','x','X')
	<dd> The corresponding argument must be an integral type
	and is formatted as an integer. If the argument is a signed type
	and the $(I FormatChar) is $(B d) it is converted to
	a signed string of characters, otherwise it is treated as
	unsigned. An argument of type $(B bool) is formatted as '1'
	or '0'. The base used is binary for $(B b), octal for $(B o),
	decimal
	for $(B d), and hexadecimal for $(B x) or $(B X).
	$(B x) formats using lower case letters, $(B X) uppercase.
	If there are fewer resulting digits than the $(I Precision),
	leading zeros are used as necessary.
	If the $(I Precision) is 0 and the number is 0, no digits
	result.

	<dt>$(B 'e','E')
	<dd> A floating point number is formatted as one digit before
	the decimal point, $(I Precision) digits after, the $(I FormatChar),
	&plusmn;, followed by at least a two digit exponent: $(I d.dddddd)e$(I &plusmn;dd).
	If there is no $(I Precision), six
	digits are generated after the decimal point.
	If the $(I Precision) is 0, no decimal point is generated.

	<dt>$(B 'f','F')
	<dd> A floating point number is formatted in decimal notation.
	The $(I Precision) specifies the number of digits generated
	after the decimal point. It defaults to six. At least one digit
	is generated before the decimal point. If the $(I Precision)
	is zero, no decimal point is generated.

	<dt>$(B 'g','G')
	<dd> A floating point number is formatted in either $(B e) or
	$(B f) format for $(B g); $(B E) or $(B F) format for
	$(B G).
	The $(B f) format is used if the exponent for an $(B e) format
	is greater than -5 and less than the $(I Precision).
	The $(I Precision) specifies the number of significant
	digits, and defaults to six.
	Trailing zeros are elided after the decimal point, if the fractional
	part is zero then no decimal point is generated.

	<dt>$(B 'a','A')
	<dd> A floating point number is formatted in hexadecimal
	exponential notation 0x$(I h.hhhhhh)p$(I &plusmn;d).
	There is one hexadecimal digit before the decimal point, and as
	many after as specified by the $(I Precision).
	If the $(I Precision) is zero, no decimal point is generated.
	If there is no $(I Precision), as many hexadecimal digits as
	necessary to exactly represent the mantissa are generated.
	The exponent is written in as few digits as possible,
	but at least one, is in decimal, and represents a power of 2 as in
	$(I h.hhhhhh)*2<sup>$(I &plusmn;d)</sup>.
	The exponent for zero is zero.
	The hexadecimal digits, x and p are in upper case if the
	$(I FormatChar) is upper case.
    </dl>

    Floating point NaN's are formatted as $(B nan) if the
    $(I FormatChar) is lower case, or $(B NAN) if upper.
    Floating point infinities are formatted as $(B inf) or
    $(B infinity) if the
    $(I FormatChar) is lower case, or $(B INF) or $(B INFINITY) if upper.
    </dl>

Example:

-------------------------
import std.c.stdio;
import std.format;

void myPrint(...)
{
    void putc(char c)
    {
	fputc(c, stdout);
    }

    std.format.doFormat(&putc, _arguments, _argptr);
}

...

int x = 27;
// prints 'The answer is 27:6'
myPrint("The answer is %s:", x, 6);
------------------------
 */

void doFormat(void delegate(dchar) putc, TypeInfo[] arguments, va_list argptr)
{   int j;
    TypeInfo ti;
    Mangle m;
    uint flags;
    int field_width;
    int precision;

    enum : uint
    {
	FLdash = 1,
	FLplus = 2,
	FLspace = 4,
	FLhash = 8,
	FLlngdbl = 0x20,
	FL0pad = 0x40,
	FLprecision = 0x80,
    }

    static TypeInfo skipCI(TypeInfo valti)
    {
      while (1)
      {
	if (valti.classinfo.name.length == 18 &&
	    valti.classinfo.name[9..18] == "Invariant")
	    valti =	(cast(TypeInfo_Invariant)valti).next;
	else if (valti.classinfo.name.length == 14 &&
	    valti.classinfo.name[9..14] == "Const")
	    valti =	(cast(TypeInfo_Const)valti).next;
	else
	    break;
      }
      return valti;
    }

    void formatArg(char fc)
    {
	bool vbit;
	ulong vnumber;
	char vchar;
	dchar vdchar;
	Object vobject;
	real vreal;
	creal vcreal;
	Mangle m2;
	int signed = 0;
	uint base = 10;
	int uc;
	char[ulong.sizeof * 8] tmpbuf;	// long enough to print long in binary
	const(char)* prefix = "";
	string s;

	void putstr(const char[] s)
	{
	    //printf("flags = x%x\n", flags);
	    int prepad = 0;
	    int postpad = 0;
	    int padding = field_width - (strlen(prefix) + toUCSindex(s, s.length));
	    if (padding > 0)
	    {
		if (flags & FLdash)
		    postpad = padding;
		else
		    prepad = padding;
	    }

	    if (flags & FL0pad)
	    {
		while (*prefix)
		    putc(*prefix++);
		while (prepad--)
		    putc('0');
	    }
	    else
	    {
		while (prepad--)
		    putc(' ');
		while (*prefix)
		    putc(*prefix++);
	    }

	    foreach (dchar c; s)
		putc(c);

	    while (postpad--)
		putc(' ');
	}

	void putreal(real v)
	{
	    //printf("putreal %Lg\n", vreal);

	    switch (fc)
	    {
		case 's':
		    fc = 'g';
		    break;

		case 'f', 'F', 'e', 'E', 'g', 'G', 'a', 'A':
		    break;

		default:
		    //printf("fc = '%c'\n", fc);
		Lerror:
		    throw new FormatError("floating");
	    }
	    version (DigitalMarsC)
	    {
		int sl;
		char[] fbuf = tmpbuf;
		if (!(flags & FLprecision))
		    precision = 6;
		while (1)
		{
		    sl = fbuf.length;
		    prefix = (*__pfloatfmt)(fc, flags | FLlngdbl,
			    precision, &v, cast(char*)fbuf, &sl, field_width);
		    if (sl != -1)
			break;
		    sl = fbuf.length * 2;
		    fbuf = (cast(char*)alloca(sl * char.sizeof))[0 .. sl];
		}
		putstr(fbuf[0 .. sl]);
	    }
	    else
	    {
		int sl;
		char[] fbuf = tmpbuf;
		char[12] format;
		format[0] = '%';
		int i = 1;
		if (flags & FLdash)
		    format[i++] = '-';
		if (flags & FLplus)
		    format[i++] = '+';
		if (flags & FLspace)
		    format[i++] = ' ';
		if (flags & FLhash)
		    format[i++] = '#';
		if (flags & FL0pad)
		    format[i++] = '0';
		format[i + 0] = '*';
		format[i + 1] = '.';
		format[i + 2] = '*';
		format[i + 3] = 'L';
		format[i + 4] = fc;
		format[i + 5] = 0;
		if (!(flags & FLprecision))
		    precision = -1;
		while (1)
		{   int n;

		    sl = fbuf.length;
		    n = snprintf(fbuf.ptr, sl, format.ptr, field_width, precision, v);
		    //printf("format = '%s', n = %d\n", cast(char*)format, n);
		    if (n >= 0 && n < sl)
		    {	sl = n;
			break;
		    }
		    if (n < 0)
			sl = sl * 2;
		    else
			sl = n + 1;
		    fbuf = (cast(char*)alloca(sl * char.sizeof))[0 .. sl];
		}
		putstr(fbuf[0 .. sl]);
	    }
	    return;
	}

	static Mangle getMan(TypeInfo ti)
	{
	  auto m = cast(Mangle)ti.classinfo.name[9];
	  if (ti.classinfo.name.length == 20 &&
	      ti.classinfo.name[9..20] == "StaticArray")
		m = cast(Mangle)'G';
	  return m;
	}

	void putArray(void* p, size_t len, TypeInfo valti)
	{
	  //printf("\nputArray(len = %u), tsize = %u\n", len, valti.tsize());
	  putc('[');
	  valti = skipCI(valti);
	  size_t tsize = valti.tsize();
	  auto argptrSave = argptr;
	  auto tiSave = ti;
	  auto mSave = m;
	  ti = valti;
	  //printf("\n%.*s\n", valti.classinfo.name);
	  m = getMan(valti);
	  while (len--)
	  {
	    //doFormat(putc, (&valti)[0 .. 1], p);
	    argptr = p;
	    formatArg('s');

	    p += tsize;
	    if (len > 0) putc(',');
	  }
	  m = mSave;
	  ti = tiSave;
	  argptr = argptrSave;
	  putc(']');
	}

	void putAArray(ubyte[long] vaa, TypeInfo valti, TypeInfo keyti)
	{
	  putc('[');
	  bool comma=false;
	  auto argptrSave = argptr;
	  auto tiSave = ti;
	  auto mSave = m;
	  valti = skipCI(valti);
	  keyti = skipCI(keyti);
	  foreach(inout fakevalue; vaa)
	  {
	    if (comma) putc(',');
	    comma = true;
	    // the key comes before the value
	    ubyte* key = &fakevalue - long.sizeof;

	    //doFormat(putc, (&keyti)[0..1], key);
	    argptr = key;
	    ti = keyti;
	    m = getMan(keyti);
	    formatArg('s');

	    putc(':');
	    auto keysize = keyti.tsize;
	    keysize = (keysize + 3) & ~3;
	    ubyte* value = key + keysize;
	    //doFormat(putc, (&valti)[0..1], value);
	    argptr = value;
	    ti = valti;
	    m = getMan(valti);
	    formatArg('s');
	  }
	  m = mSave;
	  ti = tiSave;
	  argptr = argptrSave;
	  putc(']');
	}

	//printf("formatArg(fc = '%c', m = '%c')\n", fc, m);
	switch (m)
	{
	    case Mangle.Tbool:
		vbit = va_arg!(bool)(argptr);
		if (fc != 's')
		{   vnumber = vbit;
		    goto Lnumber;
		}
		putstr(vbit ? "true" : "false");
		return;


	    case Mangle.Tchar:
		vchar = va_arg!(char)(argptr);
		if (fc != 's')
		{   vnumber = vchar;
		    goto Lnumber;
		}
	    L2:
		putstr((&vchar)[0 .. 1]);
		return;

	    case Mangle.Twchar:
		vdchar = va_arg!(wchar)(argptr);
		goto L1;

	    case Mangle.Tdchar:
		vdchar = va_arg!(dchar)(argptr);
	    L1:
		if (fc != 's')
		{   vnumber = vdchar;
		    goto Lnumber;
		}
		if (vdchar <= 0x7F)
		{   vchar = cast(char)vdchar;
		    goto L2;
		}
		else
		{   if (!isValidDchar(vdchar))
			throw new UtfException("invalid dchar in format", 0);
		    char[4] vbuf;
		    putstr(toUTF8(vbuf, vdchar));
		}
		return;


	    case Mangle.Tbyte:
		signed = 1;
		vnumber = va_arg!(byte)(argptr);
		goto Lnumber;

	    case Mangle.Tubyte:
		vnumber = va_arg!(ubyte)(argptr);
		goto Lnumber;

	    case Mangle.Tshort:
		signed = 1;
		vnumber = va_arg!(short)(argptr);
		goto Lnumber;

	    case Mangle.Tushort:
		vnumber = va_arg!(ushort)(argptr);
		goto Lnumber;

	    case Mangle.Tint:
		signed = 1;
		vnumber = va_arg!(int)(argptr);
		goto Lnumber;

	    case Mangle.Tuint:
	    Luint:
		vnumber = va_arg!(uint)(argptr);
		goto Lnumber;

	    case Mangle.Tlong:
		signed = 1;
		vnumber = cast(ulong)va_arg!(long)(argptr);
		goto Lnumber;

	    case Mangle.Tulong:
	    Lulong:
		vnumber = va_arg!(ulong)(argptr);
		goto Lnumber;

	    case Mangle.Tclass:
		vobject = va_arg!(Object)(argptr);
		if (vobject is null)
		    s = "null";
		else
		    s = vobject.toString();
		goto Lputstr;

	    case Mangle.Tpointer:
		vnumber = cast(ulong)va_arg!(void*)(argptr);
		uc = 1;
		flags |= FL0pad;
		if (!(flags & FLprecision))
		{   flags |= FLprecision;
		    precision = (void*).sizeof;
		}
		base = 16;
		goto Lnumber;


	    case Mangle.Tfloat:
	    case Mangle.Tifloat:
		if (fc == 'x' || fc == 'X')
		    goto Luint;
		vreal = va_arg!(float)(argptr);
		goto Lreal;

	    case Mangle.Tdouble:
	    case Mangle.Tidouble:
		if (fc == 'x' || fc == 'X')
		    goto Lulong;
		vreal = va_arg!(double)(argptr);
		goto Lreal;

	    case Mangle.Treal:
	    case Mangle.Tireal:
		vreal = va_arg!(real)(argptr);
		goto Lreal;


	    case Mangle.Tcfloat:
		vcreal = va_arg!(cfloat)(argptr);
		goto Lcomplex;

	    case Mangle.Tcdouble:
		vcreal = va_arg!(cdouble)(argptr);
		goto Lcomplex;

	    case Mangle.Tcreal:
		vcreal = va_arg!(creal)(argptr);
		goto Lcomplex;

	    case Mangle.Tsarray:
		putArray(argptr, (cast(TypeInfo_StaticArray)ti).len, (cast(TypeInfo_StaticArray)ti).next);
		return;

	    case Mangle.Tarray:
		int mi = 10;
	        if (ti.classinfo.name.length == 14 &&
		    ti.classinfo.name[9..14] == "Array") 
		{ // array of non-primitive types
		  TypeInfo tn = (cast(TypeInfo_Array)ti).next;
		  tn = skipCI(tn);
		  switch (cast(Mangle)tn.classinfo.name[9])
		  {
		    case Mangle.Tchar:  goto LarrayChar;
		    case Mangle.Twchar: goto LarrayWchar;
		    case Mangle.Tdchar: goto LarrayDchar;
		    default:
			break;
		  }
		  void[] va = va_arg!(void[])(argptr);
		  putArray(va.ptr, va.length, tn);
		  return;
		}
		if (ti.classinfo.name.length == 25 &&
		    ti.classinfo.name[9..25] == "AssociativeArray") 
		{ // associative array
		  ubyte[long] vaa = va_arg!(ubyte[long])(argptr);
		  putAArray(vaa,
			(cast(TypeInfo_AssociativeArray)ti).next,
			(cast(TypeInfo_AssociativeArray)ti).key);
		  return;
		}

		while (1)
		{
		    m2 = cast(Mangle)ti.classinfo.name[mi];
		    switch (m2)
		    {
			case Mangle.Tchar:
			LarrayChar:
			    s = va_arg!(string)(argptr);
			    goto Lputstr;

			case Mangle.Twchar:
			LarrayWchar:
			    wchar[] sw = va_arg!(wchar[])(argptr);
			    s = toUTF8(sw);
			    goto Lputstr;

			case Mangle.Tdchar:
			LarrayDchar:
			    auto sd = va_arg!(dstring)(argptr);
			    s = toUTF8(sd);
			Lputstr:
			    if (fc != 's')
				throw new FormatError("string");
			    if (flags & FLprecision && precision < s.length)
				s = s[0 .. precision];
			    putstr(s);
			    break;

			case Mangle.Tconst:
			case Mangle.Tinvariant:
			    mi++;
			    continue;

			default:
			    TypeInfo ti2 = primitiveTypeInfo(m2);
			    if (!ti2)
			      goto Lerror;
			    void[] va = va_arg!(void[])(argptr);
			    putArray(va.ptr, va.length, ti2);
		    }
		    return;
		}

	    case Mangle.Ttypedef:
		ti = (cast(TypeInfo_Typedef)ti).base;
		m = cast(Mangle)ti.classinfo.name[9];
		formatArg(fc);
		return;

	    case Mangle.Tenum:
		ti = (cast(TypeInfo_Enum)ti).base;
		m = cast(Mangle)ti.classinfo.name[9];
		formatArg(fc);
		return;

	    case Mangle.Tstruct:
	    {	TypeInfo_Struct tis = cast(TypeInfo_Struct)ti;
		if (tis.xtoString is null)
		    throw new FormatError("Can't convert " ~ tis.toString() ~ " to string: \"string toString()\" not defined");
		s = tis.xtoString(argptr);
		argptr += (tis.tsize() + 3) & ~3;
		goto Lputstr;
	    }

	    default:
		goto Lerror;
	}

    Lnumber:
	switch (fc)
	{
	    case 's':
	    case 'd':
		if (signed)
		{   if (cast(long)vnumber < 0)
		    {	prefix = "-";
			vnumber = -vnumber;
		    }
		    else if (flags & FLplus)
			prefix = "+";
		    else if (flags & FLspace)
			prefix = " ";
		}
		break;

	    case 'b':
		signed = 0;
		base = 2;
		break;

	    case 'o':
		signed = 0;
		base = 8;
		break;

	    case 'X':
		uc = 1;
		if (flags & FLhash && vnumber)
		    prefix = "0X";
		signed = 0;
		base = 16;
		break;

	    case 'x':
		if (flags & FLhash && vnumber)
		    prefix = "0x";
		signed = 0;
		base = 16;
		break;

	    default:
		goto Lerror;
	}

	if (!signed)
	{
	    switch (m)
	    {
		case Mangle.Tbyte:
		    vnumber &= 0xFF;
		    break;

		case Mangle.Tshort:
		    vnumber &= 0xFFFF;
		    break;

		case Mangle.Tint:
		    vnumber &= 0xFFFFFFFF;
		    break;

		default:
		    break;
	    }
	}

	if (flags & FLprecision && fc != 'p')
	    flags &= ~FL0pad;

	if (vnumber < base)
	{
	    if (vnumber == 0 && precision == 0 && flags & FLprecision &&
		!(fc == 'o' && flags & FLhash))
	    {
		putstr(null);
		return;
	    }
	    if (precision == 0 || !(flags & FLprecision))
	    {	vchar = cast(char)('0' + vnumber);
		if (vnumber < 10)
		    vchar = cast(char)('0' + vnumber);
		else
		    vchar = cast(char)((uc ? 'A' - 10 : 'a' - 10) + vnumber);
		goto L2;
	    }
	}

	int n = tmpbuf.length;
	char c;
	int hexoffset = uc ? ('A' - ('9' + 1)) : ('a' - ('9' + 1));

	while (vnumber)
	{
	    c = cast(char)((vnumber % base) + '0');
	    if (c > '9')
		c += hexoffset;
	    vnumber /= base;
	    tmpbuf[--n] = c;
	}
	if (tmpbuf.length - n < precision && precision < tmpbuf.length)
	{
	    int m = tmpbuf.length - precision;
	    tmpbuf[m .. n] = '0';
	    n = m;
	}
	else if (flags & FLhash && fc == 'o')
	    prefix = "0";
	putstr(tmpbuf[n .. tmpbuf.length]);
	return;

    Lreal:
	putreal(vreal);
	return;

    Lcomplex:
	putreal(vcreal.re);
	putc('+');
	putreal(vcreal.im);
	putc('i');
	return;

    Lerror:
	throw new FormatError("formatArg");
    }


    for (j = 0; j < arguments.length; )
    {	ti = arguments[j++];
	//printf("test1: '%.*s' %d\n", ti.classinfo.name, ti.classinfo.name.length);
	//ti.print();

	flags = 0;
	precision = 0;
	field_width = 0;

	ti = skipCI(ti);
	int mi = 9;
	do
	{
	    if (ti.classinfo.name.length <= mi)
		goto Lerror;
	    m = cast(Mangle)ti.classinfo.name[mi++];
	} while (m == Mangle.Tconst || m == Mangle.Tinvariant);

	if (m == Mangle.Tarray)
	{
	    if (ti.classinfo.name.length == 14 &&
		ti.classinfo.name[9..14] == "Array") 
	    {
	      TypeInfo tn = (cast(TypeInfo_Array)ti).next;
	      tn = skipCI(tn);
	      switch (cast(Mangle)tn.classinfo.name[9])
	      {
		case Mangle.Tchar:
		case Mangle.Twchar:
		case Mangle.Tdchar:
		    ti = tn;
		    mi = 9;
		    break;
		default:
		    break;
	      }
	    }
	L1:
	    Mangle m2 = cast(Mangle)ti.classinfo.name[mi];
	    string  fmt;			// format string
	    wstring wfmt;
	    dstring dfmt;

	    /* For performance reasons, this code takes advantage of the
	     * fact that most format strings will be ASCII, and that the
	     * format specifiers are always ASCII. This means we only need
	     * to deal with UTF in a couple of isolated spots.
	     */

	    switch (m2)
	    {
		case Mangle.Tchar:
		    fmt = va_arg!(string)(argptr);
		    break;

		case Mangle.Twchar:
		    wfmt = va_arg!(wstring)(argptr);
		    fmt = toUTF8(wfmt);
		    break;

		case Mangle.Tdchar:
		    dfmt = va_arg!(dstring)(argptr);
		    fmt = toUTF8(dfmt);
		    break;

		case Mangle.Tconst:
		case Mangle.Tinvariant:
		    mi++;
		    goto L1;

		default:
		    formatArg('s');
		    continue;
	    }

	    for (size_t i = 0; i < fmt.length; )
	    {	dchar c = fmt[i++];

		dchar getFmtChar()
		{   // Valid format specifier characters will never be UTF
		    if (i == fmt.length)
			throw new FormatError("invalid specifier");
		    return fmt[i++];
		}

		int getFmtInt()
		{   int n;

		    while (1)
		    {
			n = n * 10 + (c - '0');
			if (n < 0)	// overflow
			    throw new FormatError("int overflow");
			c = getFmtChar();
			if (c < '0' || c > '9')
			    break;
		    }
		    return n;
		}

		int getFmtStar()
		{   Mangle m;
		    TypeInfo ti;

		    if (j == arguments.length)
			throw new FormatError("too few arguments");
		    ti = arguments[j++];
		    m = cast(Mangle)ti.classinfo.name[9];
		    if (m != Mangle.Tint)
			throw new FormatError("int argument expected");
		    return va_arg!(int)(argptr);
		}

		if (c != '%')
		{
		    if (c > 0x7F)	// if UTF sequence
		    {
			i--;		// back up and decode UTF sequence
			c = std.utf.decode(fmt, i);
		    }
		Lputc:
		    putc(c);
		    continue;
		}

		// Get flags {-+ #}
		flags = 0;
		while (1)
		{
		    c = getFmtChar();
		    switch (c)
		    {
			case '-':	flags |= FLdash;	continue;
			case '+':	flags |= FLplus;	continue;
			case ' ':	flags |= FLspace;	continue;
			case '#':	flags |= FLhash;	continue;
			case '0':	flags |= FL0pad;	continue;

			case '%':	if (flags == 0)
					    goto Lputc;
			default:	break;
		    }
		    break;
		}

		// Get field width
		field_width = 0;
		if (c == '*')
		{
		    field_width = getFmtStar();
		    if (field_width < 0)
		    {   flags |= FLdash;
			field_width = -field_width;
		    }

		    c = getFmtChar();
		}
		else if (c >= '0' && c <= '9')
		    field_width = getFmtInt();

		if (flags & FLplus)
		    flags &= ~FLspace;
		if (flags & FLdash)
		    flags &= ~FL0pad;

		// Get precision
		precision = 0;
		if (c == '.')
		{   flags |= FLprecision;
		    //flags &= ~FL0pad;

		    c = getFmtChar();
		    if (c == '*')
		    {
			precision = getFmtStar();
			if (precision < 0)
			{   precision = 0;
			    flags &= ~FLprecision;
			}

			c = getFmtChar();
		    }
		    else if (c >= '0' && c <= '9')
			precision = getFmtInt();
		}

		if (j == arguments.length)
		    goto Lerror;
		ti = arguments[j++];
		ti = skipCI(ti);
		mi = 9;
		do
		{
		    m = cast(Mangle)ti.classinfo.name[mi++];
		} while (m == Mangle.Tconst || m == Mangle.Tinvariant);

		if (c > 0x7F)		// if UTF sequence
		    goto Lerror;	// format specifiers can't be UTF
		formatArg(cast(char)c);
	    }
	}
	else
	{
	    formatArg('s');
	}
    }
    return;

Lerror:
    throw new FormatError();
}

/* ======================== Unit Tests ====================================== */

unittest
{
    int i;
    string s;

    debug(format) printf("std.format.format.unittest\n");
 
    s = std.string.format("hello world! %s %s ", true, 57, 1_000_000_000, 'x', " foo");
    assert(s == "hello world! true 57 1000000000x foo");

    s = std.string.format(1.67, " %A ", -1.28, float.nan);
    /* The host C library is used to format floats.
     * C99 doesn't specify what the hex digit before the decimal point
     * is for %A.
     */
    version (linux)
	assert(s == "1.67 -0XA.3D70A3D70A3D8P-3 nan");
    else
	assert(s == "1.67 -0X1.47AE147AE147BP+0 nan");

    s = std.string.format("%x %X", 0x1234AF, 0xAFAFAFAF);
    assert(s == "1234af AFAFAFAF");

    s = std.string.format("%b %o", 0x1234AF, 0xAFAFAFAF);
    assert(s == "100100011010010101111 25753727657");

    s = std.string.format("%d %s", 0x1234AF, 0xAFAFAFAF);
    assert(s == "1193135 2947526575");

    s = std.string.format("%s", 1.2 + 3.4i);
    assert(s == "1.2+3.4i");

    s = std.string.format("%x %X", 1.32, 6.78f);
    assert(s == "3ff51eb851eb851f 40D8F5C3");

    s = std.string.format("%#06.*f",2,12.345);
    assert(s == "012.35");

    s = std.string.format("%#0*.*f",6,2,12.345);
    assert(s == "012.35");

    s = std.string.format("%7.4g:", 12.678);
    assert(s == "  12.68:");

    s = std.string.format("%7.4g:", 12.678L);
    assert(s == "  12.68:");

    s = std.string.format("%04f|%05d|%#05x|%#5x",-4.,-10,1,1);
    assert(s == "-4.000000|-0010|0x001|  0x1");

    i = -10;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "-10|-10|-10|-10|-10.0000");

    i = -5;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "-5| -5|-05|-5|-5.0000");

    i = 0;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "0|  0|000|0|0.0000");

    i = 5;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "5|  5|005|5|5.0000");

    i = 10;
    s = std.string.format("%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
    assert(s == "10| 10|010|10|10.0000");

    s = std.string.format("%.0d", 0);
    assert(s == "");

    s = std.string.format("%.g", .34);
    assert(s == "0.3");

    s = std.string.format("%.0g", .34);
    assert(s == "0.3");

    s = std.string.format("%.2g", .34);
    assert(s == "0.34");

    s = std.string.format("%0.0008f", 1e-08);
    assert(s == "0.00000001");

    s = std.string.format("%0.0008f", 1e-05);
    assert(s == "0.00001000");

    s = "helloworld";
    string r;
    r = std.string.format("%.2s", s[0..5]);
    assert(r == "he");
    r = std.string.format("%.20s", s[0..5]);
    assert(r == "hello");
    r = std.string.format("%8s", s[0..5]);
    assert(r == "   hello");

    byte[] arrbyte = new byte[4];
    arrbyte[0] = 100;
    arrbyte[1] = -99;
    arrbyte[3] = 0;
    r = std.string.format(arrbyte);
    assert(r == "[100,-99,0,0]");

    ubyte[] arrubyte = new ubyte[4];
    arrubyte[0] = 100;
    arrubyte[1] = 200;
    arrubyte[3] = 0;
    r = std.string.format(arrubyte);
    assert(r == "[100,200,0,0]");

    short[] arrshort = new short[4];
    arrshort[0] = 100;
    arrshort[1] = -999;
    arrshort[3] = 0;
    r = std.string.format(arrshort);
    assert(r == "[100,-999,0,0]");
    r = std.string.format("%s",arrshort);
    assert(r == "[100,-999,0,0]");

    ushort[] arrushort = new ushort[4];
    arrushort[0] = 100;
    arrushort[1] = 20_000;
    arrushort[3] = 0;
    r = std.string.format(arrushort);
    assert(r == "[100,20000,0,0]");

    int[] arrint = new int[4];
    arrint[0] = 100;
    arrint[1] = -999;
    arrint[3] = 0;
    r = std.string.format(arrint);
    assert(r == "[100,-999,0,0]");
    r = std.string.format("%s",arrint);
    assert(r == "[100,-999,0,0]");

    long[] arrlong = new long[4];
    arrlong[0] = 100;
    arrlong[1] = -999;
    arrlong[3] = 0;
    r = std.string.format(arrlong);
    assert(r == "[100,-999,0,0]");
    r = std.string.format("%s",arrlong);
    assert(r == "[100,-999,0,0]");

    ulong[] arrulong = new ulong[4];
    arrulong[0] = 100;
    arrulong[1] = 999;
    arrulong[3] = 0;
    r = std.string.format(arrulong);
    assert(r == "[100,999,0,0]");

    string[] arr2 = new string[4];
    arr2[0] = "hello";
    arr2[1] = "world";
    arr2[3] = "foo";
    r = std.string.format(arr2);
    assert(r == "[hello,world,,foo]");

    r = std.string.format("%.8d", 7);
    assert(r == "00000007");
    r = std.string.format("%.8x", 10);
    assert(r == "0000000a");

    r = std.string.format("%-3d", 7);
    assert(r == "7  ");

    r = std.string.format("%*d", -3, 7);
    assert(r == "7  ");

    r = std.string.format("%.*d", -3, 7);
    assert(r == "7");

    typedef int myint;
    myint m = -7;
    r = std.string.format(m);
    assert(r == "-7");

    r = std.string.format("abc"c);
    assert(r == "abc");
    r = std.string.format("def"w);
    assert(r == "def");
    r = std.string.format("ghi"d);
    assert(r == "ghi");

    void* p = cast(void*)0xDEADBEEF;
    r = std.string.format(p);
    assert(r == "DEADBEEF");

    r = std.string.format("%#x", 0xabcd);
    assert(r == "0xabcd");
    r = std.string.format("%#X", 0xABCD);
    assert(r == "0XABCD");

    r = std.string.format("%#o", 012345);
    assert(r == "012345");
    r = std.string.format("%o", 9);
    assert(r == "11");

    r = std.string.format("%+d", 123);
    assert(r == "+123");
    r = std.string.format("%+d", -123);
    assert(r == "-123");
    r = std.string.format("% d", 123);
    assert(r == " 123");
    r = std.string.format("% d", -123);
    assert(r == "-123");

    r = std.string.format("%%");
    assert(r == "%");

    r = std.string.format("%d", true);
    assert(r == "1");
    r = std.string.format("%d", false);
    assert(r == "0");

    r = std.string.format("%d", 'a');
    assert(r == "97");
    wchar wc = 'a';
    r = std.string.format("%d", wc);
    assert(r == "97");
    dchar dc = 'a';
    r = std.string.format("%d", dc);
    assert(r == "97");

    byte b = byte.max;
    r = std.string.format("%x", b);
    assert(r == "7f");
    r = std.string.format("%x", ++b);
    assert(r == "80");
    r = std.string.format("%x", ++b);
    assert(r == "81");

    short sh = short.max;
    r = std.string.format("%x", sh);
    assert(r == "7fff");
    r = std.string.format("%x", ++sh);
    assert(r == "8000");
    r = std.string.format("%x", ++sh);
    assert(r == "8001");

    i = int.max;
    r = std.string.format("%x", i);
    assert(r == "7fffffff");
    r = std.string.format("%x", ++i);
    assert(r == "80000000");
    r = std.string.format("%x", ++i);
    assert(r == "80000001");

    r = std.string.format("%x", 10);
    assert(r == "a");
    r = std.string.format("%X", 10);
    assert(r == "A");
    r = std.string.format("%x", 15);
    assert(r == "f");
    r = std.string.format("%X", 15);
    assert(r == "F");

    Object c = null;
    r = std.string.format(c);
    assert(r == "null");

    enum TestEnum
    {
	    Value1, Value2
    }
    r = std.string.format("%s", TestEnum.Value2);
    assert(r == "1");

    invariant(char[5])[int] aa = ([3:"hello", 4:"betty"]);
    r = std.string.format("%s", aa.values);
    assert(r == "[[h,e,l,l,o],[b,e,t,t,y]]");
    r = std.string.format("%s", aa);
    assert(r == "[3:[h,e,l,l,o],4:[b,e,t,t,y]]");

    static const dchar[] ds = ['a','b'];
    for (int j = 0; j < ds.length; ++j)
    {
	r = std.string.format(" %d", ds[j]);
	if (j == 0)
	    assert(r == " 97");
	else
	    assert(r == " 98");
    }

    r = std.string.format(">%14d<, ", 15, [1,2,3]);
    assert(r == ">            15<, [1,2,3]");

    assert(std.string.format("%8s", "bar") == "     bar");
    assert(std.string.format("%8s", "b\u00e9ll\u00f4") == "   b\u00e9ll\u00f4");
}

// Andrei
//-------------------------------------------------------------------------------
/**
 * Implements the static Writer interface for a string. Instantiate it
 * with the character type, e.g. StringWriter!(char),
 * StringWriter!(wchar), or StringWriter!(dchar). Regardless of
 * instantiation, StringWriter supports all character widths; it only
 * is the most efficient at accepting the character type it was
 * instantiated with.
 */
struct StringWriter(Char)
{
    alias Char NativeChar;
    Char[] backend;
    void write(C)(in C[] s)
    {
        static if (C.sizeof == NativeChar.sizeof)
        {
            backend ~= s;
        }
        else
        {
            backend ~= to!(const(NativeChar)[])(s);
        }
    }
    void putchar(C)(in C c)
    {
        static if (C.sizeof == NativeChar.sizeof)
        {
            backend ~= c;
        }
        else
        {
            backend ~= to!(const(NativeChar)[])(c);
        }
    }
}

import std.bitmanip;

/*
 * A compiled version of an individual writef format
 * specifier. FormatInfo only focuses on representation, without
 * assigning any semantics to the fields. */
struct FormatInfo
{
    /** minimum width, default 0. If width == width.max, then width
     was specified as '*' in the format string.
    */
    short width = 0; 
    /** precision, default ushort.max - 1. If precision ==
     precision.max, then precision was specified as '*' in the format string.
    */
    short precision = short.max - 1; // by convention max-1 == "no precision"
    /** The actual format specifier, 's' by default. */
    char spec = 's';
    /** Index of the argument, 1 .. ubyte.max. (0 means not used)*/
    ubyte index;
    /* Flags: flDash for '-', flZero for '0', flSpace for ' ', flPlus
     *  for '+', flHash for '#'. */
    mixin(bitfields!(
              bool, "flDash", 1,
              bool, "flZero", 1,
              bool, "flSpace", 1,
              bool, "flPlus", 1,
              bool, "flHash", 1,
              ubyte, "", 3));
}

/*
 * Given a string format specification fmt, parses a format
 * specifier. The string is assumed to start with the character
 * immediately following the '%'. The string is advanced to right
 * after the end of the format specifier. */
FormatInfo parseFormatSpec(S)(ref S fmt)
{
    FormatInfo result;
    if (!fmt.length) return result;
    size_t i = 0;
    for (;;)
        switch (fmt[i])
        {
        case '-': result.flDash = true; ++i; break;
        case '+': result.flPlus = true; ++i; break;
        case '#': result.flHash = true; ++i; break;
        case '0': result.flZero = true; ++i; break;
        case ' ': result.flSpace = true; ++i; break;
        case '*':
            if (isdigit(fmt[++i]))
            {
                // a '*' followed by digits and '$' is a positional format
                fmt = fmt[1 .. $];
                result.width = -parse!(typeof(result.width))(fmt);
                i = 0;
                if (fmt[i++] != '$') throw new FormatError("$ expected");
            }
            else 
            {
                // read result
                result.width = result.width.max;
            }
            break;
        case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9':
            fmt = fmt[i .. $];
            auto widthOrArgIndex = parse!(int)(fmt);
            i = 0;
            if (fmt[0] == '$')
            {
                // index!
                result.index = to!(ubyte)(widthOrArgIndex);
                ++i;
            }
            else
            {
                // width
                result.width = cast(short)widthOrArgIndex;
            }
            break;
        case '.':
            if (fmt[++i] == '*')
            {
                if (isdigit(fmt[++i]))
                {
                    // a '.*' followed by digits and '$' is a positional format
                    fmt = fmt[i .. $];
                    i = 0;
                    result.precision = cast(short)(-parse!(int)(fmt));
                    if (fmt[i++] != '$') throw new FormatError("$ expected");
                }
                else
                {
                    // read result
                    result.precision = result.precision.max;
                }
            }
            else if (fmt[i] == '-')
            {
                // negative precision, as good as 0
                result.precision = 0;
                fmt = fmt[i .. $];
                i = 0;
                parse!(int)(fmt); // skip digits
            }
            else
            {
                fmt = fmt[i .. $];
                i = 0;
                result.precision =
                    cast(short)(isdigit(fmt[0]) ? parse!(int)(fmt) : 0);
            }
            break;
        default:
            // this is the format char
            result.spec = fmt[i];
            fmt = fmt[i + 1 .. $];
            return result;
        }
    //assert(false);
}

//-------------------------------------------------------------------------------
// Writes characters in the format strings up to the first format specifier
// and updates the format specifier to remove the written portion
// The updated format fmt does not include the '%'
private void writeUpToFormatSpec(Writer, S)(ref Writer w, ref S fmt)
{
    for (size_t i = 0; i < fmt.length; ++i)
    {
        if (fmt[i] != '%') continue;
        if (fmt[++i] != '%')
        {
            // spec found, print and bailout
            w.write(fmt[0 .. i - 1]);
            fmt = fmt[i .. $];
            return;
        }
        // doubled! Now print whatever we had, then update the string and move on
        w.write(fmt[0 .. i]);
        fmt = fmt[i + 1 .. $];
        i = 0;
    }
    // no format spec found
    w.write(fmt);
    fmt = null;
}

unittest
{
    StringWriter!(char) w;
    string fmt = "abc%sdef%sghi";
    writeUpToFormatSpec(w, fmt);
    assert(w.backend == "abc" && fmt == "sdef%sghi");
    writeUpToFormatSpec(w, fmt);
    assert(w.backend == "abcsdef" && fmt == "sghi");
    // test with embedded %%s
    fmt = "ab%%cd%%ef%sg%%h%sij";
    w.backend = null;
    writeUpToFormatSpec(w, fmt);
    assert(w.backend == "ab%cd%ef" && fmt == "sg%%h%sij");
    writeUpToFormatSpec(w, fmt);
    assert(w.backend == "ab%cd%efsg%h" && fmt == "sij");
}

/*
 * Formats an integral number 'arg' according to 'f' and writes it to
 * 'w'.
 */ 
private void formatIntegral(Writer, D)(ref Writer w, D argx, FormatInfo f)
{
    Mutable!(D) arg = argx;
    if (f.spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto begin = cast(const char*) &arg;
        if (std.system.endian == Endian.LittleEndian && f.flPlus
            || std.system.endian == Endian.BigEndian && f.flDash)
        {
            // must swap bytes
            foreach_reverse (i; 0 .. arg.sizeof)
                w.putchar(begin[i]);
        }
        else
        {
            foreach (i; 0 .. arg.sizeof)
                w.putchar(begin[i]);
        }
        return;
    }
    if (f.precision == f.precision.max - 1)
    {
        // default precision for integrals is 1
        f.precision = 1;
    }
    else
    {
        // if a precision is specified, the '0' flag is ignored.
        f.flZero = false;
    }
    char leftPad = void;
    if (!f.flDash && !f.flZero)
        leftPad = ' ';
    else if (!f.flDash && f.flZero)
        leftPad = '0';
    else
        leftPad = 0;
    // format and write an integral argument
    uint base =
        f.spec == 'x' || f.spec == 'X' ? 16 :
        f.spec == 'o' ? 8 :
        f.spec == 'b' ? 2 :
        f.spec == 's' || f.spec == 'd' ? 10 :
        0;
    if (base == 0) throw new FormatError("integral");
    // figure out sign and continue in unsigned mode
    char forcedPrefix = void;
    if (f.flPlus) forcedPrefix = '+';
    else if (f.flSpace) forcedPrefix = ' ';
    else forcedPrefix = 0;
    if (base != 10)
    {
        // non-10 bases are always unsigned
        forcedPrefix = 0;
    }
    else if (arg < 0)
    {
        // argument is signed
        forcedPrefix = '-';
        arg = -arg;
    }
    // fill the digits
    char[] digits = void;
    {
        char buffer[64]; // 64 bits in base 2 at most
        uint i = buffer.length;
        auto n = cast(unsigned!(Mutable!(D))) arg;
        do
        {
            --i;
            buffer[i] = cast(char)(n % base);
            n /= base;
            if (buffer[i] < 10) buffer[i] += '0';
            else buffer[i] += (f.spec == 'x' ? 'a' : 'A') - 10;
        } while (n);
        digits = buffer[i .. $]; // got the digits without the sign
    }
    // adjust precision to print a '0' for octal if alternate format is on
    if (base == 8 && f.flHash()
        && (f.precision <= digits.length)) // too low precision
    {
        //f.precision = digits.length + (arg != 0);
        forcedPrefix = '0';
    }
    // write left pad; write sign; write 0x or 0X; write digits;
    //   write right pad
    // Writing left pad
    int spacesToPrint = 
        f.width // start with the minimum width
        - digits.length  // take away digits to print
        - (forcedPrefix != 0) // take away the sign if any
        - (base == 16 && f.flHash() && arg ? 2 : 0); // 0x or 0X
    int delta = f.precision - digits.length;
    if (delta > 0) spacesToPrint -= delta;
    //writeln(spacesToPrint);
    if (spacesToPrint > 0) // need to do some padding
    {
        if (leftPad == '0')
        {
            // pad with zeros
            f.precision =
                cast(typeof(f.precision)) (spacesToPrint + digits.length);
                //to!(typeof(f.precision))(spacesToPrint + digits.length);
        }
        else if (leftPad) foreach (i ; 0 .. spacesToPrint) w.putchar(' ');
    }
    // write sign
    if (forcedPrefix) w.putchar(forcedPrefix);
    // write 0x or 0X
    if (base == 16 && f.flHash() && arg) {
        // @@@ overcome bug in dmd;
        //w.write(f.spec == 'x' ? "0x" : "0X"); //crashes the compiler
        w.putchar('0');
        w.putchar(f.spec == 'x' ? 'x' : 'X'); // x or X
    }
    // write the digits
    if (arg || f.precision)
    {
        int zerosToPrint = f.precision - digits.length;
        foreach (i ; 0 .. zerosToPrint) w.putchar('0');
        w.write(digits);
    }
    // write the spaces to the right if left-align
    if (!leftPad) foreach (i ; 0 .. spacesToPrint) w.putchar(' ');
}

/*
 * Formats a floating point number 'arg' according to 'f' and writes
 * it to 'w'.
 */ 
private void formatFloat(Writer, D)(ref Writer w, D obj, FormatInfo f)
{
    if (f.spec == 'r')
    {
        // raw write, skip all else and write the thing
        auto begin = cast(const char*) &obj;
        if (std.system.endian == Endian.LittleEndian && f.flPlus
            || std.system.endian == Endian.BigEndian && f.flDash)
        {
            // must swap bytes
            foreach_reverse (i; 0 .. obj.sizeof)
                w.putchar(begin[i]);
        }
        else
        {
            foreach (i; 0 .. obj.sizeof)
                w.putchar(begin[i]);
        }
        return;
    }
    if (std.string.find("fgFGaAeEs", f.spec) < 0) {
        throw new FormatError("floating");
    }
    if (f.spec == 's') f.spec = 'g';
    char sprintfSpec[1 /*%*/ + 5 /*flags*/ + 3 /*width.prec*/ + 2 /*format*/
                     + 1 /*\0*/] = void;
    sprintfSpec[0] = '%';
    uint i = 1;
    if (f.flDash) sprintfSpec[i++] = '-';
    if (f.flPlus) sprintfSpec[i++] = '+';
    if (f.flZero) sprintfSpec[i++] = '0';
    if (f.flSpace) sprintfSpec[i++] = ' ';
    if (f.flHash) sprintfSpec[i++] = '#';
    sprintfSpec[i .. i + 3] = "*.*";
    i += 3;
    if (is(const(D) == const(real))) sprintfSpec[i++] = 'L';
    sprintfSpec[i++] = f.spec;
    sprintfSpec[i] = 0;
    //printf("format: '%s'; geeba: %g\n", sprintfSpec.ptr, obj);
    char[512] buf;
    invariant n = snprintf(buf.ptr, buf.length,
                       sprintfSpec.ptr,
                       f.width,
                       // negative precision is same as no precision specified
                       f.precision == f.precision.max - 1 ? -1 : f.precision,
                       obj);
    if (n < 0) throw new FormatError("floating point formatting failure");
    w.write(buf[0 .. strlen(buf.ptr)]);
}

/*
 * Formats an object of type 'D' according to 'f' and writes it to
 * 'w'. The pointer 'arg' is assumed to point to an object of type
 * 'D'.
 */ 
private void formatGeneric(Writer, D)(ref Writer w, const(void)* arg,
    FormatInfo f)
{
    auto obj = *cast(D*) arg;
    static if (is(const(D) == const(void[]))) {
        auto s = cast(const char[]) obj;
        w.write(s);
    } else static if (is(D Original == typedef)) {
        formatGeneric!(Writer, Original)(w, arg, f);
    } else static if (is(const D == const(float))
                      || is(const(D) == const(double))
                      || is(const(D) == const(real))) {
        formatFloat(w, obj, f);
    } else static if (is(const(D) == const ifloat)) {
        formatFloat(w, *cast(float*) &obj, f);
    } else static if (is(const(D) == const idouble)) {
        formatFloat(w, *cast(double*) &obj, f);
    } else static if (is(const(D) == const ireal)) {
        formatFloat(w, *cast(real*) &obj, f);
    } else static if (is(const(D) == const cfloat)
                      || is(const(D) == const cdouble)
                      || is(const(D) == const creal)) {
        formatFloat(w, obj.re, f);
        w.write("+");
        formatFloat(w, obj.im, f);
        w.write("i");
    } else static if (is(const(D) : const long) || is(const(D) : const ulong)) {
        static if (is(const(D) == const bool)) {
            if (f.spec == 's') {
                w.write(obj ? "true" : "false");
            } else {
                formatIntegral(w, cast(int) obj, f);
            }
        } else static if (is(const(D) == const char)
                          || is(const(D) == const wchar)
                          || is(const(D) == const dchar)) {
            if (f.spec == 's') {
                w.putchar(obj);
            } else {
                formatIntegral(w, cast(uint) obj, f);
            }
        } else {
            formatIntegral(w, obj, f);
        }
    } else static if (is(D : const(char)[]) || is(D : const(wchar)[])
                      || is(D : const(dchar)[])) {
        auto s = obj[0 .. f.precision < $ ? f.precision : $];
        if (!f.flDash)
        {
            // right align
            if (f.width > s.length)
                foreach (i ; 0 .. f.width - s.length) w.putchar(' ');
            w.write(s);
        }
        else
        {
            // left align
            w.write(s);
            if (f.width > s.length)
                foreach (i ; 0 .. f.width - s.length) w.putchar(' ');
        }
    } else static if (is(D == void[0])) {
        w.putchar('[');
        w.putchar(']');
    } else static if (isArray!(D)) {
        if (f.spec != 'r') w.putchar('['); // only write the brackets if not raw
	foreach (i, e; obj)
	{
	    if (f.spec != 'r' && i > 0) w.putchar(' ');
	    formatGeneric!(Writer, typeof(e))(w, &e, f);
	}
        if (f.spec != 'r') w.putchar(']'); // only write the brackets if not raw
    } else static if (is(const(D) : const void*)) {
        f.spec = 'X';
        ulong fake = cast(ulong) obj;
        formatGeneric!(Writer, ulong)(w, &fake, f);
    } else static if (is(const(D) : const Object)) {
        if (obj is null) w.write("null");
        else w.write(obj.toString);
    } else static if (isAssociativeArray!(D)) {
        // somebody rid me of this hack
        w.write(std.string.format("%s", obj));
    } else {
        // last resort: look for toString
        auto s = obj.toString;
        w.write(s);                                        
        //static assert(false, "Cannot format type " ~ D.stringof);
    }
}

//-------------------------------------------------------------------------------
// Fix for issue 1591
private int getNthInt(A...)(uint index, A args)
{
    static if (A.length)
    {
        if (index)
        {
            return getNthInt(index - 1, args[1 .. $]); 
        }
        static if (is(typeof(args[0]) : long) || is(typeof(arg) : ulong))
        {
            return to!(int)(args[0]);
        }
        else
        {
            throw new FormatError("int expected");
        }
    }
    else
    {
        throw new FormatError("int expected");
    }
}

/*
  (Not public yet.)  Formats arguments 'args' according to the format
  string 'fmt' and writes the result to 'w'. 'F' must be char, wchar,
  or dchar.

  Example:
  
-------------------------
import std.c.stdio;
import std.format;

string myFormat(A...)(A args)
{
    StringWriter!(char) writer;
    std.format.formattedWrite(writer, "%s et %s numeris romanis non sunt", args);
    return writer.backend;
}

...

int x = 42;
assert(myFormat(x, 0) == "42 et 0 numeris romanis non sunt");
------------------------
 
formattedWrite supports positional parameter syntax in $(WEB
opengroup.org/onlinepubs/009695399/functions/printf.html, POSIX)
style.  Example:

-------------------------
StringWriter!(char) writer;
std.format.formattedWrite(writer, "Date: %2$s %1$s", "October", 5);
assert(writer.backend == "Date: 5 October");
------------------------

The positional and non-positional styles can be mixed in the same
format string. (POSIX leaves this behavior undefined.) The internal
counter for non-positional parameters tracks the next parameter after
the largest positional parameter already used.

Warning:

This is the function internally used by writef* but it's still
undergoing active development. Do not rely on it.
*/

void formattedWrite(Writer, F, A...)(ref Writer w, const(F)[] fmt, A args)
{
    invariant len = args.length;
    void function(ref Writer, const(void)*, FormatInfo) funs[len] = void;
    const(void)* argsAddresses[len] = void;
    foreach (i, arg; args)
    {
        funs[i] = &formatGeneric!(Writer, typeof(arg));
        argsAddresses[i] = &arg;
    }
    uint currentArg = 0;
    for (;;)
    {
        writeUpToFormatSpec(w, fmt);
        auto spec = parseFormatSpec(fmt);
        if (currentArg == funs.length && !spec.index)
        {
            // leftover spec?
            if (fmt.length)
            {
                throw new FormatError(
                    cast(string) ("Orphan format specifier: %" ~ fmt));
            }
            break;
        }
        if (spec.width == spec.width.max)
        {
            auto width = to!(typeof(spec.width))(getNthInt(currentArg, args));
            if (width < 0)
            {
                spec.flDash = true;
                width = cast(short)(0 - width);
            }
            spec.width = width;
            ++currentArg;
        }
        else if (spec.width < 0)
        {
            // means: get width as a positional parameter
            auto index = cast(uint) -spec.width;
            auto width = to!(typeof(spec.width))(getNthInt(index, args));
            if (currentArg < index) currentArg = index;
            if (width < 0)
            {
                spec.flDash = true;
                width = cast(short)(0 - width);
            }
            spec.width = width;
        }
        if (spec.precision == spec.precision.max)
        {
            auto precision = to!(typeof(spec.precision))(
                getNthInt(currentArg, args));
            if (precision >= 0) spec.precision = precision;
            // else negative precision is same as no precision
            else spec.precision = spec.precision.max - 1;
            ++currentArg;
        }
        else if (spec.precision < 0)
        {
            // means: get precision as a positional parameter
            auto index = cast(uint) -spec.precision;
            auto precision = to!(typeof(spec.precision))(
                getNthInt(index, args));
            if (currentArg < index) currentArg = index;
            if (precision >= 0) spec.precision = precision;
            // else negative precision is same as no precision
            else spec.precision = spec.precision.max - 1;
        }
        // Format!
        if (spec.index > 0)
        {
            // using positional parameters!
            funs[spec.index - 1](w, argsAddresses[spec.index - 1], spec);
            if (currentArg < spec.index) currentArg = spec.index;
        }
        else
        {
            funs[currentArg](w, argsAddresses[currentArg], spec);
            ++currentArg;
        }
    }
}

/* ======================== Unit Tests ====================================== */

unittest
{
    StringWriter!(char) stream;
    formattedWrite(stream, "%s", 1.1);
    assert(stream.backend == "1.1", stream.backend);
}

unittest
{
    // testing raw writes
    StringWriter!(char) w;
    w.backend = null;
    uint a = 0x02030405;
    formattedWrite(w, "%+r", a);
    assert(w.backend.length == 4 && w.backend[0] == 2 && w.backend[1] == 3
        && w.backend[2] == 4 && w.backend[3] == 5);
    w.backend = null;
    formattedWrite(w, "%-r", a);
    assert(w.backend.length == 4 && w.backend[0] == 5 && w.backend[1] == 4
        && w.backend[2] == 3 && w.backend[3] == 2);
}

unittest
{
    // testing positional parameters
    StringWriter!(char) w;
    w.backend = null;
    formattedWrite(w, "Numbers %2$s and %1$s are reversed and %1$s%2$s repeated",
        42, 0);
    assert(w.backend == "Numbers 0 and 42 are reversed and 420 repeated",
        w.backend);
}

unittest
{
  debug(format) printf("std.format.format.unittest\n");
    
  StringWriter!(char) stream;
  //goto here;
  
  formattedWrite(stream, "hello world! %s %s ", true, 57, 1_000_000_000, 'x', " foo");
  assert(stream.backend == "hello world! true 57 1000000000x foo");

  stream.backend = null;
  formattedWrite(stream, "%g %A ", 1.67, -1.28, float.nan);
  //std.c.stdio.fwrite(stream.backend.ptr, stream.backend.length, 1, stderr);
  /* The host C library is used to format floats.
   * C99 doesn't specify what the hex digit before the decimal point
   * is for %A.
   */
  version (linux)
      assert(stream.backend == "1.67 -0X1.47AE147AE147BP+0 nan", stream.backend);
  else
      assert(stream.backend == "1.67 -0X1.47AE147AE147BP+0 nan");
  stream.backend = null;

  formattedWrite(stream, "%x %X", 0x1234AF, 0xAFAFAFAF);
  assert(stream.backend == "1234af AFAFAFAF");
  stream.backend = null;

  formattedWrite(stream, "%b %o", 0x1234AF, 0xAFAFAFAF);
  assert(stream.backend == "100100011010010101111 25753727657");
  stream.backend = null;

  formattedWrite(stream, "%d %s", 0x1234AF, 0xAFAFAFAF);
  assert(stream.backend == "1193135 2947526575");
  stream.backend = null;
  
  formattedWrite(stream, "%s", 1.2 + 3.4i);
  assert(stream.backend == "1.2+3.4i");
  stream.backend = null;
  
  formattedWrite(stream, "%a %A", 1.32, 6.78f);
  //formattedWrite(stream, "%x %X", 1.32);
  assert(stream.backend == "0x1.51eb851eb851fp+0 0X1.B1EB86P+2");
  stream.backend = null;

  formattedWrite(stream, "%#06.*f",2,12.345);
  assert(stream.backend == "012.35");
  stream.backend = null;

  formattedWrite(stream, "%#0*.*f",6,2,12.345);
  assert(stream.backend == "012.35");
  stream.backend = null;

  const real constreal = 1;
  formattedWrite(stream, "%g",constreal);
  assert(stream.backend == "1");
  stream.backend = null;

  formattedWrite(stream, "%7.4g:", 12.678);
  assert(stream.backend == "  12.68:");
  stream.backend = null;
  
  formattedWrite(stream, "%7.4g:", 12.678L);
  assert(stream.backend == "  12.68:");
  stream.backend = null;
  
  formattedWrite(stream, "%04f|%05d|%#05x|%#5x",-4.,-10,1,1);
  assert(stream.backend == "-4.000000|-0010|0x001|  0x1",
      stream.backend);
  stream.backend = null;
  
  int i;
  string s;
  
  i = -10;
  formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
  assert(stream.backend == "-10|-10|-10|-10|-10.0000");
  stream.backend = null;

  i = -5;
  formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
  assert(stream.backend == "-5| -5|-05|-5|-5.0000");
  stream.backend = null;

  i = 0;
  formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
  assert(stream.backend == "0|  0|000|0|0.0000");
  stream.backend = null;

  i = 5;
  formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
  assert(stream.backend == "5|  5|005|5|5.0000");
  stream.backend = null;

  i = 10;
  formattedWrite(stream, "%d|%3d|%03d|%1d|%01.4f",i,i,i,i,cast(double) i);
  assert(stream.backend == "10| 10|010|10|10.0000");
  stream.backend = null;

  formattedWrite(stream, "%.0d", 0);
  assert(stream.backend == "");
  stream.backend = null;

  formattedWrite(stream, "%.g", .34);
  assert(stream.backend == "0.3");
  stream.backend = null;
  
  stream.backend = null; formattedWrite(stream, "%.0g", .34);
  assert(stream.backend == "0.3");
  
  stream.backend = null; formattedWrite(stream, "%.2g", .34);
  assert(stream.backend == "0.34");
  
  stream.backend = null; formattedWrite(stream, "%0.0008f", 1e-08);
  assert(stream.backend == "0.00000001");
  
  stream.backend = null; formattedWrite(stream, "%0.0008f", 1e-05);
  assert(stream.backend == "0.00001000");
  
  //return;
  //std.c.stdio.fwrite(stream.backend.ptr, stream.backend.length, 1, stderr);
  
  s = "helloworld";
  string r;
  stream.backend = null; formattedWrite(stream, "%.2s", s[0..5]);
  assert(stream.backend == "he");
  stream.backend = null; formattedWrite(stream, "%.20s", s[0..5]);
  assert(stream.backend == "hello");
  stream.backend = null; formattedWrite(stream, "%8s", s[0..5]);
  assert(stream.backend == "   hello");

  byte[] arrbyte = new byte[4];
  arrbyte[0] = 100;
  arrbyte[1] = -99;
  arrbyte[3] = 0;
  stream.backend = null; formattedWrite(stream, "", arrbyte);
  assert(stream.backend == "[100 -99 0 0]");

  ubyte[] arrubyte = new ubyte[4];
  arrubyte[0] = 100;
  arrubyte[1] = 200;
  arrubyte[3] = 0;
  stream.backend = null; formattedWrite(stream, "", arrubyte);
  assert(stream.backend == "[100 200 0 0]");

  short[] arrshort = new short[4];
  arrshort[0] = 100;
  arrshort[1] = -999;
  arrshort[3] = 0;
  stream.backend = null; formattedWrite(stream, "", arrshort);
  assert(stream.backend == "[100 -999 0 0]");
  stream.backend = null; formattedWrite(stream, "%s",arrshort);
  assert(stream.backend == "[100 -999 0 0]");

  ushort[] arrushort = new ushort[4];
  arrushort[0] = 100;
  arrushort[1] = 20_000;
  arrushort[3] = 0;
  stream.backend = null; formattedWrite(stream, "", arrushort);
  assert(stream.backend == "[100 20000 0 0]");

  int[] arrint = new int[4];
  arrint[0] = 100;
  arrint[1] = -999;
  arrint[3] = 0;
  stream.backend = null; formattedWrite(stream, "", arrint);
  assert(stream.backend == "[100 -999 0 0]");
  stream.backend = null; formattedWrite(stream, "%s",arrint);
  assert(stream.backend == "[100 -999 0 0]");

  long[] arrlong = new long[4];
  arrlong[0] = 100;
  arrlong[1] = -999;
  arrlong[3] = 0;
  stream.backend = null; formattedWrite(stream, "", arrlong);
  assert(stream.backend == "[100 -999 0 0]");
  stream.backend = null; formattedWrite(stream, "%s",arrlong);
  assert(stream.backend == "[100 -999 0 0]");
    
  ulong[] arrulong = new ulong[4];
  arrulong[0] = 100;
  arrulong[1] = 999;
  arrulong[3] = 0;
  stream.backend = null; formattedWrite(stream, "", arrulong);
  assert(stream.backend == "[100 999 0 0]");
  
  string[] arr2 = new string[4];
  arr2[0] = "hello";
  arr2[1] = "world";
  arr2[3] = "foo";
  stream.backend = null; formattedWrite(stream, "", arr2);
  assert(stream.backend == "[hello world  foo]");

  stream.backend = null; formattedWrite(stream, "%.8d", 7);
  assert(stream.backend == "00000007");

  stream.backend = null; formattedWrite(stream, "%.8x", 10);
  assert(stream.backend == "0000000a");

  stream.backend = null; formattedWrite(stream, "%-3d", 7);
  assert(stream.backend == "7  ");
  
  stream.backend = null; formattedWrite(stream, "%*d", -3, 7);
  assert(stream.backend == "7  ");

  stream.backend = null; formattedWrite(stream, "%.*d", -3, 7);
  //writeln(stream.backend);
  assert(stream.backend == "7");

//  assert(false);
//   typedef int myint;
//   myint m = -7;
//   stream.backend = null; formattedWrite(stream, "", m);
//   assert(stream.backend == "-7");
  
  stream.backend = null; formattedWrite(stream, "", "abc"c);
  assert(stream.backend == "abc");
  stream.backend = null; formattedWrite(stream, "", "def"w);
  assert(stream.backend == "def");
  stream.backend = null; formattedWrite(stream, "", "ghi"d);
  assert(stream.backend == "ghi");
  
 here:
  void* p = cast(void*)0xDEADBEEF;
  stream.backend = null; formattedWrite(stream, "", p);
  assert(stream.backend == "DEADBEEF");

  stream.backend = null; formattedWrite(stream, "%#x", 0xabcd);
  assert(stream.backend == "0xabcd");
  stream.backend = null; formattedWrite(stream, "%#X", 0xABCD);
  assert(stream.backend == "0XABCD");

  stream.backend = null; formattedWrite(stream, "%#o", 012345);
  assert(stream.backend == "012345");
  stream.backend = null; formattedWrite(stream, "%o", 9);
  assert(stream.backend == "11");

  stream.backend = null; formattedWrite(stream, "%+d", 123);
  assert(stream.backend == "+123");
  stream.backend = null; formattedWrite(stream, "%+d", -123);
  assert(stream.backend == "-123");
  stream.backend = null; formattedWrite(stream, "% d", 123);
  assert(stream.backend == " 123");
  stream.backend = null; formattedWrite(stream, "% d", -123);
  assert(stream.backend == "-123");
  
  stream.backend = null; formattedWrite(stream, "%%");
  assert(stream.backend == "%");
  
  stream.backend = null; formattedWrite(stream, "%d", true);
  assert(stream.backend == "1");
  stream.backend = null; formattedWrite(stream, "%d", false);
  assert(stream.backend == "0");
    
  stream.backend = null; formattedWrite(stream, "%d", 'a');
  assert(stream.backend == "97");
  wchar wc = 'a';
  stream.backend = null; formattedWrite(stream, "%d", wc);
  assert(stream.backend == "97");
  dchar dc = 'a';
  stream.backend = null; formattedWrite(stream, "%d", dc);
  assert(stream.backend == "97");

  byte b = byte.max;
  stream.backend = null; formattedWrite(stream, "%x", b);
  assert(stream.backend == "7f");
  stream.backend = null; formattedWrite(stream, "%x", ++b);
  assert(stream.backend == "80");
  stream.backend = null; formattedWrite(stream, "%x", ++b);
  assert(stream.backend == "81");

  short sh = short.max;
  stream.backend = null; formattedWrite(stream, "%x", sh);
  assert(stream.backend == "7fff");
  stream.backend = null; formattedWrite(stream, "%x", ++sh);
  assert(stream.backend == "8000");
  stream.backend = null; formattedWrite(stream, "%x", ++sh);
  assert(stream.backend == "8001");
  
  i = int.max;
  stream.backend = null; formattedWrite(stream, "%x", i);
  assert(stream.backend == "7fffffff");
  stream.backend = null; formattedWrite(stream, "%x", ++i);
  assert(stream.backend == "80000000");
  stream.backend = null; formattedWrite(stream, "%x", ++i);
  assert(stream.backend == "80000001");

  stream.backend = null; formattedWrite(stream, "%x", 10);
  assert(stream.backend == "a");
  stream.backend = null; formattedWrite(stream, "%X", 10);
  assert(stream.backend == "A");
  stream.backend = null; formattedWrite(stream, "%x", 15);
  assert(stream.backend == "f");
  stream.backend = null; formattedWrite(stream, "%X", 15);
  assert(stream.backend == "F");

  Object c = null;
  stream.backend = null; formattedWrite(stream, "", c);
  assert(stream.backend == "null");

  enum TestEnum
  {
    Value1, Value2
  }
  stream.backend = null; formattedWrite(stream, "%s", TestEnum.Value2);
  assert(stream.backend == "1");

  //invariant(char[5])[int] aa = ([3:"hello", 4:"betty"]);
  //stream.backend = null; formattedWrite(stream, "%s", aa.values);
  //std.c.stdio.fwrite(stream.backend.ptr, stream.backend.length, 1, stderr);
  //assert(stream.backend == "[[h,e,l,l,o],[b,e,t,t,y]]");
  //stream.backend = null; formattedWrite(stream, "%s", aa);
  //assert(stream.backend == "[3:[h,e,l,l,o],4:[b,e,t,t,y]]");

  static const dchar[] ds = ['a','b'];
  for (int j = 0; j < ds.length; ++j)
    {
      stream.backend = null; formattedWrite(stream, " %d", ds[j]);
      if (j == 0)
	assert(stream.backend == " 97");
      else
	assert(stream.backend == " 98");
    }

  stream.backend = null; formattedWrite(stream, "%.-3d", 7);
  assert(stream.backend == "7", ">" ~ stream.backend ~ "<");
  

  // systematic test
  const string[] flags = [ "-", "+", "#", "0", " ", "" ];
  const string[] widths = [ "", "0", "4", "20" ];
  const string[] precs = [ "", ".", ".0", ".4", ".20" ];
  const string formats = "sdoxXeEfFgGaA";
  /+
  foreach (flag1; flags)
      foreach (flag2; flags)
          foreach (flag3; flags)
              foreach (flag4; flags)
                  foreach (flag5; flags)
                      foreach (width; widths)
                          foreach (prec; precs)
                              foreach (format; formats)
                              {
                                  stream.backend = null; 
                                  auto fmt = "%" ~ flag1 ~ flag2  ~ flag3
                                      ~ flag4 ~ flag5 ~ width ~ prec ~ format
                                      ~ '\0';
                                  fmt = fmt[0 .. $ - 1]; // keep it zero-term
                                  char buf[256];
                                  buf[0] = 0;
                                  switch (format)
                                  {
                                  case 's': 
                                      formattedWrite(stream, fmt, "wyda");
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          "wyda\0".ptr);
                                      break;
                                  case 'd':
                                      formattedWrite(stream, fmt, 456);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               456);
                                      break; 
                                  case 'o':
                                      formattedWrite(stream, fmt, 345);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               345);
                                      break; 
                                  case 'x':
                                      formattedWrite(stream, fmt, 63546);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          63546);
                                      break; 
                                  case 'X':
                                      formattedWrite(stream, fmt, 12566);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          12566);
                                      break; 
                                  case 'e':
                                      formattedWrite(stream, fmt, 3245.345234);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          3245.345234);
                                      break; 
                                  case 'E':
                                      formattedWrite(stream, fmt, 3245.2345234);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          3245.2345234);
                                      break; 
                                  case 'f':
                                      formattedWrite(stream, fmt, 3245234.645675);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          3245234.645675);
                                      break; 
                                  case 'F':
                                      formattedWrite(stream, fmt, 213412.43);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          213412.43);
                                      break; 
                                  case 'g':
                                      formattedWrite(stream, fmt, 234134.34);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                          234134.34);
                                      break; 
                                  case 'G':
                                      formattedWrite(stream, fmt, 23141234.4321);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               23141234.4321);
                                      break; 
                                  case 'a':
                                      formattedWrite(stream, fmt, 21341234.2134123);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               21341234.2134123);
                                      break; 
                                  case 'A':
                                      formattedWrite(stream, fmt, 1092384098.45234);
                                      snprintf(buf.ptr, buf.length, fmt.ptr,
                                               1092384098.45234);
                                      break;
                                  default:
                                      break;
                                  }
                                  auto exp = buf[0 .. strlen(buf.ptr)];
                                  if (stream.backend != exp)
                                  {
                                      writeln("Format: \"", fmt, '"');
                                      writeln("Expected: >", exp, "<");
                                      writeln("Actual:   >", stream.backend,
                                              "<");
                                      assert(false);
                                  }
                              }+/
}

unittest
{
   invariant(char[5])[int] aa = ([3:"hello", 4:"betty"]);
   if (false) writeln(aa.keys);
   assert(aa[3] == "hello");
   assert(aa[4] == "betty");
   if (false)
   {
       writeln(aa.values[0]);
       writeln(aa.values[1]);
       writefln("%s", typeid(typeof(aa.values)));
       writefln("%s", aa[3]);
       writefln("%s", aa[4]);
       writefln("%s", aa.values);
       //writefln("%s", aa);
       wstring a = "abcd";
       writefln(a);
       dstring b = "abcd";
       writefln(b);
   }

   StringWriter!(char) stream;
   alias TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong,
       float, double, real,
       ifloat, idouble, ireal, cfloat, cdouble, creal) AllNumerics;
   foreach (T; AllNumerics)
   {
       static if (is(T : ireal))
           T value = 1i;
       else static if (is(T : creal))
           T value = 1 + 1i;
       else
           T value = 1;
       stream.backend = null; formattedWrite(stream, "%s", value);
       static if (is(T : creal))
           assert(stream.backend == "1+1i");
       else
           assert(stream.backend == "1");
       // test typedefs too
       typedef T Wyda;
       Wyda another = 1;
       stream.backend = null; formattedWrite(stream, "%s", another);
       assert(stream.backend == "1");
   }
   
   //auto r = std.string.format("%s", aa.values);
   stream.backend = null; formattedWrite(stream, "%s", aa);
   assert(stream.backend == "[3:[h,e,l,l,o],4:[b,e,t,t,y]]", stream.backend);
//    r = std.string.format("%s", aa);
//   assert(r == "[3:[h,e,l,l,o],4:[b,e,t,t,y]]");
}
