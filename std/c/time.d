
/**
 * C's &lt;time.h&gt;
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *	WIKI=Phobos/StdCTime
 */

module std.c.time;

private import std.c.stddef;

extern (C):

alias int clock_t;

version (Windows)
{   const clock_t CLOCKS_PER_SEC = 1000;
    const clock_t CLK_TCK        = 1000;

    struct tm
    {  int     tm_sec,
               tm_min,
               tm_hour,
               tm_mday,
               tm_mon,
               tm_year,
               tm_wday,
               tm_yday,
               tm_isdst;
    }
}
else version (linux)
{   const clock_t CLOCKS_PER_SEC = 1000000;
    extern (C) int sysconf(int);
    extern clock_t CLK_TCK;
    /*static this()
    {
	CLK_TCK = cast(clock_t) sysconf(2);
    }*/

    struct tm
    {  int     tm_sec,
               tm_min,
               tm_hour,
               tm_mday,
               tm_mon,
               tm_year,
               tm_wday,
               tm_yday,
               tm_isdst;
    }
}
else version (OSX)
{
    const clock_t CLOCKS_PER_SEC = 100;
    const clock_t CLK_TCK        = 100;

    struct tm
    {  int     tm_sec,
               tm_min,
               tm_hour,
               tm_mday,
               tm_mon,
               tm_year,
               tm_wday,
               tm_yday,
               tm_isdst;
    }
}
else version (FreeBSD)
{
    const clock_t CLOCKS_PER_SEC = 128;
    const clock_t CLK_TCK        = 128; // deprecated, use sysconf(_SC_CLK_TCK)

    struct tm
    {   int     tm_sec,
               tm_min,
               tm_hour,
               tm_mday,
               tm_mon,
               tm_year,
               tm_wday,
               tm_yday,
               tm_isdst;
	int tm_gmtoff;
	char* tm_zone;
    }
}
else version (Solaris)
{
    const clock_t CLOCKS_PER_SEC = 1000000;
    clock_t CLK_TCK        = 0; // deprecated, use sysconf(_SC_CLK_TCK)

    extern (C) int sysconf(int);
    static this()
    {
       CLK_TCK = _sysconf(3);
    }

    struct tm
    {   int     tm_sec,
               tm_min,
               tm_hour,
               tm_mday,
               tm_mon,
               tm_year,
               tm_wday,
               tm_yday,
               tm_isdst;
    }
}
else
{
    static assert(0);
}

const uint TIMEOFFSET     = 315558000;

alias int time_t;

extern int daylight;
extern int timezone;
extern int altzone;
extern char *tzname[2];

clock_t clock();
time_t time(time_t *);
time_t mktime(tm *);
char *asctime(tm *);
char *ctime(time_t *);
tm *localtime(time_t *);
tm *gmtime(time_t *);
size_t strftime(char *, size_t, char *, tm *);
char *_strdate(char *dstring);
char *_strtime(char *timestr);
double difftime(time_t t1, time_t t2);
void _tzset();
void tzset();

void sleep(time_t);
void usleep(uint);
void msleep(uint);

wchar_t *_wasctime(tm *);
wchar_t *_wctime(time_t *);
size_t wcsftime(wchar_t *, size_t, wchar_t *, tm *);
wchar_t *_wstrdate(wchar_t *);
wchar_t *_wstrtime(wchar_t *);
