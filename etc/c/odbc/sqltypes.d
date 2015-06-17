/**
Declarations for interfacing with the ODBC library.

Adapted with minimal changes from the work of David L. Davis
(refer to the $(WEB
forum.dlang.org/thread/cfk7ql$(DOLLAR)1p4n$(DOLLAR)1@digitaldaemon.com#post-cfk7ql:241p4n:241:40digitaldaemon.com,
original announcement)).

`etc.c.odbc.sqlext.d` corresponds to the `sqlext.h` C header file.

See_Also: $(LUCKY ODBC API Reference on MSN Online)
*/
module etc.c.odbc.sqltypes;

extern (Windows):

// * API declaration data types *
//alias void *HANDLE;

//alias ubyte   SQLCHAR;
alias char    SQLCHAR;
alias byte    SQLSCHAR;
alias ubyte   SQLDATE;
alias ubyte   SQLDECIMAL;
alias double  SQLDOUBLE;
alias double  SQLFLOAT;
alias int     SQLINTEGER;
alias ushort  SQLUINTEGER;
alias ubyte   SQLNUMERIC;
alias float   SQLREAL;
alias ubyte   SQLTIME;
alias ubyte   SQLTIMESTAMP;
alias ubyte   SQLVARCHAR;
alias void *  SQLPOINTER;
alias short   SQLSMALLINT;
alias ushort  SQLUSMALLINT;

// * function return type *
alias SQLSMALLINT SQLRETURN;

// * generic data structures *
alias void *    SQLHANDLE;
alias SQLHANDLE SQLHENV;
alias SQLHANDLE SQLHDBC;
alias SQLHANDLE SQLHSTMT;
alias SQLHANDLE SQLHDESC;

// * SQL portable types for C *
//alias ubyte  UCHAR;  // std.c.windows.windows has this alias
//alias char   UCHAR;
alias byte   SCHAR;
//alias SCHAR  SQLSCHAR;
alias uint   DWORD;
alias int    SDWORD;
alias short  SWORD;
alias uint   UDWORD;
alias ushort UWORD;
alias short  WORD;
//alias UDWORD SQLUINTEGER;
alias long   SLONG;
alias short  SSHORT;
alias ulong  ULONG;
alias ushort USHORT;
alias double SDOUBLE;
alias double LDOUBLE;
alias float  SFLOAT;
alias void*  PTR;
alias void*  HENV;
alias void*  HDBC;
alias void*  HSTMT;
alias short  RETCODE;
alias SQLPOINTER HWND;
alias HWND   SQLHWND;

// * transfer types for DATE, TIME, TIMESTAMP *
struct DATE_STRUCT
{
    SQLSMALLINT    year;
    SQLUSMALLINT   month;
    SQLUSMALLINT   day;
};

alias DATE_STRUCT SQL_DATE_STRUCT;

struct TIME_STRUCT
{
    SQLUSMALLINT hour;
    SQLUSMALLINT minute;
    SQLUSMALLINT second;
};

alias TIME_STRUCT SQL_TIME_STRUCT;

struct TIMESTAMP_STRUCT
{
    SQLSMALLINT    year;
    SQLUSMALLINT   month;
    SQLUSMALLINT   day;
    SQLUSMALLINT   hour;
    SQLUSMALLINT   minute;
    SQLUSMALLINT   second;
    SQLUINTEGER    fraction;
};

alias TIMESTAMP_STRUCT SQL_TIMESTAMP_STRUCT;

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
};

struct SQL_DAY_SECOND_STRUCT
{
    SQLUINTEGER day;
    SQLUINTEGER hour;
    SQLUINTEGER minute;
    SQLUINTEGER second;
    SQLUINTEGER fraction;
};

struct SQL_INTERVAL_STRUCT
{
    SQLINTERVAL interval_type;
    SQLSMALLINT interval_sign;

    union  intval {
        SQL_YEAR_MONTH_STRUCT year_month;
        SQL_DAY_SECOND_STRUCT day_second;
    };
};

// * internal representation of numeric data type *
const int SQL_MAX_NUMERIC_LEN =	16;
struct SQL_NUMERIC_STRUCT
{
    SQLCHAR  precision;
    SQLSCHAR scale;
    SQLCHAR  sign;    /* 1 if positive, 0 if negative */
    SQLCHAR[ SQL_MAX_NUMERIC_LEN ]  val;
};

/* size is 16 */
struct SQLGUID
{
    DWORD Data1;
    WORD Data2;
    WORD Data3;
    ubyte[ 8 ] Data4;
};

alias SQLGUID GUID;
alias uint    BOOKMARK;
alias ushort  SQLWCHAR;

version( UNICODE )
{
alias SQLWCHAR SQLTCHAR;
}
else
{
alias SQLCHAR SQLTCHAR;
} // end version( UNICODE )
