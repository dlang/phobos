
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

module std.date;

private import std.c.stdio;
private import std.dateparse;

alias long d_time;
//typedef double d_time;

d_time d_time_nan = long.min; //double.nan;

struct Date
{
    int year = int.min;	// our "nan" Date value
    int month;		// 1..12
    int day;		// 1..31
    int hour;		// 0..23
    int minute;		// 0..59
    int second;		// 0..59
    int ms;		// 0..999
    int weekday;	// 0: not specified
			// 1..7: Sunday..Saturday
    int tzcorrection = int.min;	// -12..12 correction in hours

    void parse(char[] s)
    {
	DateParse dp;

	dp.parse(s, *this);
    }
}

enum
{
	HoursPerDay    = 24,
	MinutesPerHour = 60,
	msPerMinute    = 60 * 1000,
	msPerHour      = 60 * msPerMinute,
	msPerDay       = 86400000,
	TicksPerMs     = 1,
	TicksPerSecond = 1000,
	TicksPerMinute = TicksPerSecond * 60,
	TicksPerHour   = TicksPerMinute * 60,
	TicksPerDay    = TicksPerHour   * 24,
}

d_time LocalTZA = 0;


const char[] daystr = "SunMonTueWedThuFriSat";
const char[] monstr = "JanFebMarAprMayJunJulAugSepOctNovDec";

/********************************
 * Compute ISO 8601 week based year.
 * Week 1 is first week with Jan 4 in it.
 * Monday is start of week.
 * Weeks are 1..53
 */

void toISO8601YearWeek(d_time t, out int year, out int week)
{
    year = YearFromTime(t);

    int yday = Day(t) - DayFromYear(year);
    int d;
    int w;
    int ydaybeg;

    /* Determine day of week Jan 4 falls on.
     * Weeks begin on a Monday.
     */

    d = DayFromYear(year);
    w = (d + 3/*Jan4*/ + 3) % 7;
    if (w < 0)
        w += 7;

    /* Find yday of beginning of ISO 8601 year
     */
    ydaybeg = 3/*Jan4*/ - w;

    /* Check if yday is actually the last week of the previous year
     */
    if (yday < ydaybeg)
    {
	year -= 1;
	week = 53;
        return;
    }

    /* Check if yday is actually the first week of the next year
     */
    if (yday >= 362)                            // possible
    {   int d2;
        int ydaybeg2;

        d2 = DayFromYear(year + 1);
        w = (d2 + 3/*Jan4*/ + 3) % 7;
        if (w < 0)
            w += 7;
        //printf("w = %d\n", w);
        ydaybeg2 = 3/*Jan4*/ - w;
        if (d + yday >= d2 + ydaybeg2)
        {
	    year += 1;
	    week = 1;
            return;
        }
    }

    week = (yday - ydaybeg) / 7 + 1;
}

d_time floor(d_time d)
{
    return d;
}

d_time floor(real d)
{
    return cast(d_time)d;
}

d_time dmod(d_time n, d_time d)
{   d_time r;

    r = n % d;
    if (r < 0)
	r += d;
    return r;
}

d_time HourFromTime(d_time t)
{
    return dmod(floor(t / msPerHour), HoursPerDay);
}

d_time MinFromTime(d_time t)
{
    return dmod(floor(t / msPerMinute), MinutesPerHour);
}

d_time SecFromTime(d_time t)
{
    return dmod(floor(t / TicksPerSecond), 60);
}

d_time msFromTime(d_time t)
{
    return dmod(t / (TicksPerSecond / 1000), 1000);
}

d_time TimeWithinDay(d_time t)
{
    return dmod(t, msPerDay);
}

d_time toInteger(d_time n)
{
    return (n >= 0)
	? floor(n)
	: - floor(-n);
}

int Day(d_time t)
{
    if (t < 0)
	t -= msPerDay;		// use this if t is not floating point
    return cast(int)floor(t / msPerDay);
}

int LeapYear(int y)
{
    return ((y & 3) == 0 &&
	    (y % 100 || (y % 400) == 0));
}

int DaysInYear(int y)
{
    return 365 + LeapYear(y);
}

int DayFromYear(int y)
{
    return cast(int) (365 * (y - 1970) +
		floor((y - 1969.0) / 4) -
		floor((y - 1901.0) / 100) +
		floor((y - 1601.0) / 400));
}

d_time TimeFromYear(int y)
{
    return cast(d_time)msPerDay * DayFromYear(y);
}

int YearFromTime(d_time t)
{   int y;

    // Hazard a guess
    y = 1970 + cast(int) (t / (365.2425 * msPerDay));

    if (TimeFromYear(y) <= t)
    {
	while (TimeFromYear(y + 1) <= t)
	    y++;
    }
    else
    {
	do
	{
	    y--;
	}
	while (TimeFromYear(y) > t);
    }
    return y;
}

int inLeapYear(d_time t)
{
    return LeapYear(YearFromTime(t));
}

int MonthFromTime(d_time t)
{
    int day;
    int month;
    int year;

    year = YearFromTime(t);
    day = Day(t) - DayFromYear(year);

    if (day < 59)
    {
	if (day < 31)
	{   assert(day >= 0);
	    month = 0;
	}
	else
	    month = 1;
    }
    else
    {
	day -= LeapYear(year);
	if (day < 212)
	{
	    if (day < 59)
		month = 1;
	    else if (day < 90)
		month = 2;
	    else if (day < 120)
		month = 3;
	    else if (day < 151)
		month = 4;
	    else if (day < 181)
		month = 5;
	    else
		month = 6;
	}
	else
	{
	    if (day < 243)
		month = 7;
	    else if (day < 273)
		month = 8;
	    else if (day < 304)
		month = 9;
	    else if (day < 334)
		month = 10;
	    else if (day < 365)
		month = 11;
	    else
	    {	assert(0);
		month = -1;	// keep /W4 happy
	    }
	}
    }
    return month;
}

int DateFromTime(d_time t)
{
    int day;
    int leap;
    int month;
    int year;
    int date;

    year = YearFromTime(t);
    day = Day(t) - DayFromYear(year);
    leap = LeapYear(year);
    month = MonthFromTime(t);
    switch (month)
    {
	case 0:	 date = day +   1;		break;
	case 1:	 date = day -  30;		break;
	case 2:	 date = day -  58 - leap;	break;
	case 3:	 date = day -  89 - leap;	break;
	case 4:	 date = day - 119 - leap;	break;
	case 5:	 date = day - 150 - leap;	break;
	case 6:	 date = day - 180 - leap;	break;
	case 7:	 date = day - 211 - leap;	break;
	case 8:	 date = day - 242 - leap;	break;
	case 9:	 date = day - 272 - leap;	break;
	case 10: date = day - 303 - leap;	break;
	case 11: date = day - 333 - leap;	break;
	default:
	    assert(0);
	    date = -1;	// keep /W4 happy
    }
    return date;
}

int WeekDay(d_time t)
{   int w;

    w = (cast(int)Day(t) + 4) % 7;
    if (w < 0)
	w += 7;
    return w;
}

// Convert from UTC to local time

d_time UTCtoLocalTime(d_time t)
{
    return t + LocalTZA + DaylightSavingTA(t);
}

// Convert from local time to UTC

d_time LocalTimetoUTC(d_time t)
{
    return t - LocalTZA - DaylightSavingTA(t - LocalTZA);
}

d_time MakeTime(d_time hour, d_time min, d_time sec, d_time ms)
{
  /+
    if (!Port::isfinite(hour) ||
	!Port::isfinite(min) ||
	!Port::isfinite(sec) ||
	!Port::isfinite(ms))
	return  d_time_nan;
   +/

    hour = toInteger(hour);
    min = toInteger(min);
    sec = toInteger(sec);
    ms = toInteger(ms);

    return hour * TicksPerHour +
	   min * TicksPerMinute +
	   sec * TicksPerSecond +
	   ms * TicksPerMs;
}


d_time MakeDay(d_time year, d_time month, d_time date)
{   d_time t;
    int y;
    int m;
    int leap;
    static int mdays[12] =
    [ 0,31,59,90,120,151,181,212,243,273,304,334 ];

/+
    if (!Port::isfinite(year) ||
	!Port::isfinite(month) ||
	!Port::isfinite(date))
	return  d_time.init;
 +/

    year = toInteger(year);
    month = toInteger(month);
    date = toInteger(date);

    y = cast(int)(year + floor(month / 12));
    m = cast(int)dmod(month, 12);

    leap = LeapYear(y);
    t = TimeFromYear(y) + cast(d_time)mdays[m] * msPerDay;
    if (leap && month >= 2)
	t += msPerDay;

    if (YearFromTime(t) != y ||
	MonthFromTime(t) != m ||
	DateFromTime(t) != 1)
	return  d_time_nan;

    return Day(t) + date - 1;
}

d_time MakeDate(d_time day, d_time time)
{
  /+
    if (!Port::isfinite(day) ||
	!Port::isfinite(time))
	return  d_time.init;
   +/

    return day * TicksPerDay + time;
}

d_time TimeClip(d_time time)
{
    //printf("TimeClip(%g) = %g\n", time, toInteger(time));
  /+
    if (!Port::isfinite(time) ||
	time > 8.64e15 ||
	time < -8.64e15)
	return  d_time_nan;
   +/
    return toInteger(time);
}

char[] toString(d_time time)
{
    d_time t;
    char sign;
    int hr;
    int mn;
    int len;
    d_time offset;
    d_time dst;

    // Years are supposed to be -285616 .. 285616, or 7 digits
    // "Tue Apr 02 02:04:57 GMT-0800 1996"
    char[] buffer = new char[29 + 7 + 1];

    if (time == d_time_nan)
	return "Invalid Date";

    dst = DaylightSavingTA(time);
    offset = LocalTZA + dst;
    t = time + offset;
    sign = '+';
    if (offset < 0)
    {	sign = '-';
//	offset = -offset;
	offset = -(LocalTZA + dst);
    }

    mn = cast(int)(offset / msPerMinute);
    hr = mn / 60;
    mn %= 60;

    //printf("hr = %d, offset = %g, LocalTZA = %g, dst = %g, + = %g\n", hr, offset, LocalTZA, dst, LocalTZA + dst);

    len = sprintf(buffer, "%.3s %.3s %02d %02d:%02d:%02d GMT%c%02d%02d %d",
	&daystr[WeekDay(t) * 3],
	&monstr[MonthFromTime(t) * 3],
	DateFromTime(t),
	cast(int)HourFromTime(t), cast(int)MinFromTime(t), cast(int)SecFromTime(t),
	sign, hr, mn,
	cast(long)YearFromTime(t));

    // Ensure no buggy buffer overflows
    //printf("len = %d, buffer.length = %d\n", len, buffer.length);
    assert(len < buffer.length);

    return buffer[0 .. len];
}

char[] toDateString(d_time time)
{
    d_time t;
    d_time offset;
    d_time dst;
    int len;

    // Years are supposed to be -285616 .. 285616, or 7 digits
    // "Tue Apr 02 1996"
    char[] buffer = new char[29 + 7 + 1];

  /+
    if (Port::isnan(time))
	return "Invalid Date";
   +/

    dst = DaylightSavingTA(time);
    offset = LocalTZA + dst;
    t = time + offset;

    len = sprintf(buffer, "%.3s %.3s %02d %d",
	&daystr[WeekDay(t) * 3],
	&monstr[MonthFromTime(t) * 3],
	DateFromTime(t),
	cast(long)YearFromTime(t));

    // Ensure no buggy buffer overflows
    assert(len < buffer.length);

    return buffer[0 .. len];
}

char[] toTimeString(d_time time)
{
    d_time t;
    char sign;
    int hr;
    int mn;
    int len;
    d_time offset;
    d_time dst;

    // "02:04:57 GMT-0800"
    char[] buffer = new char[17 + 1];

  /+
    if (Port::isnan(time))
	return "Invalid Date";
   +/

    dst = DaylightSavingTA(time);
    offset = LocalTZA + dst;
    t = time + offset;
    sign = '+';
    if (offset < 0)
    {	sign = '-';
//	offset = -offset;
	offset = -(LocalTZA + dst);
    }

    mn = cast(int)(offset / msPerMinute);
    hr = mn / 60;
    mn %= 60;

    //printf("hr = %d, offset = %g, LocalTZA = %g, dst = %g, + = %g\n", hr, offset, LocalTZA, dst, LocalTZA + dst);

    len = sprintf(buffer, "%02d:%02d:%02d GMT%c%02d%02d",
	cast(int)HourFromTime(t), cast(int)MinFromTime(t), cast(int)SecFromTime(t),
	sign, hr, mn);

    // Ensure no buggy buffer overflows
    assert(len < buffer.length);

    // Lop off terminating 0
    return buffer[0 .. len];
}

d_time parse(char[] s)
{
    Date dp;
    d_time n;
    d_time day;
    d_time time;

    try
    {
	dp.parse(s);

	//printf("year = %d, month = %d, day = %d\n", dp.year, dp.month, dp.day);
	//printf("%02d:%02d:%02d.%03d\n", dp.hour, dp.minute, dp.second, dp.ms);
	//printf("weekday = %d, ampm = %d, tzcorrection = %d\n", dp.weekday, dp.ampm, dp.tzcorrection);

	time = MakeTime(dp.hour, dp.minute, dp.second, dp.ms);
	if (dp.tzcorrection == Date.tzcorrection.init)
	    time -= LocalTZA;
	else
	    time += cast(d_time)dp.tzcorrection * msPerHour;
	day = MakeDay(dp.year, dp.month - 1, dp.day);
	n = MakeDate(day,time);
	n = TimeClip(n);
    }
    catch
    {
	n =  d_time.init;		// erroneous date string
    }
    return n;
}

static this()
{
    LocalTZA = getLocalTZA();
    //printf("LocalTZA = %g, %g\n", LocalTZA, LocalTZA / msPerHour);
}

version (Win32)
{

    private import std.c.windows.windows;
    //import c.time;

    d_time getUTCtime()
    {
	SYSTEMTIME st;
	d_time n;

	GetSystemTime(&st);		// get time in UTC
	n = SYSTEMTIME2d_time(&st, 0);
	return n;
	//return c.time.time(null) * TicksPerSecond;
    }

    static d_time SYSTEMTIME2d_time(SYSTEMTIME *st, d_time t)
    {
	d_time n;
	d_time day;
	d_time time;

	if (st.wYear)
	{
	    time = MakeTime(st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
	    day = MakeDay(st.wYear, st.wMonth - 1, st.wDay);
	}
	else
	{   // wDayOfWeek is weekday, wDay is which week in the month
	    int year;
	    int wd;
	    int mday;
	    int month;
	    d_time x;

	    year = YearFromTime(t);
	    month = st.wMonth - 1;
	    x = MakeDay(year, month, 1);
	    wd = WeekDay(MakeDate(x, 0));

	    mday = (7 - wd + st.wDayOfWeek);
	    if (mday >= 7)
		mday -= 7;
	    mday += (st.wDay - 1) * 7 + 1;
	    //printf("month = %d, wDayOfWeek = %d, wDay = %d, mday = %d\n", st.wMonth, st.wDayOfWeek, st.wDay, mday);

	    day = MakeDay(year, month, mday);
	    time = 0;
	}
	n = MakeDate(day,time);
	n = TimeClip(n);
	return n;
    }

    d_time getLocalTZA()
    {
	d_time t;
	DWORD r;
	TIME_ZONE_INFORMATION tzi;

	/* http://msdn.microsoft.com/library/en-us/sysinfo/base/gettimezoneinformation.asp
	 */
	r = GetTimeZoneInformation(&tzi);
	switch (r)
	{
	    case TIME_ZONE_ID_STANDARD:
	    case TIME_ZONE_ID_DAYLIGHT:
		//printf("bias = %d\n", tzi.Bias);
		//printf("standardbias = %d\n", tzi.StandardBias);
		//printf("daylightbias = %d\n", tzi.DaylightBias);
		t = -(tzi.Bias + tzi.StandardBias) * cast(d_time)(60 * TicksPerSecond);
		break;

	    default:
		t = 0;
		break;
	}

	return t;
    }

    /*
     * Get daylight savings time adjust for time dt.
     */

    int DaylightSavingTA(d_time dt)
    {
	int t;
	DWORD r;
	TIME_ZONE_INFORMATION tzi;
	d_time ts;
	d_time td;

	/* http://msdn.microsoft.com/library/en-us/sysinfo/base/gettimezoneinformation.asp
	 */
	r = GetTimeZoneInformation(&tzi);
	t = 0;
	switch (r)
	{
	    case TIME_ZONE_ID_STANDARD:
	    case TIME_ZONE_ID_DAYLIGHT:
		if (tzi.StandardDate.wMonth == 0 ||
		    tzi.DaylightDate.wMonth == 0)
		    break;

		ts = SYSTEMTIME2d_time(&tzi.StandardDate, dt);
		td = SYSTEMTIME2d_time(&tzi.DaylightDate, dt);

		if (td <= dt && dt <= ts)
		{
		    t = -tzi.DaylightBias * (60 * TicksPerSecond);
		    //printf("DST is in effect, %d\n", t);
		}
		else
		{
		    //printf("no DST\n");
		}
		break;

	    case TIME_ZONE_ID_UNKNOWN:
		// Daylight savings time not used in this time zone
		break;
	}
	return t;
    }
}

version (linux)
{

    private import std.c.linux.linux;

    d_time getUTCtime()
    {   timeval tv;

	//printf("getUTCtime()\n");
	if (gettimeofday(&tv, null))
	{   // Some error happened - try time() instead
	    return time(null) * TicksPerSecond;
	}

	return tv.tv_sec * cast(d_time)TicksPerSecond +
		(tv.tv_usec / (1000000 / cast(d_time)TicksPerSecond));
    }

    d_time getLocalTZA()
    {
	int t;

	time(&t);
	localtime(&t);	// this will set timezone
	return -(timezone * TicksPerSecond);
    }

    /*
     * Get daylight savings time adjust for time dt.
     */

    int DaylightSavingTA(d_time dt)
    {
	tm *tmp;
	int t;

	t = cast(int) (dt / TicksPerSecond);	// BUG: need range check
	tmp = localtime(&t);
	if (tmp.tm_isdst > 0)
	    // BUG: Assume daylight savings time is plus one hour.
	    return 60 * 60 * TicksPerSecond;

	return 0;
    }

}


/+ ====================== DOS File Time =============================== +/

typedef uint DosFileTime;

d_time toDtime(DosFileTime time)
{
    uint dt = cast(uint)time;

    if (dt == 0)
	return d_time_nan;

    int year = ((dt >> 25) & 0x7F) + 1980;
    int month = ((dt >> 21) & 0x0F) - 1;	// 0..12
    int dayofmonth = ((dt >> 16) & 0x1F);	// 0..31
    int hour = (dt >> 11) & 0x1F;		// 0..23
    int minute = (dt >> 5) & 0x3F;		// 0..59
    int second = (dt << 1) & 0x3E;		// 0..58 (in 2 second increments)

    d_time t;

    t = date.MakeDate(date.MakeDay(year, month, dayofmonth),
	    date.MakeTime(hour, minute, second, 0));

    assert(YearFromTime(t) == year);
    assert(MonthFromTime(t) == month);
    assert(DateFromTime(t) == dayofmonth);
    assert(HourFromTime(t) == hour);
    assert(MinFromTime(t) == minute);
    assert(SecFromTime(t) == second);

    t -= LocalTZA + DaylightSavingTA(t);

    return t;
}

DosFileTime toDosFileTime(d_time t)
{   uint dt;

    if (t == d_time_nan)
	return cast(DosFileTime)0;

    t += LocalTZA + DaylightSavingTA(t);

    uint year = YearFromTime(t);
    uint month = MonthFromTime(t);
    uint dayofmonth = DateFromTime(t);
    uint hour = HourFromTime(t);
    uint minute = MinFromTime(t);
    uint second = SecFromTime(t);

    dt = (year - 1980) << 25;
    dt |= ((month + 1) & 0x0F) << 21;
    dt |= (dayofmonth & 0x1F) << 16;
    dt |= (hour & 0x1F) << 11;
    dt |= (minute & 0x3F) << 5;
    dt |= (second >> 1) & 0x1F;

    return cast(DosFileTime)dt;
}
