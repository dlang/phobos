/*
 *  Copyright (C) 2004 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
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
private import std.c.stdlib;
private import std.string;

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
    extern (C) char* function(int c, int flags, int precision, real* pdval,
	char* buf, int* psl, int width) __pfloatfmt;
}
else
{
    // Use C99 snprintf
    extern (C) int snprintf(char* s, size_t n, char* format, ...);
}

enum Mangle : char
{
    Tvoid     = 'v',
    Tbit      = 'b',
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
    case Mangle.Tbit:
      ti = typeid(bit);break;
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
 * Convert arguments to tchar's according to format strings and feed to putc().
 * This is the core workhorse routine for all the various formatters.
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


    void formatArg(char fc)
    {
	bit vbit;
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
	char* prefix = "";
	char[] s;

	void putstr(char[] s)
	{
	    //printf("flags = x%x\n", flags);
	    int prepad = 0;
	    int postpad = 0;
	    int padding = field_width - (strlen(prefix) + s.length);
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
		    n = snprintf(fbuf, sl, format, field_width, precision, v);
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

	void putArray(void* p, size_t len, TypeInfo ti) {
	  putc('[');
	  size_t tsize = ti.tsize();
	  while (len--) {
	    doFormat(putc, (&ti)[0 .. 1], p);
	    p += tsize;
	    if (len > 0) putc(',');
	  }
	  putc(']');
	}

	//printf("formatArg(fc = '%c', m = '%c')\n", fc, m);
	switch (m)
	{
	    case Mangle.Tbit:
		vbit = va_arg!(bit)(argptr);
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
			throw new UtfError("invalid dchar in format", 0);
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
		vnumber = va_arg!(long)(argptr);
		goto Lnumber;

	    case Mangle.Tulong:
	    Lulong:
		vnumber = va_arg!(ulong)(argptr);
		goto Lnumber;

	    case Mangle.Tclass:
		vobject = va_arg!(Object)(argptr);
		s = vobject.toString();
		goto Lputstr;

	    case Mangle.Tpointer:
		vnumber = cast(ulong)va_arg!(void*)(argptr);
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

	    case Mangle.Tarray:
	        if (ti.classinfo.name.length == 14 &&
		    ti.classinfo.name[9..14] == "Array") 
		{ // array of non-primitive types
		  void[] va = va_arg!(void[])(argptr);
		  putArray(va.ptr, va.length, (cast(TypeInfo_Array)ti).next);
		  return;
		}
		m2 = cast(Mangle)ti.classinfo.name[10];
		switch (m2)
		{
		    case Mangle.Tchar:
			s = va_arg!(char[])(argptr);
			goto Lputstr;

		    case Mangle.Twchar:
			wchar[] sw = va_arg!(wchar[])(argptr);
			s = toUTF8(sw);
			goto Lputstr;

		    case Mangle.Tdchar:
			dchar[] sd = va_arg!(dchar[])(argptr);
			s = toUTF8(sd);
		    Lputstr:
			if (flags & FLprecision && precision < s.length)
			    s = s[0 .. precision];
			putstr(s);
			break;

  		    default:
		        TypeInfo ti2 = primitiveTypeInfo(m2);
			if (!ti2)
			  goto Lerror;
			void[] va = va_arg!(void[])(argptr);
			putArray(va.ptr, va.length, ti2);
		}
		return;

	    case Mangle.Ttypedef:
		ti = (cast(TypeInfo_Typedef)ti).base;
		m = cast(Mangle)ti.classinfo.name[9];
		formatArg(fc);
		return;

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

	if (flags & FLprecision && fc != 'p')
	    flags &= ~FL0pad;

	if (vnumber < 10)
	{
	    if (vnumber == 0 && precision == 0 && flags & FLprecision &&
		!(fc == 'o' && flags & FLhash))
	    {
		putstr(null);
		return;
	    }
	    if (vnumber < base)
	    {	vchar = '0' + vnumber;
		goto L2;
	    }
	}

	int n = tmpbuf.length;
	char c;
	int hexoffset = uc ? ('A' - ('9' + 1)) : ('a' - ('9' + 1));

	while (vnumber)
	{
	    c = (vnumber % base) + '0';
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
	if (ti.classinfo.name.length < 10)
	    goto Lerror;
	m = cast(Mangle)ti.classinfo.name[9];

	if (m == Mangle.Tarray)
	{
	    Mangle m2 = cast(Mangle)ti.classinfo.name[10];
	    char[]  fmt;			// format string
	    wchar[] wfmt;
	    dchar[] dfmt;

	    /* For performance reasons, this code takes advantage of the
	     * fact that most format strings will be ASCII, and that the
	     * format specifiers are always ASCII. This means we only need
	     * to deal with UTF in a couple of isolated spots.
	     */

	    switch (m2)
	    {
		case Mangle.Tchar:
		    fmt = va_arg!(char[])(argptr);
		    break;

		case Mangle.Twchar:
		    wfmt = va_arg!(wchar[])(argptr);
		    fmt = toUTF8(wfmt);
		    break;

		case Mangle.Tdchar:
		    dfmt = va_arg!(dchar[])(argptr);
		    fmt = toUTF8(dfmt);
		    break;

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
		m = cast(Mangle)ti.classinfo.name[9];

		if (c > 0x7F)		// if UTF sequence
		    goto Lerror;	// format specifiers can't be UTF
		formatArg(cast(char)c);
	    }
	}
	else
	{
	    field_width = 0;
	    flags = 0;
	    precision = 0;
	    formatArg('s');
	}
    }
    return;

Lerror:
    throw new FormatError();
}


class FormatError : Error
{
  private:

    this()
    {
	super("std.format");
    }

    this(char[] msg)
    {
	super("std.format " ~ msg);
    }
}

/* ======================== Unit Tests ====================================== */

unittest
{
    int i;
    char[] s;

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
    char[] r;
    r = std.string.format("%.2s", s[0..5]);
    assert(r == "he");
    r = std.string.format("%.20s", s[0..5]);
    assert(r == "hello");
    r = std.string.format("%8s", s[0..5]);
    assert(r == "   hello");

    int[] arr = new int[4];
    arr[0] = 100;
    arr[1] = -999;
    arr[3] = 0;
    r = std.string.format(arr);
    assert(r == "[100,-999,0,0]");
    r = std.string.format("%s",arr);
    assert(r == "[100,-999,0,0]");

    char[][] arr2 = new char[][4];
    arr2[0] = "hello";
    arr2[1] = "world";
    arr2[3] = "foo";
    r = std.string.format(arr2);
    assert(r == "[hello,world,,foo]");

}

