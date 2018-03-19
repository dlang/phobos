/**
Declarations for interfacing with the ODBC library.

Adapted with minimal changes from the work of David L. Davis
(refer to the $(HTTP
forum.dlang.org/post/cfk7ql$(DOLLAR)1p4n$(DOLLAR)1@digitaldaemon.com,
original announcement)).

`etc.c.odbc.sqlext` corresponds to the `sqlext.h` C header file.

See_Also: $(LINK2 https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/odbc-api-reference,
            ODBC API Reference on MSN Online)
*/

module etc.c.odbc.sqlext;

import etc.c.odbc.sql;
import etc.c.odbc.sqltypes;

extern (Windows):

// * generally useful constants *
enum int SQL_SPEC_MAJOR  = 3;           /* Major version of specification  */
enum int SQL_SPEC_MINOR  = 51;          /* Minor version of specification  */
immutable char[] SQL_SPEC_STRING = "03.51";  /* String constant for version     */

enum int SQL_SQLSTATE_SIZE  = 5;        /* size of SQLSTATE */
enum int SQL_MAX_DSN_LENGTH = 32;       /* maximum data source name size */

enum int SQL_MAX_OPTION_STRING_LENGTH = 256;

// * return code SQL_NO_DATA_FOUND is the same as SQL_NO_DATA *
//enum int SQL_NO_DATA_FOUND = 100;
enum int SQL_NO_DATA_FOUND = SQL_NO_DATA;

// * an end handle type *
enum int SQL_HANDLE_SENV = 5;

// * env attribute *
enum : uint
{
    SQL_ATTR_ODBC_VERSION       = 200,
    SQL_ATTR_CONNECTION_POOLING = 201,
    SQL_ATTR_CP_MATCH           = 202,

    // * values for SQL_ATTR_CONNECTION_POOLING *
    SQL_CP_OFF                  = 0UL,
    SQL_CP_ONE_PER_DRIVER       = 1UL,
    SQL_CP_ONE_PER_HENV         = 2UL,
    SQL_CP_DEFAULT              = SQL_CP_OFF,

    // * values for SQL_ATTR_CP_MATCH *
    SQL_CP_STRICT_MATCH         = 0UL,
    SQL_CP_RELAXED_MATCH        = 1UL,
    SQL_CP_MATCH_DEFAULT        = SQL_CP_STRICT_MATCH,

    // * values for SQL_ATTR_ODBC_VERSION *
    SQL_OV_ODBC2                = 2UL,
    SQL_OV_ODBC3                = 3UL
}

// * connection attributes *
enum
{
    SQL_ACCESS_MODE       = 101,
    SQL_AUTOCOMMIT        = 102,
    SQL_LOGIN_TIMEOUT     = 103,
    SQL_OPT_TRACE         = 104,
    SQL_OPT_TRACEFILE     = 105,
    SQL_TRANSLATE_DLL     = 106,
    SQL_TRANSLATE_OPTION  = 107,
    SQL_TXN_ISOLATION     = 108,
    SQL_CURRENT_QUALIFIER = 109,
    SQL_ODBC_CURSORS      = 110,
    SQL_QUIET_MODE        = 111,
    SQL_PACKET_SIZE       = 112
}

// * connection attributes with new names *
enum
{
    SQL_ATTR_ACCESS_MODE         = SQL_ACCESS_MODE,
    SQL_ATTR_AUTOCOMMIT          = SQL_AUTOCOMMIT,
    SQL_ATTR_CONNECTION_TIMEOUT  = 113,
    SQL_ATTR_CURRENT_CATALOG     = SQL_CURRENT_QUALIFIER,
    SQL_ATTR_DISCONNECT_BEHAVIOR = 114,
    SQL_ATTR_ENLIST_IN_DTC       = 1207,
    SQL_ATTR_ENLIST_IN_XA        = 1208,
    SQL_ATTR_LOGIN_TIMEOUT       = SQL_LOGIN_TIMEOUT,
    SQL_ATTR_ODBC_CURSORS        = SQL_ODBC_CURSORS,
    SQL_ATTR_PACKET_SIZE         = SQL_PACKET_SIZE,
    SQL_ATTR_QUIET_MODE          = SQL_QUIET_MODE,
    SQL_ATTR_TRACE               = SQL_OPT_TRACE,
    SQL_ATTR_TRACEFILE           = SQL_OPT_TRACEFILE,
    SQL_ATTR_TRANSLATE_LIB       = SQL_TRANSLATE_DLL,
    SQL_ATTR_TRANSLATE_OPTION    = SQL_TRANSLATE_OPTION,
    SQL_ATTR_TXN_ISOLATION       = SQL_TXN_ISOLATION
}

// * GetConnectAttr only *
enum int SQL_ATTR_CONNECTION_DEAD   = 1209;

/+
 ' ODBC Driver Manager sets this connection attribute to a unicode driver
 ' (which supports SQLConnectW) when the application is an ANSI application
 ' (which calls SQLConnect, SQLDriverConnect, or SQLBrowseConnect).
 ' This is SetConnectAttr only and application does not set this attribute
 ' This attribute was introduced because some unicode driver's some APIs may
 ' need to behave differently on ANSI or Unicode applications. A unicode
 ' driver, which  has same behavior for both ANSI or Unicode applications,
 ' should return SQL_ERROR when the driver manager sets this connection
 ' attribute. When a unicode driver returns SQL_SUCCESS on this attribute,
 ' the driver manager treates ANSI and Unicode connections differently in
 ' connection pooling.
+/
enum int SQL_ATTR_ANSI_APP = 115;


// * SQL_ACCESS_MODE options *
enum : uint
{
    SQL_MODE_READ_WRITE = 0UL,
    SQL_MODE_READ_ONLY  = 1UL,
    SQL_MODE_DEFAULT    = SQL_MODE_READ_WRITE
}

// * SQL_AUTOCOMMIT options *
enum : uint
{
    SQL_AUTOCOMMIT_OFF     = 0UL,
    SQL_AUTOCOMMIT_ON      = 1UL,
    SQL_AUTOCOMMIT_DEFAULT = SQL_AUTOCOMMIT_ON
}

// * SQL_LOGIN_TIMEOUT options *
enum uint SQL_LOGIN_TIMEOUT_DEFAULT  = 15UL;

// * SQL_OPT_TRACE options *
enum : uint
{
    SQL_OPT_TRACE_OFF          = 0UL,
    SQL_OPT_TRACE_ON           = 1UL,
    SQL_OPT_TRACE_DEFAULT      = SQL_OPT_TRACE_OFF
}

immutable char[] SQL_OPT_TRACE_FILE_DEFAULT = r"\SQL.LOG";

// * SQL_ODBC_CURSORS options *
enum : uint
{
    SQL_CUR_USE_IF_NEEDED = 0UL,
    SQL_CUR_USE_ODBC      = 1UL,
    SQL_CUR_USE_DRIVER    = 2UL,
    SQL_CUR_DEFAULT       = SQL_CUR_USE_DRIVER
}

enum
{
    // * values for SQL_ATTR_DISCONNECT_BEHAVIOR *
    SQL_DB_RETURN_TO_POOL = 0UL,
    SQL_DB_DISCONNECT     = 1UL,
    SQL_DB_DEFAULT        = SQL_DB_RETURN_TO_POOL,

    // * values for SQL_ATTR_ENLIST_IN_DTC *
    SQL_DTC_DONE          = 0L

}

// * values for SQL_ATTR_CONNECTION_DEAD *
enum int SQL_CD_TRUE  = 1L; // * Connection is closed/dead    *
enum int SQL_CD_FALSE = 0L; // * Connection is open/available *

// * values for SQL_ATTR_ANSI_APP ( ODBC v3.51 ) *
enum int SQL_AA_TRUE  = 1L; // * the application is an ANSI app   *
enum int SQL_AA_FALSE = 0L; // * the application is a Unicode app *

// * statement attributes *
enum
{
    SQL_QUERY_TIMEOUT   = 0,
    SQL_MAX_ROWS        = 1,
    SQL_NOSCAN          = 2,
    SQL_MAX_LENGTH      = 3,
    SQL_ASYNC_ENABLE    = 4,   // * same as SQL_ATTR_ASYNC_ENABLE *
    SQL_BIND_TYPE       = 5,
    SQL_CURSOR_TYPE     = 6,
    SQL_CONCURRENCY     = 7,
    SQL_KEYSET_SIZE     = 8,
    SQL_ROWSET_SIZE     = 9,
    SQL_SIMULATE_CURSOR = 10,
    SQL_RETRIEVE_DATA   = 11,
    SQL_USE_BOOKMARKS   = 12,
    SQL_GET_BOOKMARK    = 13,  // * GetStmtOption Only *
    SQL_ROW_NUMBER      = 14   // * GetStmtOption Only *
}

// * statement attributes for ODBC 3.0 *
enum
{
    SQL_ATTR_ASYNC_ENABLE          = 4,
    SQL_ATTR_CONCURRENCY           = SQL_CONCURRENCY,
    SQL_ATTR_CURSOR_TYPE           = SQL_CURSOR_TYPE,
    SQL_ATTR_ENABLE_AUTO_IPD       = 15,
    SQL_ATTR_FETCH_BOOKMARK_PTR    = 16,
    SQL_ATTR_KEYSET_SIZE           = SQL_KEYSET_SIZE,
    SQL_ATTR_MAX_LENGTH            = SQL_MAX_LENGTH,
    SQL_ATTR_MAX_ROWS              = SQL_MAX_ROWS,
    SQL_ATTR_NOSCAN                = SQL_NOSCAN,
    SQL_ATTR_PARAM_BIND_OFFSET_PTR = 17,
    SQL_ATTR_PARAM_BIND_TYPE       = 18,
    SQL_ATTR_PARAM_OPERATION_PTR   = 19,
    SQL_ATTR_PARAM_STATUS_PTR      = 20,
    SQL_ATTR_PARAMS_PROCESSED_PTR  = 21,
    SQL_ATTR_PARAMSET_SIZE         = 22,
    SQL_ATTR_QUERY_TIMEOUT         = SQL_QUERY_TIMEOUT,
    SQL_ATTR_RETRIEVE_DATA         = SQL_RETRIEVE_DATA,
    SQL_ATTR_ROW_BIND_OFFSET_PTR   = 23,
    SQL_ATTR_ROW_BIND_TYPE         = SQL_BIND_TYPE,
    SQL_ATTR_ROW_NUMBER            = SQL_ROW_NUMBER,    // * GetStmtAttr *
    SQL_ATTR_ROW_OPERATION_PTR     = 24,
    SQL_ATTR_ROW_STATUS_PTR        = 25,
    SQL_ATTR_ROWS_FETCHED_PTR      = 26,
    SQL_ATTR_ROW_ARRAY_SIZE        = 27,
    SQL_ATTR_SIMULATE_CURSOR       = SQL_SIMULATE_CURSOR,
    SQL_ATTR_USE_BOOKMARKS         = SQL_USE_BOOKMARKS
}

// * whether an attribute is a pointer or not *
enum
{
    SQL_IS_POINTER   = (-4),
    SQL_IS_UINTEGER  = (-5),
    SQL_IS_INTEGER   = (-6),
    SQL_IS_USMALLINT = (-7),
    SQL_IS_SMALLINT  = (-8)
}

// * the value of SQL_ATTR_PARAM_BIND_TYPE *
enum : uint
{
    SQL_PARAM_BIND_BY_COLUMN    = 0UL,
    SQL_PARAM_BIND_TYPE_DEFAULT = SQL_PARAM_BIND_BY_COLUMN
}

// * SQL_QUERY_TIMEOUT options *
enum uint SQL_QUERY_TIMEOUT_DEFAULT = 0UL;

// * SQL_MAX_ROWS options *
enum uint SQL_MAX_ROWS_DEFAULT = 0UL;

// * SQL_NOSCAN options *
enum : uint
{
    SQL_NOSCAN_OFF     = 0UL,     /* 1.0 FALSE */
    SQL_NOSCAN_ON      = 1UL,     /* 1.0 TRUE  */
    SQL_NOSCAN_DEFAULT = SQL_NOSCAN_OFF
}

// * SQL_MAX_LENGTH options *
enum uint SQL_MAX_LENGTH_DEFAULT = 0UL;

// * values for SQL_ATTR_ASYNC_ENABLE *
enum : uint
{
    SQL_ASYNC_ENABLE_OFF     = 0UL,
    SQL_ASYNC_ENABLE_ON      = 1UL,
    SQL_ASYNC_ENABLE_DEFAULT = SQL_ASYNC_ENABLE_OFF
}

// * SQL_BIND_TYPE options *
enum : uint
{
    SQL_BIND_BY_COLUMN    = 0UL,
    SQL_BIND_TYPE_DEFAULT = SQL_BIND_BY_COLUMN  /* Default value */
}

// * SQL_CONCURRENCY options *
enum
{
    SQL_CONCUR_READ_ONLY = 1,
    SQL_CONCUR_LOCK      = 2,
    SQL_CONCUR_ROWVER    = 3,
    SQL_CONCUR_VALUES    = 4,
    SQL_CONCUR_DEFAULT   = SQL_CONCUR_READ_ONLY  /* Default value */
}

// * SQL_CURSOR_TYPE options *
enum : uint
{
    SQL_CURSOR_FORWARD_ONLY  = 0UL,
    SQL_CURSOR_KEYSET_DRIVEN = 1UL,
    SQL_CURSOR_DYNAMIC       = 2UL,
    SQL_CURSOR_STATIC        = 3UL,
    SQL_CURSOR_TYPE_DEFAULT  = SQL_CURSOR_FORWARD_ONLY  /* Default value */
}

// * SQL_ROWSET_SIZE options *
enum uint SQL_ROWSET_SIZE_DEFAULT  = 1UL;

// * SQL_KEYSET_SIZE options *
enum uint SQL_KEYSET_SIZE_DEFAULT  = 0UL;

// * SQL_SIMULATE_CURSOR options *
enum : uint
{
    SQL_SC_NON_UNIQUE = 0UL,
    SQL_SC_TRY_UNIQUE = 1UL,
    SQL_SC_UNIQUE     = 2UL
}

// * SQL_RETRIEVE_DATA options *
enum : uint
{
    SQL_RD_OFF     = 0UL,
    SQL_RD_ON      = 1UL,
    SQL_RD_DEFAULT = SQL_RD_ON
}

// * SQL_USE_BOOKMARKS options *
enum : uint
{
    SQL_UB_OFF     = 0UL,
    SQL_UB_ON      = 01UL,
    SQL_UB_DEFAULT = SQL_UB_OFF
}

// * New values for SQL_USE_BOOKMARKS attribute *
enum : uint
{
    SQL_UB_FIXED    = SQL_UB_ON,
    SQL_UB_VARIABLE = 2UL
}

/* SQLColAttributes defines */
enum
{
    SQL_COLUMN_COUNT          = 0,
    SQL_COLUMN_NAME           = 1,
    SQL_COLUMN_TYPE           = 2,
    SQL_COLUMN_LENGTH         = 3,
    SQL_COLUMN_PRECISION      = 4,
    SQL_COLUMN_SCALE          = 5,
    SQL_COLUMN_DISPLAY_SIZE   = 6,
    SQL_COLUMN_NULLABLE       = 7,
    SQL_COLUMN_UNSIGNED       = 8,
    SQL_COLUMN_MONEY          = 9,
    SQL_COLUMN_UPDATABLE      = 10,
    SQL_COLUMN_AUTO_INCREMENT = 11,
    SQL_COLUMN_CASE_SENSITIVE = 12,
    SQL_COLUMN_SEARCHABLE     = 13,
    SQL_COLUMN_TYPE_NAME      = 14,
    SQL_COLUMN_TABLE_NAME     = 15,
    SQL_COLUMN_OWNER_NAME     = 16,
    SQL_COLUMN_QUALIFIER_NAME = 17,
    SQL_COLUMN_LABEL          = 18,
    SQL_COLATT_OPT_MAX        = SQL_COLUMN_LABEL
}

// * extended descriptor field *
enum
{
    SQL_DESC_ARRAY_SIZE                  = 20,
    SQL_DESC_ARRAY_STATUS_PTR            = 21,
    SQL_DESC_AUTO_UNIQUE_VALUE           = SQL_COLUMN_AUTO_INCREMENT,
    SQL_DESC_BASE_COLUMN_NAME            = 22,
    SQL_DESC_BASE_TABLE_NAME             = 23,
    SQL_DESC_BIND_OFFSET_PTR             = 24,
    SQL_DESC_BIND_TYPE                   = 25,
    SQL_DESC_CASE_SENSITIVE              = SQL_COLUMN_CASE_SENSITIVE,
    SQL_DESC_CATALOG_NAME                = SQL_COLUMN_QUALIFIER_NAME,
    SQL_DESC_CONCISE_TYPE                = SQL_COLUMN_TYPE,
    SQL_DESC_DATETIME_INTERVAL_PRECISION = 26,
    SQL_DESC_DISPLAY_SIZE                = SQL_COLUMN_DISPLAY_SIZE,
    SQL_DESC_FIXED_PREC_SCALE            = SQL_COLUMN_MONEY,
    SQL_DESC_LABEL                       = SQL_COLUMN_LABEL,
    SQL_DESC_LITERAL_PREFIX              = 27,
    SQL_DESC_LITERAL_SUFFIX              = 28,
    SQL_DESC_LOCAL_TYPE_NAME             = 29,
    SQL_DESC_MAXIMUM_SCALE               = 30,
    SQL_DESC_MINIMUM_SCALE               = 31,
    SQL_DESC_NUM_PREC_RADIX              = 32,
    SQL_DESC_PARAMETER_TYPE              = 33,
    SQL_DESC_ROWS_PROCESSED_PTR          = 34,
    SQL_DESC_SCHEMA_NAME                 = SQL_COLUMN_OWNER_NAME,
    SQL_DESC_SEARCHABLE                  = SQL_COLUMN_SEARCHABLE,
    SQL_DESC_TYPE_NAME                   = SQL_COLUMN_TYPE_NAME,
    SQL_DESC_TABLE_NAME                  = SQL_COLUMN_TABLE_NAME,
    SQL_DESC_UNSIGNED                    = SQL_COLUMN_UNSIGNED,
    SQL_DESC_UPDATABLE                   = SQL_COLUMN_UPDATABLE
}

// ODBCVER >= 0x0350
enum int SQL_DESC_ROWVER = 35;

// * defines for diagnostics fields *
enum
{
    SQL_DIAG_CURSOR_ROW_COUNT = (-1249),
    SQL_DIAG_ROW_NUMBER       = (-1248),
    SQL_DIAG_COLUMN_NUMBER    = (-1247)
}

// * SQL extended datatypes *
enum
{
    SQL_DATE          = 9,
    SQL_INTERVAL      = 10,
    SQL_TIME          = 10,
    SQL_TIMESTAMP     = 11,
    SQL_LONGVARCHAR   = (-1),
    SQL_BINARY        = (-2),
    SQL_VARBINARY     = (-3),
    SQL_LONGVARBINARY = (-4),
    SQL_BIGINT        = (-5),
    SQL_TINYINT       = (-6),
    SQL_BIT           = (-7),

    // ODBCVER >= 0x0350
    SQL_GUID          = (-11)
}

enum
{
    // * interval code *
    SQL_CODE_YEAR                 = 1,
    SQL_CODE_MONTH                = 2,
    SQL_CODE_DAY                  = 3,
    SQL_CODE_HOUR                 = 4,
    SQL_CODE_MINUTE               = 5,
    SQL_CODE_SECOND               = 6,
    SQL_CODE_YEAR_TO_MONTH        = 7,
    SQL_CODE_DAY_TO_HOUR          = 8,
    SQL_CODE_DAY_TO_MINUTE        = 9,
    SQL_CODE_DAY_TO_SECOND        = 10,
    SQL_CODE_HOUR_TO_MINUTE       = 11,
    SQL_CODE_HOUR_TO_SECOND       = 12,
    SQL_CODE_MINUTE_TO_SECOND     = 13,

    SQL_INTERVAL_YEAR             = (100 + SQL_CODE_YEAR),
    SQL_INTERVAL_MONTH            = (100 + SQL_CODE_MONTH),
    SQL_INTERVAL_DAY              = (100 + SQL_CODE_DAY),
    SQL_INTERVAL_HOUR             = (100 + SQL_CODE_HOUR),
    SQL_INTERVAL_MINUTE           = (100 + SQL_CODE_MINUTE),
    SQL_INTERVAL_SECOND           = (100 + SQL_CODE_SECOND),
    SQL_INTERVAL_YEAR_TO_MONTH    = (100 + SQL_CODE_YEAR_TO_MONTH),
    SQL_INTERVAL_DAY_TO_HOUR      = (100 + SQL_CODE_DAY_TO_HOUR),
    SQL_INTERVAL_DAY_TO_MINUTE    = (100 + SQL_CODE_DAY_TO_MINUTE),
    SQL_INTERVAL_DAY_TO_SECOND    = (100 + SQL_CODE_DAY_TO_SECOND),
    SQL_INTERVAL_HOUR_TO_MINUTE   = (100 + SQL_CODE_HOUR_TO_MINUTE),
    SQL_INTERVAL_HOUR_TO_SECOND   = (100 + SQL_CODE_HOUR_TO_SECOND),
    SQL_INTERVAL_MINUTE_TO_SECOND = (100 + SQL_CODE_MINUTE_TO_SECOND),
}

// * The previous definitions for SQL_UNICODE_ are historical and obsolete *
enum
{
    SQL_WCHAR               = (-8),
    SQL_WVARCHAR            = (-9),
    SQL_WLONGVARCHAR        = (-10),
    SQL_C_WCHAR             = SQL_WCHAR,
    SQL_UNICODE             = SQL_WCHAR,
    SQL_UNICODE_VARCHAR     = SQL_WVARCHAR,
    SQL_UNICODE_LONGVARCHAR = SQL_WLONGVARCHAR,
    SQL_UNICODE_CHAR        = SQL_WCHAR
}

// * C datatype to SQL datatype mapping   SQL types *
enum
{
                                         /* ------------------------------- */
    SQL_C_CHAR          = SQL_CHAR,      /* CHAR, VARCHAR, DECIMAL, NUMERIC */
    SQL_C_LONG          = SQL_INTEGER,   /* INTEGER                         */
    SQL_C_SHORT         = SQL_SMALLINT,  /* SMALLINT                        */
    SQL_C_FLOAT         = SQL_REAL,      /* REAL                            */
    SQL_C_DOUBLE        = SQL_DOUBLE,    /* FLOAT, DOUBLE                   */
    SQL_C_NUMERIC       = SQL_NUMERIC,
    SQL_C_DEFAULT       = 99,
    SQL_SIGNED_OFFSET   = (-20),
    SQL_UNSIGNED_OFFSET = (-22)
}

// * C datatype to SQL datatype mapping *
enum
{
    SQL_C_DATE      = SQL_DATE,
    SQL_C_TIME      = SQL_TIME,
    SQL_C_TIMESTAMP = SQL_TIMESTAMP
}

enum
{
    SQL_C_TYPE_DATE                 = SQL_TYPE_DATE,
    SQL_C_TYPE_TIME                 = SQL_TYPE_TIME,
    SQL_C_TYPE_TIMESTAMP            = SQL_TYPE_TIMESTAMP,
    SQL_C_INTERVAL_YEAR             = SQL_INTERVAL_YEAR,
    SQL_C_INTERVAL_MONTH            = SQL_INTERVAL_MONTH,
    SQL_C_INTERVAL_DAY              = SQL_INTERVAL_DAY,
    SQL_C_INTERVAL_HOUR             = SQL_INTERVAL_HOUR,
    SQL_C_INTERVAL_MINUTE           = SQL_INTERVAL_MINUTE,
    SQL_C_INTERVAL_SECOND           = SQL_INTERVAL_SECOND,
    SQL_C_INTERVAL_YEAR_TO_MONTH    = SQL_INTERVAL_YEAR_TO_MONTH,
    SQL_C_INTERVAL_DAY_TO_HOUR      = SQL_INTERVAL_DAY_TO_HOUR,
    SQL_C_INTERVAL_DAY_TO_MINUTE    = SQL_INTERVAL_DAY_TO_MINUTE,
    SQL_C_INTERVAL_DAY_TO_SECOND    = SQL_INTERVAL_DAY_TO_SECOND,
    SQL_C_INTERVAL_HOUR_TO_MINUTE   = SQL_INTERVAL_HOUR_TO_MINUTE,
    SQL_C_INTERVAL_HOUR_TO_SECOND   = SQL_INTERVAL_HOUR_TO_SECOND,
    SQL_C_INTERVAL_MINUTE_TO_SECOND = SQL_INTERVAL_MINUTE_TO_SECOND
}

enum
{
    SQL_C_BINARY      = SQL_BINARY,
    SQL_C_BIT         = SQL_BIT,
    SQL_C_SBIGINT     = (SQL_BIGINT+SQL_SIGNED_OFFSET),      /* SIGNED   BIGINT   */
    SQL_C_UBIGINT     = (SQL_BIGINT+SQL_UNSIGNED_OFFSET),    /* UNSIGNED BIGINT   */
    SQL_C_TINYINT     = SQL_TINYINT,
    SQL_C_SLONG       = (SQL_C_LONG + SQL_SIGNED_OFFSET),    /* SIGNED INTEGER    */
    SQL_C_SSHORT      = (SQL_C_SHORT + SQL_SIGNED_OFFSET),   /* SIGNED SMALLINT   */
    SQL_C_STINYINT    = (SQL_TINYINT + SQL_SIGNED_OFFSET),   /* SIGNED TINYINT    */
    SQL_C_ULONG       = (SQL_C_LONG + SQL_UNSIGNED_OFFSET),  /* UNSIGNED INTEGER  */
    SQL_C_USHORT      = (SQL_C_SHORT + SQL_UNSIGNED_OFFSET), /* UNSIGNED SMALLINT */
    SQL_C_UTINYINT    = (SQL_TINYINT + SQL_UNSIGNED_OFFSET), /* UNSIGNED TINYINT  */
    SQL_C_BOOKMARK    = SQL_C_ULONG,                         /* BOOKMARK          */
    SQL_C_VARBOOKMARK = SQL_C_BINARY,

    // ODBCVER >= 0x0350
    SQL_C_GUID        = SQL_GUID                             /* GUID              */
}

enum int SQL_TYPE_NULL =  0;

// * define for SQL_DIAG_ROW_NUMBER and SQL_DIAG_COLUMN_NUMBER *
enum : uint
{
    SQL_NO_ROW_NUMBER         = (-1),
    SQL_NO_COLUMN_NUMBER      = (-1),
    SQL_ROW_NUMBER_UNKNOWN    = (-2),
    SQL_COLUMN_NUMBER_UNKNOWN = (-2)
}

// * SQLBindParameter extensions *
enum uint SQL_DEFAULT_PARAM = (-5);
enum uint SQL_IGNORE        = (-6);
enum uint SQL_COLUMN_IGNORE = SQL_IGNORE;

enum : uint
{
    SQL_LEN_DATA_AT_EXEC_OFFSET  = (-100),
}

uint SQL_LEN_DATA_AT_EXEC()
(
    uint length
)
{
    return ( ( -1 * length ) + cast(uint) SQL_LEN_DATA_AT_EXEC_OFFSET );
}

// * binary length for driver specific attributes *
enum uint SQL_LEN_BINARY_ATTR_OFFSET  = (-100);

uint SQL_LEN_BINARY_ATTR()
(
    uint length
)
{
    return ( ( -1 * length ) + cast(uint) SQL_LEN_BINARY_ATTR_OFFSET );
}

// * Defines used by Driver Manager when mapping SQLSetParam to SQLBindParameter *
enum int SQL_PARAM_TYPE_DEFAULT = SQL_PARAM_INPUT_OUTPUT;
enum int SQL_SETPARAM_VALUE_MAX = (-1L);

// ODBCVER < 0x0300
enum int SQL_COLUMN_DRIVER_START = 1000;

enum int SQL_COLATT_OPT_MIN = SQL_COLUMN_COUNT;

// * SQLColAttributes subdefines for SQL_COLUMN_UPDATABLE *
enum
{
    SQL_ATTR_READONLY          = 0,
    SQL_ATTR_WRITE             = 1,
    SQL_ATTR_READWRITE_UNKNOWN = 2
}

// * SQLColAttributes subdefines for SQL_COLUMN_SEARCHABLE *
// * These are also used by SQLGetInfo *
enum
{
    SQL_UNSEARCHABLE    = 0,
    SQL_LIKE_ONLY       = 1,
    SQL_ALL_EXCEPT_LIKE = 2,
    SQL_SEARCHABLE      = 3,
    SQL_PRED_SEARCHABLE = SQL_SEARCHABLE
}

// * New defines for SEARCHABLE column in SQLGetTypeInfo *
enum
{
    SQL_COL_PRED_CHAR  = SQL_LIKE_ONLY,
    SQL_COL_PRED_BASIC = SQL_ALL_EXCEPT_LIKE
}

// * Special return values for SQLGetData *
enum uint SQL_NO_TOTAL = (-4);

/********************************************/
/* SQLGetFunctions: additional values for   */
/* fFunction to represent functions that    */
/* are not in the X/Open spec.              */
/********************************************/
enum
{
    SQL_API_SQLALLOCHANDLESTD   = 73,
    SQL_API_SQLBULKOPERATIONS   = 24,
    SQL_API_SQLBINDPARAMETER    = 72,
    SQL_API_SQLBROWSECONNECT    = 55,
    SQL_API_SQLCOLATTRIBUTES    = 6,
    SQL_API_SQLCOLUMNPRIVILEGES = 56,
    SQL_API_SQLDESCRIBEPARAM    = 58,
    SQL_API_SQLDRIVERCONNECT    = 41,
    SQL_API_SQLDRIVERS          = 71,
    SQL_API_SQLEXTENDEDFETCH    = 59,
    SQL_API_SQLFOREIGNKEYS      = 60,
    SQL_API_SQLMORERESULTS      = 61,
    SQL_API_SQLNATIVESQL        = 62,
    SQL_API_SQLNUMPARAMS        = 63,
    SQL_API_SQLPARAMOPTIONS     = 64,
    SQL_API_SQLPRIMARYKEYS      = 65,
    SQL_API_SQLPROCEDURECOLUMNS = 66,
    SQL_API_SQLPROCEDURES       = 67,
    SQL_API_SQLSETPOS           = 68,
    SQL_API_SQLSETSCROLLOPTIONS = 69,
    SQL_API_SQLTABLEPRIVILEGES  = 70
}

/+----------------------------------------------+
 ' SQL_API_ODBC3_ALL_FUNCTIONS                  '
 ' This returns a bitmap, which allows us to    '
 ' handle the higher-valued function numbers.   '
 ' Use  SQL_FUNC_EXISTS(bitmap,function_number) '
 ' to determine if the function exists.         '
 +----------------------------------------------+/
enum
{
    SQL_API_ODBC3_ALL_FUNCTIONS      = 999,
    SQL_API_ODBC3_ALL_FUNCTIONS_SIZE = 250, /* array of 250 words */
}

//SQL_FUNC_EXISTS(pfExists, uwAPI) ((*(((UWORD*) (pfExists)) + ((uwAPI) >> 4))
//                & (1 << ((uwAPI) & 0x000F)) ) ? SQL_TRUE : SQL_FALSE )

/+-----------------------------------------------+
 ' ODBC 3.0 SQLGetInfo values that are not part  '
 ' of the X/Open standard at this time.   X/Open '
 ' standard values are in sql.h.                 '
 +-----------------------------------------------+/
enum
{
    SQL_ACTIVE_ENVIRONMENTS             = 116,
    SQL_ALTER_DOMAIN                    = 117,
    SQL_SQL_CONFORMANCE                 = 118,
    SQL_DATETIME_LITERALS               = 119,
    SQL_ASYNC_MODE                      = 10_021, /* new X/Open spec */
    SQL_BATCH_ROW_COUNT                 = 120,
    SQL_BATCH_SUPPORT                   = 121,
    SQL_QUALIFIER_LOCATION              = 114,
    SQL_QUALIFIER_NAME_SEPARATOR        = 41,
    SQL_QUALIFIER_TERM                  = 42,
    SQL_QUALIFIER_USAGE                 = 92,
    SQL_CATALOG_LOCATION                = SQL_QUALIFIER_LOCATION,
    SQL_CATALOG_NAME_SEPARATOR          = SQL_QUALIFIER_NAME_SEPARATOR,
    SQL_CATALOG_TERM                    = SQL_QUALIFIER_TERM,
    SQL_CATALOG_USAGE                   = SQL_QUALIFIER_USAGE,
    SQL_CONVERT_WCHAR                   = 122,
    SQL_CONVERT_INTERVAL_DAY_TIME       = 123,
    SQL_CONVERT_INTERVAL_YEAR_MONTH     = 124,
    SQL_CONVERT_WLONGVARCHAR            = 125,
    SQL_CONVERT_WVARCHAR                = 126,
    SQL_CREATE_ASSERTION                = 127,
    SQL_CREATE_CHARACTER_SET            = 128,
    SQL_CREATE_COLLATION                = 129,
    SQL_CREATE_DOMAIN                   = 130,
    SQL_CREATE_SCHEMA                   = 131,
    SQL_CREATE_TABLE                    = 132,
    SQL_CREATE_TRANSLATION              = 133,
    SQL_CREATE_VIEW                     = 134,
    SQL_DRIVER_HDESC                    = 135,
    SQL_DROP_ASSERTION                  = 136,
    SQL_DROP_CHARACTER_SET              = 137,
    SQL_DROP_COLLATION                  = 138,
    SQL_DROP_DOMAIN                     = 139,
    SQL_DROP_SCHEMA                     = 140,
    SQL_DROP_TABLE                      = 141,
    SQL_DROP_TRANSLATION                = 142,
    SQL_DROP_VIEW                       = 143,
    SQL_DYNAMIC_CURSOR_ATTRIBUTES1      = 144,
    SQL_DYNAMIC_CURSOR_ATTRIBUTES2      = 145,
    SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES1 = 146,
    SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES2 = 147,
    SQL_INDEX_KEYWORDS                  = 148,
    SQL_INFO_SCHEMA_VIEWS               = 149,
    SQL_KEYSET_CURSOR_ATTRIBUTES1       = 150,
    SQL_KEYSET_CURSOR_ATTRIBUTES2       = 151,
    SQL_MAX_ASYNC_CONCURRENT_STATEMENTS = 10_022, /* new X/Open spec */
    SQL_ODBC_INTERFACE_CONFORMANCE      = 152,
    SQL_PARAM_ARRAY_ROW_COUNTS          = 153,
    SQL_PARAM_ARRAY_SELECTS             = 154,
    SQL_OWNER_TERM                      = 39,
    SQL_OWNER_USAGE                     = 91,
    SQL_SCHEMA_TERM                     = SQL_OWNER_TERM,
    SQL_SCHEMA_USAGE                    = SQL_OWNER_USAGE,
    SQL_SQL92_DATETIME_FUNCTIONS        = 155,
    SQL_SQL92_FOREIGN_KEY_DELETE_RULE   = 156,
    SQL_SQL92_FOREIGN_KEY_UPDATE_RULE   = 157,
    SQL_SQL92_GRANT                     = 158,
    SQL_SQL92_NUMERIC_VALUE_FUNCTIONS   = 159,
    SQL_SQL92_PREDICATES                = 160,
    SQL_SQL92_RELATIONAL_JOIN_OPERATORS = 161,
    SQL_SQL92_REVOKE                    = 162,
    SQL_SQL92_ROW_VALUE_enumRUCTOR     = 163,
    SQL_SQL92_STRING_FUNCTIONS          = 164,
    SQL_SQL92_VALUE_EXPRESSIONS         = 165,
    SQL_STANDARD_CLI_CONFORMANCE        = 166,
    SQL_STATIC_CURSOR_ATTRIBUTES1       = 167,
    SQL_STATIC_CURSOR_ATTRIBUTES2       = 168,
    SQL_AGGREGATE_FUNCTIONS             = 169,
    SQL_DDL_INDEX                       = 170,
    SQL_DM_VER                          = 171,
    SQL_INSERT_STATEMENT                = 172,
    SQL_UNION                           = 96,
    SQL_UNION_STATEMENT                 = SQL_UNION
}

enum int SQL_DTC_TRANSITION_COST = 1750;

/+
 ' -- SQL_ALTER_TABLE bitmasks --
 ' the following 5 bitmasks are defined in sql.d
 ' enum int SQL_AT_ADD_COLUMN     = 0x00000001L
 ' enum int SQL_AT_DROP_COLUMN    = 0x00000002L
 ' enum int SQL_AT_ADD_CONSTRAINT = 0x00000008L
 '
 +/
enum
{
    SQL_AT_ADD_COLUMN_SINGLE              = 0x00000020L,
    SQL_AT_ADD_COLUMN_DEFAULT             = 0x00000040L,
    SQL_AT_ADD_COLUMN_COLLATION           = 0x00000080L,
    SQL_AT_SET_COLUMN_DEFAULT             = 0x00000100L,
    SQL_AT_DROP_COLUMN_DEFAULT            = 0x00000200L,
    SQL_AT_DROP_COLUMN_CASCADE            = 0x00000400L,
    SQL_AT_DROP_COLUMN_RESTRICT           = 0x00000800L,
    SQL_AT_ADD_TABLE_CONSTRAINT           = 0x00001000L,
    SQL_AT_DROP_TABLE_CONSTRAINT_CASCADE  = 0x00002000L,
    SQL_AT_DROP_TABLE_CONSTRAINT_RESTRICT = 0x00004000L,
    SQL_AT_CONSTRAINT_NAME_DEFINITION     = 0x00008000L,
    SQL_AT_CONSTRAINT_INITIALLY_DEFERRED  = 0x00010000L,
    SQL_AT_CONSTRAINT_INITIALLY_IMMEDIATE = 0x00020000L,
    SQL_AT_CONSTRAINT_DEFERRABLE          = 0x00040000L,
    SQL_AT_CONSTRAINT_NON_DEFERRABLE      = 0x00080000L
}

// * SQL_CONVERT_*  return value bitmasks *
enum
{
    SQL_CVT_CHAR          = 0x00000001L,
    SQL_CVT_NUMERIC       = 0x00000002L,
    SQL_CVT_DECIMAL       = 0x00000004L,
    SQL_CVT_INTEGER       = 0x00000008L,
    SQL_CVT_SMALLINT      = 0x00000010L,
    SQL_CVT_FLOAT         = 0x00000020L,
    SQL_CVT_REAL          = 0x00000040L,
    SQL_CVT_DOUBLE        = 0x00000080L,
    SQL_CVT_VARCHAR       = 0x00000100L,
    SQL_CVT_LONGVARCHAR   = 0x00000200L,
    SQL_CVT_BINARY        = 0x00000400L,
    SQL_CVT_VARBINARY     = 0x00000800L,
    SQL_CVT_BIT           = 0x00001000L,
    SQL_CVT_TINYINT       = 0x00002000L,
    SQL_CVT_BIGINT        = 0x00004000L,
    SQL_CVT_DATE          = 0x00008000L,
    SQL_CVT_TIME          = 0x00010000L,
    SQL_CVT_TIMESTAMP     = 0x00020000L,
    SQL_CVT_LONGVARBINARY = 0x00040000L
}

enum
{
    SQL_CVT_INTERVAL_YEAR_MONTH = 0x00080000L,
    SQL_CVT_INTERVAL_DAY_TIME   = 0x00100000L,
    SQL_CVT_WCHAR               = 0x00200000L,
    SQL_CVT_WLONGVARCHAR        = 0x00400000L,
    SQL_CVT_WVARCHAR            = 0x00800000L
}

// * SQL_CONVERT_FUNCTIONS functions *
enum
{
    SQL_FN_CVT_CONVERT = 0x00000001L,
    SQL_FN_CVT_CAST    = 0x00000002L
}

// * SQL_STRING_FUNCTIONS functions *
enum
{
    SQL_FN_STR_CONCAT     = 0x00000001L,
    SQL_FN_STR_INSERT     = 0x00000002L,
    SQL_FN_STR_LEFT       = 0x00000004L,
    SQL_FN_STR_LTRIM      = 0x00000008L,
    SQL_FN_STR_LENGTH     = 0x00000010L,
    SQL_FN_STR_LOCATE     = 0x00000020L,
    SQL_FN_STR_LCASE      = 0x00000040L,
    SQL_FN_STR_REPEAT     = 0x00000080L,
    SQL_FN_STR_REPLACE    = 0x00000100L,
    SQL_FN_STR_RIGHT      = 0x00000200L,
    SQL_FN_STR_RTRIM      = 0x00000400L,
    SQL_FN_STR_SUBSTRING  = 0x00000800L,
    SQL_FN_STR_UCASE      = 0x00001000L,
    SQL_FN_STR_ASCII      = 0x00002000L,
    SQL_FN_STR_CHAR       = 0x00004000L,
    SQL_FN_STR_DIFFERENCE = 0x00008000L,
    SQL_FN_STR_LOCATE_2   = 0x00010000L,
    SQL_FN_STR_SOUNDEX    = 0x00020000L,
    SQL_FN_STR_SPACE      = 0x00040000L
}

enum
{
    SQL_FN_STR_BIT_LENGTH       = 0x00080000L,
    SQL_FN_STR_CHAR_LENGTH      = 0x00100000L,
    SQL_FN_STR_CHARACTER_LENGTH = 0x00200000L,
    SQL_FN_STR_OCTET_LENGTH     = 0x00400000L,
    SQL_FN_STR_POSITION         = 0x00800000L
}

// * SQL_SQL92_STRING_FUNCTIONS *
enum
{
    SQL_SSF_CONVERT       = 0x00000001L,
    SQL_SSF_LOWER         = 0x00000002L,
    SQL_SSF_UPPER         = 0x00000004L,
    SQL_SSF_SUBSTRING     = 0x00000008L,
    SQL_SSF_TRANSLATE     = 0x00000010L,
    SQL_SSF_TRIM_BOTH     = 0x00000020L,
    SQL_SSF_TRIM_LEADING  = 0x00000040L,
    SQL_SSF_TRIM_TRAILING = 0x00000080L
}

// * SQL_NUMERIC_FUNCTIONS functions *
enum
{
    SQL_FN_NUM_ABS      = 0x00000001L,
    SQL_FN_NUM_ACOS     = 0x00000002L,
    SQL_FN_NUM_ASIN     = 0x00000004L,
    SQL_FN_NUM_ATAN     = 0x00000008L,
    SQL_FN_NUM_ATAN2    = 0x00000010L,
    SQL_FN_NUM_CEILING  = 0x00000020L,
    SQL_FN_NUM_COS      = 0x00000040L,
    SQL_FN_NUM_COT      = 0x00000080L,
    SQL_FN_NUM_EXP      = 0x00000100L,
    SQL_FN_NUM_FLOOR    = 0x00000200L,
    SQL_FN_NUM_LOG      = 0x00000400L,
    SQL_FN_NUM_MOD      = 0x00000800L,
    SQL_FN_NUM_SIGN     = 0x00001000L,
    SQL_FN_NUM_SIN      = 0x00002000L,
    SQL_FN_NUM_SQRT     = 0x00004000L,
    SQL_FN_NUM_TAN      = 0x00008000L,
    SQL_FN_NUM_PI       = 0x00010000L,
    SQL_FN_NUM_RAND     = 0x00020000L,
    SQL_FN_NUM_DEGREES  = 0x00040000L,
    SQL_FN_NUM_LOG10    = 0x00080000L,
    SQL_FN_NUM_POWER    = 0x00100000L,
    SQL_FN_NUM_RADIANS  = 0x00200000L,
    SQL_FN_NUM_ROUND    = 0x00400000L,
    SQL_FN_NUM_TRUNCATE = 0x00800000L
}

// * SQL_SQL92_NUMERIC_VALUE_FUNCTIONS *
enum
{
    SQL_SNVF_BIT_LENGTH       = 0x00000001L,
    SQL_SNVF_CHAR_LENGTH      = 0x00000002L,
    SQL_SNVF_CHARACTER_LENGTH = 0x00000004L,
    SQL_SNVF_EXTRACT          = 0x00000008L,
    SQL_SNVF_OCTET_LENGTH     = 0x00000010L,
    SQL_SNVF_POSITION         = 0x00000020L
}

// * SQL_TIMEDATE_FUNCTIONS functions *
enum
{
    SQL_FN_TD_NOW           = 0x00000001L,
    SQL_FN_TD_CURDATE       = 0x00000002L,
    SQL_FN_TD_DAYOFMONTH    = 0x00000004L,
    SQL_FN_TD_DAYOFWEEK     = 0x00000008L,
    SQL_FN_TD_DAYOFYEAR     = 0x00000010L,
    SQL_FN_TD_MONTH         = 0x00000020L,
    SQL_FN_TD_QUARTER       = 0x00000040L,
    SQL_FN_TD_WEEK          = 0x00000080L,
    SQL_FN_TD_YEAR          = 0x00000100L,
    SQL_FN_TD_CURTIME       = 0x00000200L,
    SQL_FN_TD_HOUR          = 0x00000400L,
    SQL_FN_TD_MINUTE        = 0x00000800L,
    SQL_FN_TD_SECOND        = 0x00001000L,
    SQL_FN_TD_TIMESTAMPADD  = 0x00002000L,
    SQL_FN_TD_TIMESTAMPDIFF = 0x00004000L,
    SQL_FN_TD_DAYNAME       = 0x00008000L,
    SQL_FN_TD_MONTHNAME     = 0x00010000L
}

enum
{
    SQL_FN_TD_CURRENT_DATE      = 0x00020000L,
    SQL_FN_TD_CURRENT_TIME      = 0x00040000L,
    SQL_FN_TD_CURRENT_TIMESTAMP = 0x00080000L,
    SQL_FN_TD_EXTRACT           = 0x00100000L
}

// * SQL_SQL92_DATETIME_FUNCTIONS *
enum
{
    SQL_SDF_CURRENT_DATE       = 0x00000001L,
    SQL_SDF_CURRENT_TIME       = 0x00000002L,
    SQL_SDF_CURRENT_TIMESTAMP  = 0x00000004L
}

// * SQL_SYSTEM_FUNCTIONS functions *
enum
{
    SQL_FN_SYS_USERNAME = 0x00000001L,
    SQL_FN_SYS_DBNAME   = 0x00000002L,
    SQL_FN_SYS_IFNULL   = 0x00000004L
}

// * SQL_TIMEDATE_ADD_INTERVALS and SQL_TIMEDATE_DIFF_INTERVALS functions *
enum
{
    SQL_FN_TSI_FRAC_SECOND = 0x00000001L,
    SQL_FN_TSI_SECOND      = 0x00000002L,
    SQL_FN_TSI_MINUTE      = 0x00000004L,
    SQL_FN_TSI_HOUR        = 0x00000008L,
    SQL_FN_TSI_DAY         = 0x00000010L,
    SQL_FN_TSI_WEEK        = 0x00000020L,
    SQL_FN_TSI_MONTH       = 0x00000040L,
    SQL_FN_TSI_QUARTER     = 0x00000080L,
    SQL_FN_TSI_YEAR        = 0x00000100L
}

/+
 ' bitmasks for SQL_DYNAMIC_CURSOR_ATTRIBUTES1,
 ' SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES1,
 ' SQL_KEYSET_CURSOR_ATTRIBUTES1, and SQL_STATIC_CURSOR_ATTRIBUTES1
 '
 +/
enum
{
    // * supported SQLFetchScroll FetchOrientation's *
    SQL_CA1_NEXT                    = 0x00000001L,
    SQL_CA1_ABSOLUTE                = 0x00000002L,
    SQL_CA1_RELATIVE                = 0x00000004L,
    SQL_CA1_BOOKMARK                = 0x00000008L,

    // * supported SQLSetPos LockType's *
    SQL_CA1_LOCK_NO_CHANGE          = 0x00000040L,
    SQL_CA1_LOCK_EXCLUSIVE          = 0x00000080L,
    SQL_CA1_LOCK_UNLOCK             = 0x00000100L,

    // * supported SQLSetPos Operations *
    SQL_CA1_POS_POSITION            = 0x00000200L,
    SQL_CA1_POS_UPDATE              = 0x00000400L,
    SQL_CA1_POS_DELETE              = 0x00000800L,
    SQL_CA1_POS_REFRESH             = 0x00001000L,

    // * positioned updates and deletes *
    SQL_CA1_POSITIONED_UPDATE       = 0x00002000L,
    SQL_CA1_POSITIONED_DELETE       = 0x00004000L,
    SQL_CA1_SELECT_FOR_UPDATE       = 0x00008000L,

    // * supported SQLBulkOperations operations *
    SQL_CA1_BULK_ADD                = 0x00010000L,
    SQL_CA1_BULK_UPDATE_BY_BOOKMARK = 0x00020000L,
    SQL_CA1_BULK_DELETE_BY_BOOKMARK = 0x00040000L,
    SQL_CA1_BULK_FETCH_BY_BOOKMARK  = 0x00080000L
}

/+
 ' bitmasks for SQL_DYNAMIC_CURSOR_ATTRIBUTES2,
 ' SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES2,
 ' SQL_KEYSET_CURSOR_ATTRIBUTES2, and SQL_STATIC_CURSOR_ATTRIBUTES2
 '
 +/
enum
{
    // * supported values for SQL_ATTR_SCROLL_CONCURRENCY *
    SQL_CA2_READ_ONLY_CONCURRENCY  = 0x00000001L,
    SQL_CA2_LOCK_CONCURRENCY       = 0x00000002L,
    SQL_CA2_OPT_ROWVER_CONCURRENCY = 0x00000004L,
    SQL_CA2_OPT_VALUES_CONCURRENCY = 0x00000008L,

    // * sensitivity of the cursor to its own inserts, deletes, and updates *
    SQL_CA2_SENSITIVITY_ADDITIONS  = 0x00000010L,
    SQL_CA2_SENSITIVITY_DELETIONS  = 0x00000020L,
    SQL_CA2_SENSITIVITY_UPDATES    = 0x00000040L,

    // * semantics of SQL_ATTR_MAX_ROWS *
    SQL_CA2_MAX_ROWS_SELECT        = 0x00000080L,
    SQL_CA2_MAX_ROWS_INSERT        = 0x00000100L,
    SQL_CA2_MAX_ROWS_DELETE        = 0x00000200L,
    SQL_CA2_MAX_ROWS_UPDATE        = 0x00000400L,
    SQL_CA2_MAX_ROWS_CATALOG       = 0x00000800L,
    SQL_CA2_MAX_ROWS_AFFECTS_ALL   = (SQL_CA2_MAX_ROWS_SELECT |
                          SQL_CA2_MAX_ROWS_INSERT | SQL_CA2_MAX_ROWS_DELETE |
                          SQL_CA2_MAX_ROWS_UPDATE | SQL_CA2_MAX_ROWS_CATALOG),

    // * semantics of SQL_DIAG_CURSOR_ROW_COUNT *
    SQL_CA2_CRC_EXACT              = 0x00001000L,
    SQL_CA2_CRC_APPROXIMATE        = 0x00002000L,

    // * the kinds of positioned statements that can be simulated *
    SQL_CA2_SIMULATE_NON_UNIQUE    = 0x00004000L,
    SQL_CA2_SIMULATE_TRY_UNIQUE    = 0x00008000L,
    SQL_CA2_SIMULATE_UNIQUE        = 0x00010000L
}

// * SQL_ODBC_API_CONFORMANCE values *
enum
{
    SQL_OAC_NONE   = 0x0000,
    SQL_OAC_LEVEL1 = 0x0001,
    SQL_OAC_LEVEL2 = 0x0002
}

// * SQL_ODBC_SAG_CLI_CONFORMANCE values *
enum
{
    SQL_OSCC_NOT_COMPLIANT = 0x0000,
    SQL_OSCC_COMPLIANT     = 0x0001
}

// * SQL_ODBC_SQL_CONFORMANCE values *
enum
{
    SQL_OSC_MINIMUM  = 0x0000,
    SQL_OSC_CORE     = 0x0001,
    SQL_OSC_EXTENDED = 0x0002
}

// * SQL_CONCAT_NULL_BEHAVIOR values *
enum
{
    SQL_CB_NULL     = 0x0000,
    SQL_CB_NON_NULL = 0x0001
}

// * SQL_SCROLL_OPTIONS masks *
enum
{
    SQL_SO_FORWARD_ONLY  = 0x00000001L,
    SQL_SO_KEYSET_DRIVEN = 0x00000002L,
    SQL_SO_DYNAMIC       = 0x00000004L,
    SQL_SO_MIXED         = 0x00000008L,
    SQL_SO_STATIC        = 0x00000010L
}

// * SQL_FETCH_DIRECTION masks *
enum
{
    SQL_FD_FETCH_BOOKMARK  = 0x00000080L
}

// * SQL_CORRELATION_NAME values *
enum
{
    SQL_CN_NONE      = 0x0000,
    SQL_CN_DIFFERENT = 0x0001,
    SQL_CN_ANY       = 0x0002
}

enum
{
    // * SQL_NON_NULLABLE_COLUMNS values *
    SQL_NNC_NULL     = 0x0000,
    SQL_NNC_NON_NULL = 0x0001,

    // * SQL_NULL_COLLATION values *
    SQL_NC_START     = 0x0002,
    SQL_NC_END       = 0x0004
}

// * SQL_FILE_USAGE values *
enum
{
    SQL_FILE_NOT_SUPPORTED = 0x0000,
    SQL_FILE_TABLE         = 0x0001,
    SQL_FILE_QUALIFIER     = 0x0002,
    SQL_FILE_CATALOG       = SQL_FILE_QUALIFIER
}

// * SQL_GETDATA_EXTENSIONS values *
enum
{
    SQL_GD_BLOCK = 0x00000004L,
    SQL_GD_BOUND = 0x00000008L
}

// * SQL_POSITIONED_STATEMENTS masks *
enum
{
    SQL_PS_POSITIONED_DELETE = 0x00000001L,
    SQL_PS_POSITIONED_UPDATE = 0x00000002L,
    SQL_PS_SELECT_FOR_UPDATE = 0x00000004L
}

// * SQL_GROUP_BY values *
enum
{
    SQL_GB_NOT_SUPPORTED            = 0x0000,
    SQL_GB_GROUP_BY_EQUALS_SELECT   = 0x0001,
    SQL_GB_GROUP_BY_CONTAINS_SELECT = 0x0002,
    SQL_GB_NO_RELATION              = 0x0003,
    SQL_GB_COLLATE                  = 0x0004
}

// * SQL_OWNER_USAGE masks *
enum
{
    SQL_OU_DML_STATEMENTS       = 0x00000001L,
    SQL_OU_PROCEDURE_INVOCATION = 0x00000002L,
    SQL_OU_TABLE_DEFINITION     = 0x00000004L,
    SQL_OU_INDEX_DEFINITION     = 0x00000008L,
    SQL_OU_PRIVILEGE_DEFINITION = 0x00000010L
}

// * SQL_SCHEMA_USAGE masks *
enum
{
    SQL_SU_DML_STATEMENTS       = SQL_OU_DML_STATEMENTS,
    SQL_SU_PROCEDURE_INVOCATION = SQL_OU_PROCEDURE_INVOCATION,
    SQL_SU_TABLE_DEFINITION     = SQL_OU_TABLE_DEFINITION,
    SQL_SU_INDEX_DEFINITION     = SQL_OU_INDEX_DEFINITION,
    SQL_SU_PRIVILEGE_DEFINITION = SQL_OU_PRIVILEGE_DEFINITION
}

// * SQL_QUALIFIER_USAGE masks *
enum
{
    SQL_QU_DML_STATEMENTS       = 0x00000001L,
    SQL_QU_PROCEDURE_INVOCATION = 0x00000002L,
    SQL_QU_TABLE_DEFINITION     = 0x00000004L,
    SQL_QU_INDEX_DEFINITION     = 0x00000008L,
    SQL_QU_PRIVILEGE_DEFINITION = 0x00000010L
}

enum
{
    // * SQL_CATALOG_USAGE masks *
    SQL_CU_DML_STATEMENTS       = SQL_QU_DML_STATEMENTS,
    SQL_CU_PROCEDURE_INVOCATION = SQL_QU_PROCEDURE_INVOCATION,
    SQL_CU_TABLE_DEFINITION     = SQL_QU_TABLE_DEFINITION,
    SQL_CU_INDEX_DEFINITION     = SQL_QU_INDEX_DEFINITION,
    SQL_CU_PRIVILEGE_DEFINITION = SQL_QU_PRIVILEGE_DEFINITION
}

enum
{
    // * SQL_SUBQUERIES masks *
    SQL_SQ_COMPARISON            = 0x00000001L,
    SQL_SQ_EXISTS                = 0x00000002L,
    SQL_SQ_IN                    = 0x00000004L,
    SQL_SQ_QUANTIFIED            = 0x00000008L,
    SQL_SQ_CORRELATED_SUBQUERIES = 0x00000010L,

    // * SQL_UNION masks *
    SQL_U_UNION                  = 0x00000001L,
    SQL_U_UNION_ALL              = 0x00000002L,

    // * SQL_BOOKMARK_PERSISTENCE values *
    SQL_BP_CLOSE                 = 0x00000001L,
    SQL_BP_DELETE                = 0x00000002L,
    SQL_BP_DROP                  = 0x00000004L,
    SQL_BP_TRANSACTION           = 0x00000008L,
    SQL_BP_UPDATE                = 0x00000010L,
    SQL_BP_OTHER_HSTMT           = 0x00000020L,
    SQL_BP_SCROLL                = 0x00000040L,

    // * SQL_STATIC_SENSITIVITY values *
    SQL_SS_ADDITIONS             = 0x00000001L,
    SQL_SS_DELETIONS             = 0x00000002L,
    SQL_SS_UPDATES               = 0x00000004L,

    // * SQL_VIEW values *
    SQL_CV_CREATE_VIEW           = 0x00000001L,
    SQL_CV_CHECK_OPTION          = 0x00000002L,
    SQL_CV_CASCADED              = 0x00000004L,
    SQL_CV_LOCAL                 = 0x00000008L,

    // * SQL_LOCK_TYPES masks *
    SQL_LCK_NO_CHANGE            = 0x00000001L,
    SQL_LCK_EXCLUSIVE            = 0x00000002L,
    SQL_LCK_UNLOCK               = 0x00000004L,

    // * SQL_POS_OPERATIONS masks *
    SQL_POS_POSITION             = 0x00000001L,
    SQL_POS_REFRESH              = 0x00000002L,
    SQL_POS_UPDATE               = 0x00000004L,
    SQL_POS_DELETE               = 0x00000008L,
    SQL_POS_ADD                  = 0x00000010L,

    // * SQL_QUALIFIER_LOCATION values *
    SQL_QL_START                 = 0x0001,
    SQL_QL_END                   = 0x0002
}

// * Here start return values for ODBC 3.0 SQLGetInfo *
enum
{
    // * SQL_AGGREGATE_FUNCTIONS bitmasks *
    SQL_AF_AVG                             = 0x00000001L,
    SQL_AF_COUNT                           = 0x00000002L,
    SQL_AF_MAX                             = 0x00000004L,
    SQL_AF_MIN                             = 0x00000008L,
    SQL_AF_SUM                             = 0x00000010L,
    SQL_AF_DISTINCT                        = 0x00000020L,
    SQL_AF_ALL                             = 0x00000040L,

    // * SQL_SQL_CONFORMANCE bit masks *
    SQL_SC_SQL92_ENTRY                     = 0x00000001L,
    SQL_SC_FIPS127_2_TRANSITIONAL          = 0x00000002L,
    SQL_SC_SQL92_INTERMEDIATE              = 0x00000004L,
    SQL_SC_SQL92_FULL                      = 0x00000008L,

    // * SQL_DATETIME_LITERALS masks *
    SQL_DL_SQL92_DATE                      = 0x00000001L,
    SQL_DL_SQL92_TIME                      = 0x00000002L,
    SQL_DL_SQL92_TIMESTAMP                 = 0x00000004L,
    SQL_DL_SQL92_INTERVAL_YEAR             = 0x00000008L,
    SQL_DL_SQL92_INTERVAL_MONTH            = 0x00000010L,
    SQL_DL_SQL92_INTERVAL_DAY              = 0x00000020L,
    SQL_DL_SQL92_INTERVAL_HOUR             = 0x00000040L,
    SQL_DL_SQL92_INTERVAL_MINUTE           = 0x00000080L,
    SQL_DL_SQL92_INTERVAL_SECOND           = 0x00000100L,
    SQL_DL_SQL92_INTERVAL_YEAR_TO_MONTH    = 0x00000200L,
    SQL_DL_SQL92_INTERVAL_DAY_TO_HOUR      = 0x00000400L,
    SQL_DL_SQL92_INTERVAL_DAY_TO_MINUTE    = 0x00000800L,
    SQL_DL_SQL92_INTERVAL_DAY_TO_SECOND    = 0x00001000L,
    SQL_DL_SQL92_INTERVAL_HOUR_TO_MINUTE   = 0x00002000L,
    SQL_DL_SQL92_INTERVAL_HOUR_TO_SECOND   = 0x00004000L,
    SQL_DL_SQL92_INTERVAL_MINUTE_TO_SECOND = 0x00008000L,

    // * SQL_CATALOG_LOCATION values *
    SQL_CL_START              = SQL_QL_START,
    SQL_CL_END                = SQL_QL_END,

    // * values for SQL_BATCH_ROW_COUNT *
    SQL_BRC_PROCEDURES        = 0x0000001,
    SQL_BRC_EXPLICIT          = 0x0000002,
    SQL_BRC_ROLLED_UP         = 0x0000004,

    // * bitmasks for SQL_BATCH_SUPPORT *
    SQL_BS_SELECT_EXPLICIT    = 0x00000001L,
    SQL_BS_ROW_COUNT_EXPLICIT = 0x00000002L,
    SQL_BS_SELECT_PROC        = 0x00000004L,
    SQL_BS_ROW_COUNT_PROC     = 0x00000008L,

    // * Values for SQL_PARAM_ARRAY_ROW_COUNTS getinfo */
    SQL_PARC_BATCH    = 1,
    SQL_PARC_NO_BATCH = 2,

    // * values for SQL_PARAM_ARRAY_SELECTS *
    SQL_PAS_BATCH     = 1,
    SQL_PAS_NO_BATCH  = 2,
    SQL_PAS_NO_SELECT = 3,

    // * Bitmasks for SQL_INDEX_KEYWORDS *
    SQL_IK_NONE       = 0x00000000L,
    SQL_IK_ASC        = 0x00000001L,
    SQL_IK_DESC       = 0x00000002L,
    SQL_IK_ALL        = (SQL_IK_ASC | SQL_IK_DESC),

    // * Bitmasks for SQL_INFO_SCHEMA_VIEWS *
    SQL_ISV_ASSERTIONS              = 0x00000001L,
    SQL_ISV_CHARACTER_SETS          = 0x00000002L,
    SQL_ISV_CHECK_CONSTRAINTS       = 0x00000004L,
    SQL_ISV_COLLATIONS              = 0x00000008L,
    SQL_ISV_COLUMN_DOMAIN_USAGE     = 0x00000010L,
    SQL_ISV_COLUMN_PRIVILEGES       = 0x00000020L,
    SQL_ISV_COLUMNS                 = 0x00000040L,
    SQL_ISV_CONSTRAINT_COLUMN_USAGE = 0x00000080L,
    SQL_ISV_CONSTRAINT_TABLE_USAGE  = 0x00000100L,
    SQL_ISV_DOMAIN_CONSTRAINTS      = 0x00000200L,
    SQL_ISV_DOMAINS                 = 0x00000400L,
    SQL_ISV_KEY_COLUMN_USAGE        = 0x00000800L,
    SQL_ISV_REFERENTIAL_CONSTRAINTS = 0x00001000L,
    SQL_ISV_SCHEMATA                = 0x00002000L,
    SQL_ISV_SQL_LANGUAGES           = 0x00004000L,
    SQL_ISV_TABLE_CONSTRAINTS       = 0x00008000L,
    SQL_ISV_TABLE_PRIVILEGES        = 0x00010000L,
    SQL_ISV_TABLES                  = 0x00020000L,
    SQL_ISV_TRANSLATIONS            = 0x00040000L,
    SQL_ISV_USAGE_PRIVILEGES        = 0x00080000L,
    SQL_ISV_VIEW_COLUMN_USAGE       = 0x00100000L,
    SQL_ISV_VIEW_TABLE_USAGE        = 0x00200000L,
    SQL_ISV_VIEWS                   = 0x00400000L,

    // * Bitmasks for SQL_ASYNC_MODE *
    SQL_AM_NONE         = 0,
    SQL_AM_CONNECTION   = 1,
    SQL_AM_STATEMENT    = 2,

    // * Bitmasks for SQL_ALTER_DOMAIN *
    SQL_AD_CONSTRAINT_NAME_DEFINITION         = 0x00000001L,
    SQL_AD_ADD_DOMAIN_CONSTRAINT              = 0x00000002L,
    SQL_AD_DROP_DOMAIN_CONSTRAINT             = 0x00000004L,
    SQL_AD_ADD_DOMAIN_DEFAULT                 = 0x00000008L,
    SQL_AD_DROP_DOMAIN_DEFAULT                = 0x00000010L,
    SQL_AD_ADD_CONSTRAINT_INITIALLY_DEFERRED  = 0x00000020L,
    SQL_AD_ADD_CONSTRAINT_INITIALLY_IMMEDIATE = 0x00000040L,
    SQL_AD_ADD_CONSTRAINT_DEFERRABLE          = 0x00000080L,
    SQL_AD_ADD_CONSTRAINT_NON_DEFERRABLE      = 0x00000100L,

    // * SQL_CREATE_SCHEMA bitmasks *
    SQL_CS_CREATE_SCHEMA         = 0x00000001L,
    SQL_CS_AUTHORIZATION         = 0x00000002L,
    SQL_CS_DEFAULT_CHARACTER_SET = 0x00000004L,

    // * SQL_CREATE_TRANSLATION bitmasks *
    SQL_CTR_CREATE_TRANSLATION   = 0x00000001L,

    // * SQL_CREATE_ASSERTION bitmasks *
    SQL_CA_CREATE_ASSERTION               = 0x00000001L,
    SQL_CA_CONSTRAINT_INITIALLY_DEFERRED  = 0x00000010L,
    SQL_CA_CONSTRAINT_INITIALLY_IMMEDIATE = 0x00000020L,
    SQL_CA_CONSTRAINT_DEFERRABLE          = 0x00000040L,
    SQL_CA_CONSTRAINT_NON_DEFERRABLE      = 0x00000080L,

    // * SQL_CREATE_CHARACTER_SET bitmasks *
    SQL_CCS_CREATE_CHARACTER_SET = 0x00000001L,
    SQL_CCS_COLLATE_CLAUSE       = 0x00000002L,
    SQL_CCS_LIMITED_COLLATION    = 0x00000004L,

    // * SQL_CREATE_COLLATION bitmasks *
    SQL_CCOL_CREATE_COLLATION    = 0x00000001L,

    // * SQL_CREATE_DOMAIN bitmasks *
    SQL_CDO_CREATE_DOMAIN                  = 0x00000001L,
    SQL_CDO_DEFAULT                        = 0x00000002L,
    SQL_CDO_CONSTRAINT                     = 0x00000004L,
    SQL_CDO_COLLATION                      = 0x00000008L,
    SQL_CDO_CONSTRAINT_NAME_DEFINITION     = 0x00000010L,
    SQL_CDO_CONSTRAINT_INITIALLY_DEFERRED  = 0x00000020L,
    SQL_CDO_CONSTRAINT_INITIALLY_IMMEDIATE = 0x00000040L,
    SQL_CDO_CONSTRAINT_DEFERRABLE          = 0x00000080L,
    SQL_CDO_CONSTRAINT_NON_DEFERRABLE      = 0x00000100L,

    // * SQL_CREATE_TABLE bitmasks *
    SQL_CT_CREATE_TABLE                   = 0x00000001L,
    SQL_CT_COMMIT_PRESERVE                = 0x00000002L,
    SQL_CT_COMMIT_DELETE                  = 0x00000004L,
    SQL_CT_GLOBAL_TEMPORARY               = 0x00000008L,
    SQL_CT_LOCAL_TEMPORARY                = 0x00000010L,
    SQL_CT_CONSTRAINT_INITIALLY_DEFERRED  = 0x00000020L,
    SQL_CT_CONSTRAINT_INITIALLY_IMMEDIATE = 0x00000040L,
    SQL_CT_CONSTRAINT_DEFERRABLE          = 0x00000080L,
    SQL_CT_CONSTRAINT_NON_DEFERRABLE      = 0x00000100L,
    SQL_CT_COLUMN_CONSTRAINT              = 0x00000200L,
    SQL_CT_COLUMN_DEFAULT                 = 0x00000400L,
    SQL_CT_COLUMN_COLLATION               = 0x00000800L,
    SQL_CT_TABLE_CONSTRAINT               = 0x00001000L,
    SQL_CT_CONSTRAINT_NAME_DEFINITION     = 0x00002000L,

    // * SQL_DDL_INDEX bitmasks *
    SQL_DI_CREATE_INDEX   = 0x00000001L,
    SQL_DI_DROP_INDEX     = 0x00000002L,

    // * SQL_DROP_COLLATION bitmasks *
    SQL_DC_DROP_COLLATION = 0x00000001L,

    // * SQL_DROP_DOMAIN bitmasks *
    SQL_DD_DROP_DOMAIN    = 0x00000001L,
    SQL_DD_RESTRICT       = 0x00000002L,
    SQL_DD_CASCADE        = 0x00000004L,

    // * SQL_DROP_SCHEMA bitmasks *
    SQL_DS_DROP_SCHEMA    = 0x00000001L,
    SQL_DS_RESTRICT       = 0x00000002L,
    SQL_DS_CASCADE        = 0x00000004L,

    // * SQL_DROP_CHARACTER_SET bitmasks *
    SQL_DCS_DROP_CHARACTER_SET = 0x00000001L,

    // * SQL_DROP_ASSERTION bitmasks *
    SQL_DA_DROP_ASSERTION = 0x00000001L,

    // * SQL_DROP_TABLE bitmasks *
    SQL_DT_DROP_TABLE   = 0x00000001L,
    SQL_DT_RESTRICT     = 0x00000002L,
    SQL_DT_CASCADE      = 0x00000004L,

    // * SQL_DROP_TRANSLATION bitmasks *
    SQL_DTR_DROP_TRANSLATION = 0x00000001L,

    // * SQL_DROP_VIEW bitmasks *
    SQL_DV_DROP_VIEW = 0x00000001L,
    SQL_DV_RESTRICT  = 0x00000002L,
    SQL_DV_CASCADE   = 0x00000004L,

    // * SQL_INSERT_STATEMENT bitmasks *
    SQL_IS_INSERT_LITERALS = 0x00000001L,
    SQL_IS_INSERT_SEARCHED = 0x00000002L,
    SQL_IS_SELECT_INTO     = 0x00000004L,

    // * SQL_ODBC_INTERFACE_CONFORMANCE values *
    SQL_OIC_CORE           = 1UL,
    SQL_OIC_LEVEL1         = 2UL,
    SQL_OIC_LEVEL2         = 3UL,

    // * SQL_SQL92_FOREIGN_KEY_DELETE_RULE bitmasks *
    SQL_SFKD_CASCADE       = 0x00000001L,
    SQL_SFKD_NO_ACTION     = 0x00000002L,
    SQL_SFKD_SET_DEFAULT   = 0x00000004L,
    SQL_SFKD_SET_NULL      = 0x00000008L,

    // * SQL_SQL92_FOREIGN_KEY_UPDATE_RULE bitmasks *
    SQL_SFKU_CASCADE       = 0x00000001L,
    SQL_SFKU_NO_ACTION     = 0x00000002L,
    SQL_SFKU_SET_DEFAULT   = 0x00000004L,
    SQL_SFKU_SET_NULL      = 0x00000008L,

    // * SQL_SQL92_GRANT    bitmasks *
    SQL_SG_USAGE_ON_DOMAIN        = 0x00000001L,
    SQL_SG_USAGE_ON_CHARACTER_SET = 0x00000002L,
    SQL_SG_USAGE_ON_COLLATION     = 0x00000004L,
    SQL_SG_USAGE_ON_TRANSLATION   = 0x00000008L,
    SQL_SG_WITH_GRANT_OPTION      = 0x00000010L,
    SQL_SG_DELETE_TABLE           = 0x00000020L,
    SQL_SG_INSERT_TABLE           = 0x00000040L,
    SQL_SG_INSERT_COLUMN          = 0x00000080L,
    SQL_SG_REFERENCES_TABLE       = 0x00000100L,
    SQL_SG_REFERENCES_COLUMN      = 0x00000200L,
    SQL_SG_SELECT_TABLE           = 0x00000400L,
    SQL_SG_UPDATE_TABLE           = 0x00000800L,
    SQL_SG_UPDATE_COLUMN          = 0x00001000L,

    // * SQL_SQL92_PREDICATES bitmasks *
    SQL_SP_EXISTS                 = 0x00000001L,
    SQL_SP_ISNOTNULL              = 0x00000002L,
    SQL_SP_ISNULL                 = 0x00000004L,
    SQL_SP_MATCH_FULL             = 0x00000008L,
    SQL_SP_MATCH_PARTIAL          = 0x00000010L,
    SQL_SP_MATCH_UNIQUE_FULL      = 0x00000020L,
    SQL_SP_MATCH_UNIQUE_PARTIAL   = 0x00000040L,
    SQL_SP_OVERLAPS               = 0x00000080L,
    SQL_SP_UNIQUE                 = 0x00000100L,
    SQL_SP_LIKE                   = 0x00000200L,
    SQL_SP_IN                     = 0x00000400L,
    SQL_SP_BETWEEN                = 0x00000800L,
    SQL_SP_COMPARISON             = 0x00001000L,
    SQL_SP_QUANTIFIED_COMPARISON  = 0x00002000L,

    // * SQL_SQL92_RELATIONAL_JOIN_OPERATORS bitmasks *
    SQL_SRJO_CORRESPONDING_CLAUSE = 0x00000001L,
    SQL_SRJO_CROSS_JOIN           = 0x00000002L,
    SQL_SRJO_EXCEPT_JOIN          = 0x00000004L,
    SQL_SRJO_FULL_OUTER_JOIN      = 0x00000008L,
    SQL_SRJO_INNER_JOIN           = 0x00000010L,
    SQL_SRJO_INTERSECT_JOIN       = 0x00000020L,
    SQL_SRJO_LEFT_OUTER_JOIN      = 0x00000040L,
    SQL_SRJO_NATURAL_JOIN         = 0x00000080L,
    SQL_SRJO_RIGHT_OUTER_JOIN     = 0x00000100L,
    SQL_SRJO_UNION_JOIN           = 0x00000200L,

    // * SQL_SQL92_REVOKE bitmasks *
    SQL_SR_USAGE_ON_DOMAIN        = 0x00000001L,
    SQL_SR_USAGE_ON_CHARACTER_SET = 0x00000002L,
    SQL_SR_USAGE_ON_COLLATION     = 0x00000004L,
    SQL_SR_USAGE_ON_TRANSLATION   = 0x00000008L,
    SQL_SR_GRANT_OPTION_FOR       = 0x00000010L,
    SQL_SR_CASCADE                = 0x00000020L,
    SQL_SR_RESTRICT               = 0x00000040L,
    SQL_SR_DELETE_TABLE           = 0x00000080L,
    SQL_SR_INSERT_TABLE           = 0x00000100L,
    SQL_SR_INSERT_COLUMN          = 0x00000200L,
    SQL_SR_REFERENCES_TABLE       = 0x00000400L,
    SQL_SR_REFERENCES_COLUMN      = 0x00000800L,
    SQL_SR_SELECT_TABLE           = 0x00001000L,
    SQL_SR_UPDATE_TABLE           = 0x00002000L,
    SQL_SR_UPDATE_COLUMN          = 0x00004000L,

    // * SQL_SQL92_ROW_VALUE_CONSTRUCTOR bitmasks *
    SQL_SRVC_VALUE_EXPRESSION     = 0x00000001L,
    SQL_SRVC_NULL                 = 0x00000002L,
    SQL_SRVC_DEFAULT              = 0x00000004L,
    SQL_SRVC_ROW_SUBQUERY         = 0x00000008L,

    // * SQL_SQL92_VALUE_EXPRESSIONS bitmasks *
    SQL_SVE_CASE                  = 0x00000001L,
    SQL_SVE_CAST                  = 0x00000002L,
    SQL_SVE_COALESCE              = 0x00000004L,
    SQL_SVE_NULLIF                = 0x00000008L,

    // * SQL_STANDARD_CLI_CONFORMANCE bitmasks *
    SQL_SCC_XOPEN_CLI_VERSION1    = 0x00000001L,
    SQL_SCC_ISO92_CLI             = 0x00000002L,

    // * SQL_UNION_STATEMENT bitmasks *
    SQL_US_UNION                  = SQL_U_UNION,
    SQL_US_UNION_ALL              = SQL_U_UNION_ALL
}

// * SQL_DTC_TRANSITION_COST bitmasks *
enum
{
    SQL_DTC_ENLIST_EXPENSIVE   = 0x00000001L,
    SQL_DTC_UNENLIST_EXPENSIVE = 0x00000002L
}

// * additional SQLDataSources fetch directions *
enum
{
    SQL_FETCH_FIRST_USER   = 31,
    SQL_FETCH_FIRST_SYSTEM = 32

}

enum
{
    // * Defines for SQLSetPos *
    SQL_ENTIRE_ROWSET           = 0,

    // * Operations in SQLSetPos *
    SQL_POSITION                = 0, /* 1.0 FALSE */
    SQL_REFRESH                 = 1, /* 1.0 TRUE  */
    SQL_UPDATE                  = 2,
    SQL_DELETE                  = 3,

    // * Operations in SQLBulkOperations *
    SQL_ADD                     = 4,
    SQL_SETPOS_MAX_OPTION_VALUE = SQL_ADD
}

enum
{
    SQL_UPDATE_BY_BOOKMARK = 5,
    SQL_DELETE_BY_BOOKMARK = 6,
    SQL_FETCH_BY_BOOKMARK  = 7
}

// * Lock options in SQLSetPos *
enum
{
    SQL_LOCK_NO_CHANGE = 0,  /*      1.0 FALSE */
    SQL_LOCK_EXCLUSIVE = 1,  /*      1.0 TRUE  */
    SQL_LOCK_UNLOCK    = 2,
    SQL_SETPOS_MAX_LOCK_VALUE = SQL_LOCK_UNLOCK
}

//************************
/+ Macros for SQLSetPos. They're templates so they don't link in. +/
//************************
int SQL_POSITION_TO()
(
    SQLHSTMT hstmt,
    ushort      irow
)
{
    return SQLSetPos( hstmt, irow, SQL_POSITION, SQL_LOCK_NO_CHANGE );
}

int SQL_LOCK_RECORD()
(
    SQLHSTMT hstmt,
    ushort      irow,
    bool     fLock
)
{
    return SQLSetPos( hstmt, irow, SQL_POSITION, fLock );
}

int SQL_REFRESH_RECORD()
(
    SQLHSTMT hstmt,
    ushort      irow,
    bool     fLock
)
{
    return SQLSetPos( hstmt, irow, SQL_REFRESH, fLock );
}

int SQL_UPDATE_RECORD()
(
    SQLHSTMT hstmt,
    ushort      irow
)
{
    return SQLSetPos( hstmt, irow, SQL_UPDATE, SQL_LOCK_NO_CHANGE );
}

int SQL_DELETE_RECORD()
(
    SQLHSTMT hstmt,
    ushort      irow
)
{
    return SQLSetPos( hstmt, irow, SQL_DELETE, SQL_LOCK_NO_CHANGE );
}

int SQL_ADD_RECORD()
(
    SQLHSTMT hstmt,
    ushort      irow
)
{
    return SQLSetPos( hstmt, irow, SQL_ADD,SQL_LOCK_NO_CHANGE );
}

// * Column types and scopes in SQLSpecialColumns. *
enum
{
    SQL_BEST_ROWID = 1,
    SQL_ROWVER     = 2
}

/+
 ' Defines for SQLSpecialColumns (returned in the result set)
 ' SQL_PC_UNKNOWN and SQL_PC_PSEUDO are defined in sql.d
 '
 +/
enum int SQL_PC_NOT_PSEUDO = 1;

// * Defines for SQLStatistics *
enum
{
    SQL_QUICK  = 0,
    SQL_ENSURE = 1
}

/+
 ' Defines for SQLStatistics (returned in the result set)
 ' SQL_INDEX_CLUSTERED, SQL_INDEX_HASHED, and SQL_INDEX_OTHER are
 ' defined in sql.d
 '
 +/
enum int SQL_TABLE_STAT = 0;

// * Defines for SQLTables *
immutable char[] SQL_ALL_CATALOGS    = "%";
immutable char[] SQL_ALL_SCHEMAS     = "%";
immutable char[] SQL_ALL_TABLE_TYPES = "%";

// * Options for SQLDriverConnect - fDriverCompletion *
enum
{
    SQL_DRIVER_NOPROMPT          = 0,
    SQL_DRIVER_COMPLETE          = 1,
    SQL_DRIVER_PROMPT            = 2,
    SQL_DRIVER_COMPLETE_REQUIRED = 3
}

/+
 ' ODBC v1.0+ ODBC
 ' Is an alternative to SQLConnect. It supports data sources that require more
 ' connection information than the three arguments in SQLConnect, dialog boxes
 ' to prompt the user for all connection information, and data sources that are
 ' not defined in the system information.
 '
 ' SQLDriverConnect provides the following connection attributes:
 '
 ' 1) Establish a connection using a connection string that contains the data
 ' source name, one or more user IDs, one or more passwords, and other information
 ' required by the data source.
 '
 ' 2) Establish a connection using a partial connection string or no additional
 ' information; in this case, the Driver Manager and the driver can each prompt
 ' the user for connection information.
 '
 ' 3) Establish a connection to a data source that is not defined in the system
 ' information. If the application supplies a partial connection string, the
 ' driver can prompt the user for connection information.
 '
 ' 4) Establish a connection to a data source using a connection string
 ' constructed from the information in a .dsn file.
 '
 +/
SQLRETURN SQLDriverConnect
(
    /+ IN  +/ SQLHDBC      hdbc,
    /+ IN  +/ SQLHWND      hwnd,
    /+ IN  +/ SQLCHAR      *szConnStrIn,
    /+ IN  +/ SQLSMALLINT  cbConnStrIn,
    /+ OUT +/ SQLCHAR      *szConnStrOut,
    /+ IN  +/ SQLSMALLINT  cbConnStrOutMax,
    /+ OUT +/ SQLSMALLINT  *pcbConnStrOut,
    /+ IN  +/ SQLUSMALLINT fDriverCompletion
);

// * Level 2 Functions *
// * SQLExtendedFetch "fFetchType" values *
enum int SQL_FETCH_BOOKMARK = 8;

// * SQLExtendedFetch "rgfRowStatus" element values *
enum
{
    SQL_ROW_SUCCESS = 0,
    SQL_ROW_DELETED = 1,
    SQL_ROW_UPDATED = 2,
    SQL_ROW_NOROW   = 3,
    SQL_ROW_ADDED   = 4,
    SQL_ROW_ERROR   = 5
}

enum
{
    SQL_ROW_SUCCESS_WITH_INFO = 6,
    SQL_ROW_PROCEED           = 0,
    SQL_ROW_IGNORE            = 1
}

// * value for SQL_DESC_ARRAY_STATUS_PTR *
enum
{
    SQL_PARAM_SUCCESS           = 0,
    SQL_PARAM_SUCCESS_WITH_INFO = 6,
    SQL_PARAM_ERROR             = 5,
    SQL_PARAM_UNUSED            = 7,
    SQL_PARAM_DIAG_UNAVAILABLE  = 1,

    SQL_PARAM_PROCEED           = 0,
    SQL_PARAM_IGNORE            = 1
}

// * Defines for SQLForeignKeys (UPDATE_RULE and DELETE_RULE) *
enum
{
    SQL_CASCADE     = 0,
    SQL_RESTRICT    = 1,
    SQL_SET_NULL    = 2,
    SQL_NO_ACTION   = 3,
    SQL_SET_DEFAULT = 4
}

/+
 ' Note that the following are in a different column of SQLForeignKeys than
 ' the previous ones above. These are for DEFERRABILITY.
 '
 +/
enum
{
    SQL_INITIALLY_DEFERRED  = 5,
    SQL_INITIALLY_IMMEDIATE = 6,
    SQL_NOT_DEFERRABLE      = 7
}

/* Defines for SQLBindParameter and SQLProcedureColumns (returned in the result set) */
enum
{
    SQL_PARAM_TYPE_UNKNOWN = 0,
    SQL_PARAM_INPUT        = 1,
    SQL_PARAM_INPUT_OUTPUT = 2,
    SQL_RESULT_COL         = 3,
    SQL_PARAM_OUTPUT       = 4,
    SQL_RETURN_VALUE       = 5,

    /* Defines for SQLProcedures (returned in the result set) */
    SQL_PT_UNKNOWN         = 0,
    SQL_PT_PROCEDURE       = 1,
    SQL_PT_FUNCTION        = 2
}

// * This define is too large for RC *
static immutable char[] SQL_ODBC_KEYWORDS =
"ABSOLUTE,ACTION,ADA,ADD,ALL,ALLOCATE,ALTER,AND,ANY,ARE,AS," ~
"ASC,ASSERTION,AT,AUTHORIZATION,AVG," ~
"BEGIN,BETWEEN,BIT,BIT_LENGTH,BOTH,BY,CASCADE,CASCADED,CASE,CAST,CATALOG," ~
"CHAR,CHAR_LENGTH,CHARACTER,CHARACTER_LENGTH,CHECK,CLOSE,COALESCE," ~
"COLLATE,COLLATION,COLUMN,COMMIT,CONNECT,CONNECTION,CONSTRAINT," ~
"CONSTRAINTS,CONTINUE,CONVERT,CORRESPONDING,COUNT,CREATE,CROSS,CURRENT," ~
"CURRENT_DATE,CURRENT_TIME,CURRENT_TIMESTAMP,CURRENT_USER,CURSOR," ~
"DATE,DAY,DEALLOCATE,DEC,DECIMAL,DECLARE,DEFAULT,DEFERRABLE," ~
"DEFERRED,DELETE,DESC,DESCRIBE,DESCRIPTOR,DIAGNOSTICS,DISCONNECT," ~
"DISTINCT,DOMAIN,DOUBLE,DROP," ~
"ELSE,END,END-EXEC,ESCAPE,EXCEPT,EXCEPTION,EXEC,EXECUTE," ~
"EXISTS,EXTERNAL,EXTRACT," ~
"FALSE,FETCH,FIRST,FLOAT,FOR,FOREIGN,FORTRAN,FOUND,FROM,FULL," ~
"GET,GLOBAL,GO,GOTO,GRANT,GROUP,HAVING,HOUR," ~
"IDENTITY,IMMEDIATE,IN,INCLUDE,INDEX,INDICATOR,INITIALLY,INNER," ~
"INPUT,INSENSITIVE,INSERT,INT,INTEGER,INTERSECT,INTERVAL,INTO,IS,ISOLATION," ~
"JOIN,KEY,LANGUAGE,LAST,LEADING,LEFT,LEVEL,LIKE,LOCAL,LOWER," ~
"MATCH,MAX,MIN,MINUTE,MODULE,MONTH," ~
"NAMES,NATIONAL,NATURAL,NCHAR,NEXT,NO,NONE,NOT,NULL,NULLIF,NUMERIC," ~
"OCTET_LENGTH,OF,ON,ONLY,OPEN,OPTION,OR,ORDER,OUTER,OUTPUT,OVERLAPS," ~
"PAD,PARTIAL,PASCAL,PLI,POSITION,PRECISION,PREPARE,PRESERVE," ~
"PRIMARY,PRIOR,PRIVILEGES,PROCEDURE,PUBLIC," ~
"READ,REAL,REFERENCES,RELATIVE,RESTRICT,REVOKE,RIGHT,ROLLBACK,ROWS" ~
"SCHEMA,SCROLL,SECOND,SECTION,SELECT,SESSION,SESSION_USER,SET,SIZE," ~
"SMALLINT,SOME,SPACE,SQL,SQLCA,SQLCODE,SQLERROR,SQLSTATE,SQLWARNING," ~
"SUBSTRING,SUM,SYSTEM_USER," ~
"TABLE,TEMPORARY,THEN,TIME,TIMESTAMP,TIMEZONE_HOUR,TIMEZONE_MINUTE," ~
"TO,TRAILING,TRANSACTION,TRANSLATE,TRANSLATION,TRIM,TRUE," ~
"UNION,UNIQUE,UNKNOWN,UPDATE,UPPER,USAGE,USER,USING," ~
"VALUE,VALUES,VARCHAR,VARYING,VIEW,WHEN,WHENEVER,WHERE,WITH,WORK,WRITE," ~
"YEAR,ZONE";

/+
 ' ODBC v1.0+ ODBC
 ' Supports an iterative method of discovering and enumerating the attributes
 ' and attribute values required to connect to a data source. Each call to
 ' SQLBrowseConnect returns successive levels of attributes and attribute values.
 ' When all levels have been enumerated, a connection to the data source is
 ' completed and a complete connection string is returned by SQLBrowseConnect.
 ' A return code of SQL_SUCCESS or SQL_SUCCESS_WITH_INFO indicates that all
 ' connection information has been specified and the application is now connected
 ' to the data source.
 '
 +/
SQLRETURN SQLBrowseConnect
(
    /+ IN  +/ SQLHDBC     hdbc,
    /+ IN  +/ SQLCHAR     *szConnStrIn,
    /+ IN  +/ SQLSMALLINT cbConnStrIn,
    /+ OUT +/ SQLCHAR     *szConnStrOut,
    /+ IN  +/ SQLSMALLINT cbConnStrOutMax,
    /+ OUT +/ SQLSMALLINT *pcbConnStrOut
);

/+
 ' ODBC v3.0+ ODBC
 ' Performs bulk insertions and bulk bookmark operations,
 ' including update, delete, and fetch by bookmark.
 '
 ' -- Operation  --
 ' Operation to perform:
 ' SQL_ADD
 ' SQL_UPDATE_BY_BOOKMARK
 ' SQL_DELETE_BY_BOOKMARK
 ' SQL_FETCH_BY_BOOKMARK
 '
 +/
SQLRETURN SQLBulkOperations
(
    /+ IN  +/ SQLHSTMT    StatementHandle,
    /+ IN  +/ SQLSMALLINT Operation
);

/+
 ' ODBC v1.0+ ODBC
 ' Returns a list of columns and associated privileges for the
 ' specified table. The driver returns the information as a
 ' result set on the specified StatementHandle.
 '
 +/
SQLRETURN SQLColumnPrivileges
(
    /+ IN  +/ SQLHSTMT    hstmt,
    /+ IN  +/ SQLCHAR     *szCatalogName,
    /+ IN  +/ SQLSMALLINT cbCatalogName,
    /+ IN  +/ SQLCHAR     *szSchemaName,
    /+ IN  +/ SQLSMALLINT cbSchemaName,
    /+ IN  +/ SQLCHAR     *szTableName,
    /+ IN  +/ SQLSMALLINT cbTableName,
    /+ IN  +/ SQLCHAR     *szColumnName,
    /+ IN  +/ SQLSMALLINT cbColumnName
);

/+
 ' ODBC v1.0+ ODBC
 ' Returns the description of a parameter marker associated
 ' with a prepared SQL statement. This information is also
 ' available in the fields of the IPD.
 '
 ' -- pfNullable --
 ' Pointer to a buffer in which to return a value that indicates
 ' whether the parameter allows NULL values. This value is read
 ' from the SQL_DESC_NULLABLE field of the IPD. One of the following:
 '
 ' SQL_NO_NULLS: The parameter does not allow NULL values (this is the default value).
 ' SQL_NULLABLE: The parameter allows NULL values.
 ' SQL_NULLABLE_UNKNOWN: The driver cannot determine if the parameter allows NULL values.
 '
 +/
SQLRETURN SQLDescribeParam
(
    /+ IN  +/ SQLHSTMT     hstmt,
    /+ IN  +/ SQLUSMALLINT ipar,
    /+ OUT +/ SQLSMALLINT  *pfSqlType,
    /+ OUT +/ SQLUINTEGER  *pcbParamDef,
    /+ OUT +/ SQLSMALLINT  *pibScale,
    /+ OUT +/ SQLSMALLINT  *pfNullable
);

/+
 ' ODBC v1.0+ ODBC
 ' SQLForeignKeys can return:
 ' A list of foreign keys in the specified table (columns in the
 ' specified table that refer to primary keys in other tables).
 ' A list of foreign keys in other tables that refer to the primary
 ' key in the specified table. The driver returns each list as a
 ' result set on the specified statement.
 '
 +/
SQLRETURN SQLForeignKeys
(
    /+ IN  +/ SQLHSTMT    hstmt,
    /+ IN  +/ SQLCHAR     *szPkCatalogName,
    /+ IN  +/ SQLSMALLINT cbPkCatalogName,
    /+ IN  +/ SQLCHAR     *szPkSchemaName,
    /+ IN  +/ SQLSMALLINT cbPkSchemaName,
    /+ IN  +/ SQLCHAR     *szPkTableName,
    /+ IN  +/ SQLSMALLINT cbPkTableName,
    /+ IN  +/ SQLCHAR     *szFkCatalogName,
    /+ IN  +/ SQLSMALLINT cbFkCatalogName,
    /+ IN  +/ SQLCHAR     *szFkSchemaName,
    /+ IN  +/ SQLSMALLINT cbFkSchemaName,
    /+ IN  +/ SQLCHAR     *szFkTableName,
    /+ IN  +/ SQLSMALLINT cbFkTableName
);

/+
 ' ODBC v1.0+ ODBC
 ' Determines whether more results are available on a statement
 ' containing SELECT, UPDATE, INSERT, or DELETE statements and,
 ' if so, initializes processing for those results.
 '
 +/
SQLRETURN SQLMoreResults
(
    /+ IN  +/ SQLHSTMT hstmt
);

/+
 ' ODBC v1.0+ ODBC
 ' Returns the SQL string as modified by the driver.
 ' SQLNativeSql does not execute the SQL statement.
 '
 +/
SQLRETURN SQLNativeSql
(
    /+ IN  +/ SQLHDBC    hdbc,
    /+ IN  +/ SQLCHAR    *szSqlStrIn,
    /+ IN  +/ SQLINTEGER cbSqlStrIn,
    /+ OUT +/ SQLCHAR    *szSqlStr,
    /+ IN  +/ SQLINTEGER cbSqlStrMax,
    /+ OUT +/ SQLINTEGER *pcbSqlStr
);

/+
 ' ODBC v1.0+ ISO 92
 ' Returns the number of parameters in an SQL statement.
 '
 +/
SQLRETURN SQLNumParams
(
    /+ IN  +/ SQLHSTMT    hstmt,
    /+ OUT +/ SQLSMALLINT *pcpar
);

/+
 ' ODBC v1.0+ ODBC
 ' Returns the column names that make up the primary key
 ' for a table. The driver returns the information as a
 ' result set. This function does not support returning
 ' primary keys from multiple tables in a single call.
 '
 +/
SQLRETURN SQLPrimaryKeys
(
    /+ IN  +/ SQLHSTMT    hstmt,
    /+ IN  +/ SQLCHAR     *szCatalogName,
    /+ IN  +/ SQLSMALLINT cbCatalogName,
    /+ IN  +/ SQLCHAR     *szSchemaName,
    /+ IN  +/ SQLSMALLINT cbSchemaName,
    /+ IN  +/ SQLCHAR     *szTableName,
    /+ IN  +/ SQLSMALLINT cbTableName
);

/+
 ' ODBC v1.0+ ODBC
 ' Returns the list of input and output parameters, as
 ' well as the columns that make up the result set for
 ' the specified procedures. The driver returns the
 ' information as a result set on the specified statement.
 '
 +/
SQLRETURN SQLProcedureColumns
(
    /+ IN  +/ SQLHSTMT    hstmt,
    /+ IN  +/ SQLCHAR     *szCatalogName,
    /+ IN  +/ SQLSMALLINT cbCatalogName,
    /+ IN  +/ SQLCHAR     *szSchemaName,
    /+ IN  +/ SQLSMALLINT cbSchemaName,
    /+ IN  +/ SQLCHAR     *szProcName,
    /+ IN  +/ SQLSMALLINT cbProcName,
    /+ IN  +/ SQLCHAR     *szColumnName,
    /+ IN  +/ SQLSMALLINT cbColumnName
);

/+
 ' ODBC v1.0+ ODBC
 ' Returns the list of procedure names stored in a specific
 ' data source. Procedure is a generic term used to describe
 ' an executable object, or a named entity that can be invoked
 ' using input and output parameters.
 '
 +/
SQLRETURN SQLProcedures
(
    /+ IN  +/ SQLHSTMT    hstmt,
    /+ IN  +/ SQLCHAR     *szCatalogName,
    /+ IN  +/ SQLSMALLINT cbCatalogName,
    /+ IN  +/ SQLCHAR     *szSchemaName,
    /+ IN  +/ SQLSMALLINT cbSchemaName,
    /+ IN  +/ SQLCHAR     *szProcName,
    /+ IN  +/ SQLSMALLINT cbProcName
);

/+
 ' ODBC v1.0+ ODBC
 ' Sets the cursor position in a rowset and allows an
 ' application to refresh data in the rowset or to
 ' update or delete data in the result set.
 '
 ' -- fOperation --
 ' Operation to perform:
 ' SQL_POSITION
 ' SQL_REFRESH
 ' SQL_UPDATE
 ' SQL_DELETE
 '
 ' -- fLockType --
 ' Specifies how to lock the row after performing the
 ' operation specified in the Operation argument.
 ' SQL_LOCK_NO_CHANGE
 ' SQL_LOCK_EXCLUSIVE
 ' SQL_LOCK_UNLOCK
 '
 +/
SQLRETURN SQLSetPos
(
    /+ IN  +/ SQLHSTMT     hstmt,
    /+ IN  +/ SQLUSMALLINT irow,
    /+ IN  +/ SQLUSMALLINT fOperation,
    /+ IN  +/ SQLUSMALLINT fLockType
);

/+
 ' ODBC v1.0+ ODBC
 ' Returns a list of tables and the privileges associated
 ' with each table. The driver returns the information as
 ' a result set on the specified statement.
 '
 +/
SQLRETURN SQLTablePrivileges
(
    /+ IN  +/ SQLHSTMT    hstmt,
    /+ IN  +/ SQLCHAR     *szCatalogName,
    /+ IN  +/ SQLSMALLINT cbCatalogName,
    /+ IN  +/ SQLCHAR     *szSchemaName,
    /+ IN  +/ SQLSMALLINT cbSchemaName,
    /+ IN  +/ SQLCHAR     *szTableName,
    /+ IN  +/ SQLSMALLINT cbTableName
);

/+
 ' ODBC v2.0 ODBC
 ' Lists driver descriptions and driver attribute keywords.
 ' This function is implemented solely by the Driver Manager.
 '
 ' -- fDirection --
 ' Determines whether the Driver Manager fetches the next driver
 ' description in the list (SQL_FETCH_NEXT) or whether the search
 ' starts from the beginning of the list (SQL_FETCH_FIRST).
 '
 +/
SQLRETURN SQLDrivers
(
    /+ IN  +/ SQLHENV      henv,
    /+ IN  +/ SQLUSMALLINT fDirection,
    /+ OUT +/ SQLCHAR      *szDriverDesc,
    /+ IN  +/ SQLSMALLINT  cbDriverDescMax,
    /+ OUT +/ SQLSMALLINT  *pcbDriverDesc,
    /+ OUT +/ SQLCHAR      *szDriverAttributes,
    /+ IN  +/ SQLSMALLINT  cbDrvrAttrMax,
    /+ OUT +/ SQLSMALLINT  *pcbDrvrAttr
);

/+
 ' ODBC v2.0+ ODBC
 ' Binds a buffer to a parameter marker in an SQL statement.
 ' SQLBindParameter supports binding to a Unicode C data type,
 ' even if the underlying driver does not support Unicode data.
 '
 +/
SQLRETURN SQLBindParameter
(
    /+ IN    +/ SQLHSTMT     hstmt,
    /+ IN    +/ SQLUSMALLINT ipar,
    /+ IN    +/ SQLSMALLINT  fParamType,
    /+ IN    +/ SQLSMALLINT  fCType,
    /+ IN    +/ SQLSMALLINT  fSqlType,
    /+ IN    +/ SQLUINTEGER  cbColDef,
    /+ IN    +/ SQLSMALLINT  ibScale,
    /+ IN    +/ SQLPOINTER   rgbValue,
    /+ INOUT +/ SQLINTEGER   cbValueMax,
    /+ IN    +/ SQLINTEGER   *pcbValue
);

/+----------------------+
 | Deprecated Functions |
 +----------------------+/

/+
 ' In ODBC 3.x, the ODBC 2.0 function SQLColAttributes has
 ' been replaced by SQLColAttribute.
 '
 +/
SQLRETURN SQLColAttributes
(
    SQLHSTMT     hstmt,
    SQLUSMALLINT icol,
    SQLUSMALLINT fDescType,
    SQLPOINTER   rgbDesc,
    SQLSMALLINT  cbDescMax,
    SQLSMALLINT  *pcbDesc,
    SQLINTEGER   *pfDesc
);

/+
 ' In ODBC 3.x, SQLExtendedFetch has been replaced by
 ' SQLFetchScroll. ODBC 3.x applications should not
 ' call SQLExtendedFetch; instead they should call
 ' SQLFetchScroll.
 '
 +/
SQLRETURN SQLExtendedFetch
(
    SQLHSTMT     hstmt,
    SQLUSMALLINT fFetchType,
    SQLINTEGER   irow,
    SQLUINTEGER  *pcrow,
    SQLUSMALLINT *rgfRowStatus
);

/+
 ' SQLParamOptions has been replaced in ODBC 3.x by calls to SQLSetStmtAttr.
 '
 +/
SQLRETURN SQLParamOptions
(
    SQLHSTMT    hstmt,
    SQLUINTEGER crow,
    SQLUINTEGER *pirow
);

// end Deprecated Functions
