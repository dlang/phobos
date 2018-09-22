/**
Declarations for interfacing with the ODBC library.

Adapted with minimal changes from the work of David L. Davis
(refer to the $(HTTP
forum.dlang.org/post/cfk7ql$(DOLLAR)1p4n$(DOLLAR)1@digitaldaemon.com,
original announcement)).

`etc.c.odbc.sqlext.d` corresponds to the `sqlext.h` C header file.

See_Also: $(LINK2 https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/odbc-api-reference,
          ODBC API Reference on MSN Online)
*/
module etc.c.odbc.sqltypes;

extern (Windows):

// * API declaration data types *
//alias void *HANDLE;

//alias ubyte   SQLCHAR;
alias SQLCHAR      = char;
alias SQLSCHAR     = byte;
alias SQLDATE      = ubyte;
alias SQLDECIMAL   = ubyte;
alias SQLDOUBLE    = double;
alias SQLFLOAT     = double;
alias SQLINTEGER   = int;
alias SQLUINTEGER  = ushort;
alias SQLNUMERIC   = ubyte;
alias SQLREAL      = float;
alias SQLTIME      = ubyte;
alias SQLTIMESTAMP = ubyte;
alias SQLVARCHAR   = ubyte;
alias SQLPOINTER   = void*;
alias SQLSMALLINT   = short;
alias SQLUSMALLINT = ushort;

// * function return type *
alias SQLRETURN = SQLSMALLINT;

// * generic data structures *
alias SQLHANDLE = void*;
alias SQLHENV   = SQLHANDLE;
alias SQLHDBC   = SQLHANDLE;
alias SQLHSTMT  = SQLHANDLE;
alias SQLHDESC  = SQLHANDLE;

// * SQL portable types for C *
//alias ubyte  UCHAR;  // std.c.windows.windows has this alias
//alias char   UCHAR;
alias SCHAR   = byte;
//alias SCHAR  SQLSCHAR;
alias DWORD   = uint;
alias SDWORD  = int;
alias SWORD   = short;
alias UDWORD  = uint ;
alias UWORD   = ushort;
alias WORD    = short;
//alias UDWORD SQLUINTEGER;
alias SLONG   = long;
alias SSHORT  = short;
alias ULONG   = ulong;
alias USHORT  = ushort;
alias SDOUBLE = double;
alias LDOUBLE = double;
alias SFLOAT  = float;
alias PTR     = void*;
alias HENV    = void*;
alias HDBC    = void*;
alias HSTMT   = void*;
alias RETCODE = short;
alias HWND    = SQLPOINTER;
alias SQLHWND = HWND;

// * transfer types for DATE, TIME, TIMESTAMP *
struct DATE_STRUCT
{
    SQLSMALLINT    year;
    SQLUSMALLINT   month;
    SQLUSMALLINT   day;
}

alias SQL_DATE_STRUCT = DATE_STRUCT;

struct TIME_STRUCT
{
    SQLUSMALLINT hour;
    SQLUSMALLINT minute;
    SQLUSMALLINT second;
}

alias SQL_TIME_STRUCT = TIME_STRUCT;

struct TIMESTAMP_STRUCT
{
    SQLSMALLINT    year;
    SQLUSMALLINT   month;
    SQLUSMALLINT   day;
    SQLUSMALLINT   hour;
    SQLUSMALLINT   minute;
    SQLUSMALLINT   second;
    SQLUINTEGER    fraction;
}

alias SQL_TIMESTAMP_STRUCT = TIMESTAMP_STRUCT;

/+
 ' enumerations for DATETIME_INTERVAL_SUBCODE values for interval data types
 ' these values are from SQL-92
 +/
enum SQLINTERVAL
{
    SQL_IS_YEAR             = 1,
    SQL_IS_MONTH            = 2,
    SQL_IS_DAY              = 3,
    SQL_IS_HOUR             = 4,
    SQL_IS_MINUTE           = 5,
    SQL_IS_SECOND           = 6,
    SQL_IS_YEAR_TO_MONTH    = 7,
    SQL_IS_DAY_TO_HOUR      = 8,
    SQL_IS_DAY_TO_MINUTE    = 9,
    SQL_IS_DAY_TO_SECOND    = 10,
    SQL_IS_HOUR_TO_MINUTE   = 11,
    SQL_IS_HOUR_TO_SECOND   = 12,
    SQL_IS_MINUTE_TO_SECOND = 13
}

struct SQL_YEAR_MONTH_STRUCT
{
    SQLUINTEGER year;
    SQLUINTEGER month;
}

struct SQL_DAY_SECOND_STRUCT
{
    SQLUINTEGER day;
    SQLUINTEGER hour;
    SQLUINTEGER minute;
    SQLUINTEGER second;
    SQLUINTEGER fraction;
}

struct SQL_INTERVAL_STRUCT
{
    SQLINTERVAL interval_type;
    SQLSMALLINT interval_sign;

    union  intval {
        SQL_YEAR_MONTH_STRUCT year_month;
        SQL_DAY_SECOND_STRUCT day_second;
    }
}

// * internal representation of numeric data type *
const int SQL_MAX_NUMERIC_LEN = 16;
struct SQL_NUMERIC_STRUCT
{
    SQLCHAR  precision;
    SQLSCHAR scale;
    SQLCHAR  sign;    /* 1 if positive, 0 if negative */
    SQLCHAR[ SQL_MAX_NUMERIC_LEN ]  val;
}

/* size is 16 */
struct SQLGUID
{
    DWORD Data1;
    WORD Data2;
    WORD Data3;
    ubyte[ 8 ] Data4;
}

alias GUID     = SQLGUID;
alias BOOKMARK = uint;
alias SQLWCHAR = ushort;

version (UNICODE)
{
alias SQLTCHAR = SQLWCHAR;
}
else
{
alias SQLTCHAR = SQLCHAR;
} // end version (UNICODE)
