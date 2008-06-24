
/**
 * C's &lt;wchar.h&gt;
 * Authors: Walter Bright, Digital Mars, www.digitalmars.com
 * License: Public Domain
 * Macros:
 *	WIKI=Phobos/StdCWchar
 */

module std.c.wcharh;

private import std.c.stdio;
private import std.c.stddef;
private import std.c.stdarg;
private import std.c.time;

extern (C):

version (Windows)
{
    alias int mbstate_t;
    alias wchar_t wint_t;
    const wint_t WEOF = 0xFFFF;
}
else version (linux)
{
    struct mbstate_t
    {
	int __count;
	union U
	{
	    wint_t __wch;
	    ubyte[4] __wchb;
	}
	U __value;
    }
    alias uint wint_t;
    const wint_t WEOF = 0xFFFFFFFFu;
}
else
{
    static assert(0);
}

const wchar_t WCHAR_MAX = wchar_t.max;
const wchar_t WCHAR_MIN = wchar_t.min;

int fwprintf(FILE* stream, in wchar_t* format, ...);
int fwscanf(FILE* stream, in wchar_t* format, ...);
int swprintf(wchar_t* s, size_t n, in wchar_t* format, ...);
int swscanf(wchar_t* s, in wchar_t* format, ...);
int vfwprintf(FILE* stream, in wchar_t* format, va_list arg);
int vfwscanf(FILE* stream, in wchar_t* format, va_list arg);
int vswprintf(wchar_t* s, size_t n, in wchar_t* format, va_list arg);
int vswscanf(wchar_t* s, in wchar_t* format, va_list arg);
int vwprintf(in wchar_t* format, va_list arg);
int vwscanf(in wchar_t* format, va_list arg);
int wprintf(in wchar_t* format, ...);
int wscanf(in wchar_t* format, ...);
wint_t fgetwc(FILE *stream);
wchar_t *fgetws(wchar_t* s, int n, FILE* stream);
wint_t fputwc(wchar_t c, FILE *stream);
int fputws(in wchar_t* s, FILE* stream);
int fwide(FILE *stream, int mode);
wint_t getwc(FILE *stream);
wint_t getwchar();
wint_t putwc(wchar_t c, FILE *stream);
wint_t putwchar(wchar_t c);
wint_t ungetwc(wint_t c, FILE *stream);
double wcstod(wchar_t* nptr, wchar_t** endptr);
float wcstof(wchar_t* nptr, wchar_t** endptr);
real wcstold(wchar_t* nptr, wchar_t** endptr);
int wcstol(wchar_t* nptr, wchar_t** endptr, int base);
long wcstoll(wchar_t* nptr, wchar_t** endptr, int base);
uint wcstoul(wchar_t* nptr, wchar_t** endptr, int base);
ulong wcstoull(wchar_t* nptr, wchar_t** endptr, int base);
wchar_t *wcscpy(wchar_t* s1, in wchar_t* s2);
wchar_t *wcsncpy(wchar_t* s1, in wchar_t* s2, size_t n);
wchar_t *wcscat(wchar_t* s1, in wchar_t* s2);
wchar_t *wcsncat(wchar_t* s1, in wchar_t* s2, size_t n);
int wcscmp(in wchar_t *s1, in wchar_t *s2);
int wcscoll(in wchar_t *s1, in wchar_t *s2);
int wcsncmp(in wchar_t *s1, in wchar_t *s2, size_t n);
size_t wcsxfrm(wchar_t* s1, in wchar_t* s2, size_t n);
wchar_t *wcschr(wchar_t *s, wchar_t c);
size_t wcscspn(in wchar_t *s1, in wchar_t *s2);
size_t wcslen(in wchar_t *s);
wchar_t *wcspbrk(wchar_t *s1, in wchar_t *s2);
wchar_t *wcsrchr(wchar_t *s, wchar_t c);
size_t wcsspn(in wchar_t *s1, in wchar_t *s2);
wchar_t *wcsstr(wchar_t *s1, in wchar_t *s2);
wchar_t *wcstok(wchar_t* s1, in wchar_t* s2, wchar_t** ptr);
wchar_t *wmemchr(wchar_t *s, wchar_t c, size_t n);
int wmemcmp(in wchar_t* s1, in wchar_t* s2, size_t n);
wchar_t *wmemcpy(wchar_t* s1, in wchar_t* s2, size_t n);
wchar_t *wmemmove(wchar_t *s1, in wchar_t *s2, size_t n);
wchar_t *wmemset(wchar_t *s, wchar_t c, size_t n);
size_t wcsftime(wchar_t* s, size_t maxsize, in wchar_t* format, in tm* timeptr);
wint_t btowc(int c);
int wctob(wint_t c);
int mbsinit(in mbstate_t *ps);
size_t mbrlen(in char* s, size_t n, mbstate_t* ps);
size_t mbrtowc(wchar_t* pwc, in char* s, size_t n, mbstate_t* ps);
size_t wcrtomb(char* s, wchar_t wc, mbstate_t* ps);
size_t mbsrtowcs(wchar_t* dst, const (char*)* src, size_t len, mbstate_t* ps);
size_t wcsrtombs(char* dst, wchar_t** src, size_t len, mbstate_t* ps);
