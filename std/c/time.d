
module std.c.time;

extern (C):

const uint CLOCKS_PER_SEC = 1000;
const uint CLK_TCK        = 1000;
const uint TIMEOFFSET     = 315558000;

alias int clock_t;
alias int time_t;

extern int daylight;
extern int timezone;
extern int altzone;
extern char *tzname[2];

struct tm
{      int     tm_sec,
               tm_min,
               tm_hour,
               tm_mday,
               tm_mon,
               tm_year,
               tm_wday,
               tm_yday,
               tm_isdst;
}

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

wchar *_wasctime(tm *);
wchar *_wctime(time_t *);
size_t wcsftime(wchar *, size_t, wchar *, tm *);
wchar *_wstrdate(wchar *);
wchar *_wstrtime(wchar *);
