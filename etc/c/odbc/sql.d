/**
Declarations for interfacing with the ODBC library.

Adapted with minimal changes from the work of David L. Davis
(refer to the $(WEB
forum.dlang.org/post/cfk7ql$(DOLLAR)1p4n$(DOLLAR)1@digitaldaemon.com,
original announcement)).

`etc.c.odbc.sql` is the the main include for ODBC v3.0+ Core functions,
corresponding to the `sql.h` C header file. It `import`s `public`ly
`etc.c.odbc.sqltypes` for conformity with the C header.

See_Also: $(LUCKY ODBC API Reference on MSN Online)
*/

module etc.c.odbc.sql;

public import etc.c.odbc.sqltypes;

extern (Windows):

// * special length/indicator values *
enum int SQL_NULL_DATA    = (-1);
enum int SQL_DATA_AT_EXEC = (-2);

// * return values from functions *
enum
{
    SQL_SUCCESS           = 0,
    SQL_SUCCESS_WITH_INFO = 1,
    SQL_NO_DATA           = 100,
    SQL_ERROR             = (-1),
    SQL_INVALID_HANDLE    = (-2),
    SQL_STILL_EXECUTING   = 2,
    SQL_NEED_DATA         = 99
}

/* test for SQL_SUCCESS or SQL_SUCCESS_WITH_INFO */
bool SQL_SUCCEEDED()(uint rc) { return (rc & ~1U) == 0; }

enum
{
    // * flags for null-terminated string *
    SQL_NTS                         = (-3),
    SQL_NTSL                        = (-3L),

    // * maximum message length *
    SQL_MAX_MESSAGE_LENGTH          = 512,

    // * date/time length constants *
    SQL_DATE_LEN                    = 10,
    SQL_TIME_LEN                    =  8,  /* add P+1 if precision is nonzero */
    SQL_TIMESTAMP_LEN               = 19,  /* add P+1 if precision is nonzero */

    // * handle type identifiers *
    SQL_HANDLE_ENV                  = 1,
    SQL_HANDLE_DBC                  = 2,
    SQL_HANDLE_STMT                 = 3,
    SQL_HANDLE_DESC                 = 4,

    // * environment attribute *
    SQL_ATTR_OUTPUT_NTS             = 10001,

    // * connection attributes *
    SQL_ATTR_AUTO_IPD               = 10001,
    SQL_ATTR_METADATA_ID            = 10014,

    // * statement attributes *
    SQL_ATTR_APP_ROW_DESC           = 10010,
    SQL_ATTR_APP_PARAM_DESC         = 10011,
    SQL_ATTR_IMP_ROW_DESC           = 10012,
    SQL_ATTR_IMP_PARAM_DESC         = 10013,
    SQL_ATTR_CURSOR_SCROLLABLE      = (-1),
    SQL_ATTR_CURSOR_SENSITIVITY     = (-2),

    // * SQL_ATTR_CURSOR_SCROLLABLE values *
    SQL_NONSCROLLABLE               = 0,
    SQL_SCROLLABLE                  = 1,

    // * identifiers of fields in the SQL descriptor *
    SQL_DESC_COUNT                  = 1001,
    SQL_DESC_TYPE                   = 1002,
    SQL_DESC_LENGTH                 = 1003,
    SQL_DESC_OCTET_LENGTH_PTR       = 1004,
    SQL_DESC_PRECISION              = 1005,
    SQL_DESC_SCALE                  = 1006,
    SQL_DESC_DATETIME_INTERVAL_CODE = 1007,
    SQL_DESC_NULLABLE               = 1008,
    SQL_DESC_INDICATOR_PTR          = 1009,
    SQL_DESC_DATA_PTR               = 1010,
    SQL_DESC_NAME                   = 1011,
    SQL_DESC_UNNAMED                = 1012,
    SQL_DESC_OCTET_LENGTH           = 1013,
    SQL_DESC_ALLOC_TYPE             = 1099
}

// * identifiers of fields in the diagnostics area *
enum
{
    SQL_DIAG_RETURNCODE            = 1,
    SQL_DIAG_NUMBER                = 2,
    SQL_DIAG_ROW_COUNT             = 3,
    SQL_DIAG_SQLSTATE              = 4,
    SQL_DIAG_NATIVE                = 5,
    SQL_DIAG_MESSAGE_TEXT          = 6,
    SQL_DIAG_DYNAMIC_FUNCTION      = 7,
    SQL_DIAG_CLASS_ORIGIN          = 8,
    SQL_DIAG_SUBCLASS_ORIGIN       = 9,
    SQL_DIAG_CONNECTION_NAME       = 10,
    SQL_DIAG_SERVER_NAME           = 11,
    SQL_DIAG_DYNAMIC_FUNCTION_CODE = 12
}

// * dynamic function codes *
enum
{
    SQL_DIAG_ALTER_DOMAIN          = 3,
    SQL_DIAG_ALTER_TABLE           = 4,
    SQL_DIAG_CALL                  = 7,
    SQL_DIAG_CREATE_ASSERTION      = 6,
    SQL_DIAG_CREATE_CHARACTER_SET  = 8,
    SQL_DIAG_CREATE_COLLATION      = 10,
    SQL_DIAG_CREATE_DOMAIN         = 23,
    SQL_DIAG_CREATE_INDEX          = (-1),
    SQL_DIAG_CREATE_SCHEMA         = 64,
    SQL_DIAG_CREATE_TABLE          = 77,
    SQL_DIAG_CREATE_TRANSLATION    = 79,
    SQL_DIAG_CREATE_VIEW           = 84,
    SQL_DIAG_DELETE_WHERE          = 19,
    SQL_DIAG_DROP_ASSERTION        = 24,
    SQL_DIAG_DROP_CHARACTER_SET    = 25,
    SQL_DIAG_DROP_COLLATION        = 26,
    SQL_DIAG_DROP_DOMAIN           = 27,
    SQL_DIAG_DROP_INDEX            = (-2),
    SQL_DIAG_DROP_SCHEMA           = 31,
    SQL_DIAG_DROP_TABLE            = 32,
    SQL_DIAG_DROP_TRANSLATION      = 33,
    SQL_DIAG_DROP_VIEW             = 36,
    SQL_DIAG_DYNAMIC_DELETE_CURSOR = 38,
    SQL_DIAG_DYNAMIC_UPDATE_CURSOR = 81,
    SQL_DIAG_GRANT                 = 48,
    SQL_DIAG_INSERT                = 50,
    SQL_DIAG_REVOKE                = 59,
    SQL_DIAG_SELECT_CURSOR         = 85,
    SQL_DIAG_UNKNOWN_STATEMENT     = 0,
    SQL_DIAG_UPDATE_WHERE          = 82
}

enum
{
    // * SQL data type codes *
    SQL_UNKNOWN_TYPE   = 0,
    SQL_CHAR           = 1,
    SQL_NUMERIC        = 2,
    SQL_DECIMAL        = 3,
    SQL_INTEGER        = 4,
    SQL_SMALLINT       = 5,
    SQL_FLOAT          = 6,
    SQL_REAL           = 7,
    SQL_DOUBLE         = 8,
    SQL_DATETIME       = 9,
    SQL_VARCHAR        = 12,

    // * One-parameter shortcuts for date/time data types *
    SQL_TYPE_DATE      = 91,
    SQL_TYPE_TIME      = 92,
    SQL_TYPE_TIMESTAMP = 93
}

// * Statement attribute values for cursor sensitivity *
enum
{
    SQL_UNSPECIFIED = 0,
    SQL_INSENSITIVE = 1,
    SQL_SENSITIVE   = 2
}

// * GetTypeInfo() request for all data types *
enum
{
    SQL_ALL_TYPES = 0
}

// * Default conversion code for SQLBindCol(), SQLBindParam() and SQLGetData() *
enum { SQL_DEFAULT = 99 }

/+ SQLGetData() code indicating that the application row descriptor
 ' specifies the data type
 +/
enum
{
    SQL_ARD_TYPE = (-99)
}

// * SQL date/time type subcodes *
enum
{
    SQL_CODE_DATE      = 1,
    SQL_CODE_TIME      = 2,
    SQL_CODE_TIMESTAMP = 3
}

// * CLI option values *
enum
{
    SQL_FALSE = 0,
    SQL_TRUE  = 1
}

// * values of NULLABLE field in descriptor *
enum
{
    SQL_NO_NULLS = 0,
    SQL_NULLABLE = 1
}

/+ Value returned by SQLGetTypeInfo() to denote that it is
 ' not known whether or not a data type supports null values.
 +/
enum { SQL_NULLABLE_UNKNOWN = 2 }

/+ Values returned by SQLGetTypeInfo() to show WHERE clause
 ' supported
 +/
enum
{
    SQL_PRED_NONE  = 0,
    SQL_PRED_CHAR  = 1,
    SQL_PRED_BASIC = 2
}

// * values of UNNAMED field in descriptor *
enum
{
    SQL_NAMED   = 0,
    SQL_UNNAMED = 1
}

// * values of ALLOC_TYPE field in descriptor *
enum
{
    SQL_DESC_ALLOC_AUTO = 1,
    SQL_DESC_ALLOC_USER = 2
}

// * FreeStmt() options *
enum
{
    SQL_CLOSE        = 0,
    SQL_DROP         = 1,
    SQL_UNBIND       = 2,
    SQL_RESET_PARAMS = 3
}

// * Codes used for FetchOrientation in SQLFetchScroll(), and in SQLDataSources() *
enum
{
    SQL_FETCH_NEXT  = 1,
    SQL_FETCH_FIRST = 2
}

// * Other codes used for FetchOrientation in SQLFetchScroll() *
enum
{
    SQL_FETCH_LAST     = 3,
    SQL_FETCH_PRIOR    = 4,
    SQL_FETCH_ABSOLUTE = 5,
    SQL_FETCH_RELATIVE = 6
}

// * SQLEndTran() options *
enum
{
    SQL_COMMIT   = 0,
    SQL_ROLLBACK = 1
}

// * null handles returned by SQLAllocHandle() *
enum SQLHANDLE SQL_NULL_HENV  = cast(SQLHANDLE)0;
enum SQLHANDLE SQL_NULL_HDBC  = cast(SQLHANDLE)0;
enum SQLHANDLE SQL_NULL_HSTMT = cast(SQLHANDLE)0;
enum SQLHANDLE SQL_NULL_HDESC = cast(SQLHANDLE)0;

// * null handle used in place of parent handle when allocating HENV *
enum SQLHANDLE SQL_NULL_HANDLE = cast(SQLHANDLE)0L;

// * Values that may appear in the result set of SQLSpecialColumns() *
enum
{
    SQL_SCOPE_CURROW      = 0,
    SQL_SCOPE_TRANSACTION = 1,
    SQL_SCOPE_SESSION     = 2
}

enum
{
    SQL_PC_UNKNOWN    = 0,
    SQL_PC_NON_PSEUDO = 1,
    SQL_PC_PSEUDO     = 2
}

// * Reserved value for the IdentifierType argument of SQLSpecialColumns() *
enum
{
    SQL_ROW_IDENTIFIER = 1
}

// * Reserved values for UNIQUE argument of SQLStatistics() *
enum
{
    SQL_INDEX_UNIQUE    = 0,
    SQL_INDEX_ALL       = 1,

    // * Values that may appear in the result set of SQLStatistics() *
    SQL_INDEX_CLUSTERED = 1,
    SQL_INDEX_HASHED    = 2,
    SQL_INDEX_OTHER     = 3
}

// * SQLGetFunctions() values to identify ODBC APIs *
enum
{
    SQL_API_SQLALLOCCONNECT     =    1,
    SQL_API_SQLALLOCENV         =    2,
    SQL_API_SQLALLOCHANDLE      = 1001,
    SQL_API_SQLALLOCSTMT        =    3,
    SQL_API_SQLBINDCOL          =    4,
    SQL_API_SQLBINDPARAM        = 1002,
    SQL_API_SQLCANCEL           =    5,
    SQL_API_SQLCLOSECURSOR      = 1003,
    SQL_API_SQLCOLATTRIBUTE     =    6,
    SQL_API_SQLCOLUMNS          =   40,
    SQL_API_SQLCONNECT          =    7,
    SQL_API_SQLCOPYDESC         = 1004,
    SQL_API_SQLDATASOURCES      =   57,
    SQL_API_SQLDESCRIBECOL      =    8,
    SQL_API_SQLDISCONNECT       =    9,
    SQL_API_SQLENDTRAN          = 1005,
    SQL_API_SQLERROR            =   10,
    SQL_API_SQLEXECDIRECT       =   11,
    SQL_API_SQLEXECUTE          =   12,
    SQL_API_SQLFETCH            =   13,
    SQL_API_SQLFETCHSCROLL      = 1021,
    SQL_API_SQLFREECONNECT      =   14,
    SQL_API_SQLFREEENV          =   15,
    SQL_API_SQLFREEHANDLE       = 1006,
    SQL_API_SQLFREESTMT         =   16,
    SQL_API_SQLGETCONNECTATTR   = 1007,
    SQL_API_SQLGETCONNECTOPTION =   42,
    SQL_API_SQLGETCURSORNAME    =   17,
    SQL_API_SQLGETDATA          =   43,
    SQL_API_SQLGETDESCFIELD     = 1008,
    SQL_API_SQLGETDESCREC       = 1009,
    SQL_API_SQLGETDIAGFIELD     = 1010,
    SQL_API_SQLGETDIAGREC       = 1011,
    SQL_API_SQLGETENVATTR       = 1012,
    SQL_API_SQLGETFUNCTIONS     =   44,
    SQL_API_SQLGETINFO          =   45,
    SQL_API_SQLGETSTMTATTR      = 1014,
    SQL_API_SQLGETSTMTOPTION    =   46,
    SQL_API_SQLGETTYPEINFO      =   47,
    SQL_API_SQLNUMRESULTCOLS    =   18,
    SQL_API_SQLPARAMDATA        =   48,
    SQL_API_SQLPREPARE          =   19,
    SQL_API_SQLPUTDATA          =   49,
    SQL_API_SQLROWCOUNT         =   20,
    SQL_API_SQLSETCONNECTATTR   = 1016,
    SQL_API_SQLSETCONNECTOPTION =   50,
    SQL_API_SQLSETCURSORNAME    =   21,
    SQL_API_SQLSETDESCFIELD     = 1017,
    SQL_API_SQLSETDESCREC       = 1018,
    SQL_API_SQLSETENVATTR       = 1019,
    SQL_API_SQLSETPARAM         =   22,
    SQL_API_SQLSETSTMTATTR      = 1020,
    SQL_API_SQLSETSTMTOPTION    =   51,
    SQL_API_SQLSPECIALCOLUMNS   =   52,
    SQL_API_SQLSTATISTICS       =   53,
    SQL_API_SQLTABLES           =   54,
    SQL_API_SQLTRANSACT         =   23
}

// * Information requested by SQLGetInfo() *
enum
{
    SQL_MAX_DRIVER_CONNECTIONS        = 0,
    SQL_MAXIMUM_DRIVER_CONNECTIONS    = SQL_MAX_DRIVER_CONNECTIONS,
    SQL_MAX_CONCURRENT_ACTIVITIES     = 1,
    SQL_MAXIMUM_CONCURRENT_ACTIVITIES = SQL_MAX_CONCURRENT_ACTIVITIES,
    SQL_DATA_SOURCE_NAME              = 2,
    SQL_FETCH_DIRECTION               = 8,
    SQL_SERVER_NAME                   = 13,
    SQL_SEARCH_PATTERN_ESCAPE         = 14,
    SQL_DBMS_NAME                     = 17,
    SQL_DBMS_VER                      = 18,
    SQL_ACCESSIBLE_TABLES             = 19,
    SQL_ACCESSIBLE_PROCEDURES         = 20,
    SQL_CURSOR_COMMIT_BEHAVIOR        = 23,
    SQL_DATA_SOURCE_READ_ONLY         = 25,
    SQL_DEFAULT_TXN_ISOLATION         = 26,
    SQL_IDENTIFIER_CASE               = 28,
    SQL_IDENTIFIER_QUOTE_CHAR         = 29,
    SQL_MAX_COLUMN_NAME_LEN           = 30,
    SQL_MAXIMUM_COLUMN_NAME_LENGTH    = SQL_MAX_COLUMN_NAME_LEN,
    SQL_MAX_CURSOR_NAME_LEN           = 31,
    SQL_MAXIMUM_CURSOR_NAME_LENGTH    = SQL_MAX_CURSOR_NAME_LEN,
    SQL_MAX_SCHEMA_NAME_LEN           = 32,
    SQL_MAXIMUM_SCHEMA_NAME_LENGTH    = SQL_MAX_SCHEMA_NAME_LEN,
    SQL_MAX_CATALOG_NAME_LEN          = 34,
    SQL_MAXIMUM_CATALOG_NAME_LENGTH   = SQL_MAX_CATALOG_NAME_LEN,
    SQL_MAX_TABLE_NAME_LEN            = 35,
    SQL_SCROLL_CONCURRENCY            = 43,
    SQL_TXN_CAPABLE                   = 46,
    SQL_TRANSACTION_CAPABLE           = SQL_TXN_CAPABLE,
    SQL_USER_NAME                     = 47,
    SQL_TXN_ISOLATION_OPTION          = 72,
    SQL_TRANSACTION_ISOLATION_OPTION  = SQL_TXN_ISOLATION_OPTION,
    SQL_INTEGRITY                     = 73,
    SQL_GETDATA_EXTENSIONS            = 81,
    SQL_NULL_COLLATION                = 85,
    SQL_ALTER_TABLE                   = 86,
    SQL_ORDER_BY_COLUMNS_IN_SELECT    = 90,
    SQL_SPECIAL_CHARACTERS            = 94,
    SQL_MAX_COLUMNS_IN_GROUP_BY       = 97,
    SQL_MAXIMUM_COLUMNS_IN_GROUP_BY   = SQL_MAX_COLUMNS_IN_GROUP_BY,
    SQL_MAX_COLUMNS_IN_INDEX          = 98,
    SQL_MAXIMUM_COLUMNS_IN_INDEX      = SQL_MAX_COLUMNS_IN_INDEX,
    SQL_MAX_COLUMNS_IN_ORDER_BY       = 99,
    SQL_MAXIMUM_COLUMNS_IN_ORDER_BY   = SQL_MAX_COLUMNS_IN_ORDER_BY,
    SQL_MAX_COLUMNS_IN_SELECT         = 100,
    SQL_MAXIMUM_COLUMNS_IN_SELECT     = SQL_MAX_COLUMNS_IN_SELECT,
    SQL_MAX_COLUMNS_IN_TABLE          = 101,
    SQL_MAX_INDEX_SIZE                = 102,
    SQL_MAXIMUM_INDEX_SIZE            = SQL_MAX_INDEX_SIZE,
    SQL_MAX_ROW_SIZE                  = 104,
    SQL_MAXIMUM_ROW_SIZE              = SQL_MAX_ROW_SIZE,
    SQL_MAX_STATEMENT_LEN             = 105,
    SQL_MAXIMUM_STATEMENT_LENGTH      = SQL_MAX_STATEMENT_LEN,
    SQL_MAX_TABLES_IN_SELECT          = 106,
    SQL_MAXIMUM_TABLES_IN_SELECT      = SQL_MAX_TABLES_IN_SELECT,
    SQL_MAX_USER_NAME_LEN             = 107,
    SQL_MAXIMUM_USER_NAME_LENGTH      = SQL_MAX_USER_NAME_LEN,
    SQL_OJ_CAPABILITIES               = 115,
    SQL_OUTER_JOIN_CAPABILITIES       = SQL_OJ_CAPABILITIES
}

enum
{
    SQL_XOPEN_CLI_YEAR            = 10000,
    SQL_CURSOR_SENSITIVITY        = 10001,
    SQL_DESCRIBE_PARAMETER        = 10002,
    SQL_CATALOG_NAME              = 10003,
    SQL_COLLATION_SEQ             = 10004,
    SQL_MAX_IDENTIFIER_LEN        = 10005,
    SQL_MAXIMUM_IDENTIFIER_LENGTH = SQL_MAX_IDENTIFIER_LEN
}

// * SQL_ALTER_TABLE bitmasks *
enum
{
    SQL_AT_ADD_COLUMN     = 0x00000001L,
    SQL_AT_DROP_COLUMN    = 0x00000002L,
    SQL_AT_ADD_CONSTRAINT = 0x00000008L
}

/+ The following bitmasks are ODBC extensions and defined in sqlext.d
enum : ulong
{
    SQL_AT_COLUMN_SINGLE                  = 0x00000020L,
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
+/

// * SQL_ASYNC_MODE values *
enum
{
    SQL_AM_NONE       = 0,
    SQL_AM_CONNECTION = 1,
    SQL_AM_STATEMENT  = 2
}

// * SQL_CURSOR_COMMIT_BEHAVIOR values *
enum
{
    SQL_CB_DELETE   = 0,
    SQL_CB_CLOSE    = 1,
    SQL_CB_PRESERVE = 2
}

// * SQL_FETCH_DIRECTION bitmasks *
enum
{
    SQL_FD_FETCH_NEXT     = 0x00000001L,
    SQL_FD_FETCH_FIRST    = 0x00000002L,
    SQL_FD_FETCH_LAST     = 0x00000004L,
    SQL_FD_FETCH_PRIOR    = 0x00000008L,
    SQL_FD_FETCH_ABSOLUTE = 0x00000010L,
    SQL_FD_FETCH_RELATIVE = 0x00000020L
}

// * SQL_GETDATA_EXTENSIONS bitmasks *
enum
{
    SQL_GD_ANY_COLUMN = 0x00000001L,
    SQL_GD_ANY_ORDER  = 0x00000002L
}

// * SQL_IDENTIFIER_CASE values *
enum
{
    SQL_IC_UPPER     = 1,
    SQL_IC_LOWER     = 2,
    SQL_IC_SENSITIVE = 3,
    SQL_IC_MIXED     = 4
}

// * SQL_OJ_CAPABILITIES bitmasks *
// * OJ means 'outer join' *
enum
{
    SQL_OJ_LEFT               = 0x00000001L,
    SQL_OJ_RIGHT              = 0x00000002L,
    SQL_OJ_FULL               = 0x00000004L,
    SQL_OJ_NESTED             = 0x00000008L,
    SQL_OJ_NOT_ORDERED        = 0x00000010L,
    SQL_OJ_INNER              = 0x00000020L,
    SQL_OJ_ALL_COMPARISON_OPS = 0x00000040L
}

// * SQL_SCROLL_CONCURRENCY bitmasks *
enum
{
    SQL_SCCO_READ_ONLY  = 0x00000001L,
    SQL_SCCO_LOCK       = 0x00000002L,
    SQL_SCCO_OPT_ROWVER = 0x00000004L,
    SQL_SCCO_OPT_VALUES = 0x00000008L
}

// * SQL_TXN_CAPABLE values *
enum
{
    SQL_TC_NONE       = 0,
    SQL_TC_DML        = 1,
    SQL_TC_ALL        = 2,
    SQL_TC_DDL_COMMIT = 3,
    SQL_TC_DDL_IGNORE = 4
}

// * SQL_TXN_ISOLATION_OPTION bitmasks *
enum
{
    SQL_TXN_READ_UNCOMMITTED         = 0x00000001L,
    SQL_TRANSACTION_READ_UNCOMMITTED = SQL_TXN_READ_UNCOMMITTED,
    SQL_TXN_READ_COMMITTED           = 0x00000002L,
    SQL_TRANSACTION_READ_COMMITTED   = SQL_TXN_READ_COMMITTED,
    SQL_TXN_REPEATABLE_READ          = 0x00000004L,
    SQL_TRANSACTION_REPEATABLE_READ  = SQL_TXN_REPEATABLE_READ,
    SQL_TXN_SERIALIZABLE             = 0x00000008L,
    SQL_TRANSACTION_SERIALIZABLE     = SQL_TXN_SERIALIZABLE
}

// * SQL_NULL_COLLATION values *
enum
{
    SQL_NC_HIGH = 0,
    SQL_NC_LOW  = 1
}

/+
 ' ODBC v3.0+ ISO 92
 ' Allocates an environment, connection, statement, or descriptor handle.
 '
 ' -- HandleTypes --
 ' SQL_HANDLE_ENV
 ' SQL_HANDLE_DBC
 ' SQL_HANDLE_DESC
 ' SQL_HANDLE_STMT
 '
 ' -- InputHandle --
 ' The input handle in whose context the new handle is to be allocated.
 ' If HandleType is SQL_HANDLE_ENV, this is SQL_NULL_HANDLE. If HandleType
 ' is SQL_HANDLE_DBC, this must be an environment handle, and if it is
 ' SQL_HANDLE_STMT or SQL_HANDLE_DESC, it must be a connection handle.
 '
 +/
SQLRETURN SQLAllocHandle
(
    /+ IN  +/ SQLSMALLINT HandleType,
    /+ IN  +/ SQLHANDLE   InputHandle,
    /+ OUT +/ SQLHANDLE   *OutputHandle
);

/+
 ' ODBC v1.0+ ISO 92
 ' Binds application data buffers to columns in the result set.
 '
 +/
SQLRETURN SQLBindCol
(
    /+ IN     +/ SQLHSTMT     StatementHandle,
    /+ IN     +/ SQLUSMALLINT ColumnNumber,
    /+ IN     +/ SQLSMALLINT  TargetType,
    /+ INOUT  +/ SQLPOINTER   TargetValue,
    /+ IN     +/ SQLINTEGER   BufferLength,
    /+ INOUT  +/ SQLINTEGER   *StrLen_or_Ind
);

SQLRETURN SQLBindParam
(
    SQLHSTMT     StatementHandle,
    SQLUSMALLINT ParameterNumber,
    SQLSMALLINT  ValueType,
    SQLSMALLINT  ParameterType,
    SQLUINTEGER  LengthPrecision,
    SQLSMALLINT  ParameterScale,
    SQLPOINTER   ParameterValue,
    SQLINTEGER   *StrLen_or_Ind
);

/+
 ' ODBC v1.0+ ISO 92
 ' Cancels the processing on a statement.
 '
 +/
SQLRETURN SQLCancel
(
    /+ IN  +/ SQLHSTMT StatementHandle
);

/+
 ' ODBC v3.0+ ISO 92
 ' Closes a cursor that has been opened on a statement and discards pending results.
 '
 +/
SQLRETURN SQLCloseCursor
(
    SQLHSTMT StatementHandle
);

/+
 ' ODBC v3.0+ ISO 92
 ' Returns descriptor information for a column in a result set.
 ' Descriptor information is returned as a character string, a 32-bit
 ' descriptor-dependent value, or an integer value.
 '
 +/
SQLRETURN SQLColAttribute
(
    /+ IN  +/ SQLHSTMT     StatementHandle,
    /+ IN  +/ SQLUSMALLINT ColumnNumber,
    /+ IN  +/ SQLUSMALLINT FieldIdentifier,
    /+ OUT +/ SQLPOINTER   CharacterAttribute,
    /+ IN  +/ SQLSMALLINT  BufferLength,
    /+ OUT +/ SQLSMALLINT  *StringLength,
    /+ OUT +/ SQLPOINTER   NumericAttribute
);

/+
 ' ODBC v1.0+ X/Open
 ' Returns the list of column names in specified tables. The driver
 ' returns this information as a result set on the specified StatementHandle.
 '
 +/
SQLRETURN SQLColumns
(
    /+ IN  +/ SQLHSTMT    StatementHandle,
    /+ IN  +/ SQLCHAR     *CatalogName,
    /+ IN  +/ SQLSMALLINT NameLength1,
    /+ IN  +/ SQLCHAR     *SchemaName,
    /+ IN  +/ SQLSMALLINT NameLength2,
    /+ IN  +/ SQLCHAR     *TableName,
    /+ IN  +/ SQLSMALLINT NameLength3,
    /+ IN  +/ SQLCHAR     *ColumnName,
    /+ IN  +/ SQLSMALLINT NameLength4
);

/+
 ' ODBC v1.0+ ISO 92
 ' Establishes connections to a driver and a data source. The connection
 ' handle references storage of all information about the connection to
 ' the data source, including status, transaction state, and error information.
 '
 +/
SQLRETURN SQLConnect
(
    /+ IN  +/ SQLHDBC     ConnectionHandle,
    /+ IN  +/ SQLCHAR     *ServerName,
    /+ IN  +/ SQLSMALLINT NameLength1,
    /+ IN  +/ SQLCHAR     *UserName,
    /+ IN  +/ SQLSMALLINT NameLength2,
    /+ IN  +/ SQLCHAR     *Authentication,
    /+ IN  +/ SQLSMALLINT NameLength3
);

/+
 ' ODBC v3.0+ ISO 92
 ' Copies descriptor information from one descriptor handle to another.
 '
 +/
SQLRETURN SQLCopyDesc
(
    /+ IN  +/ SQLHDESC SourceDescHandle,
    /+ IN  +/ SQLHDESC TargetDescHandle
);

/+
 ' ODBC v1.0+ ISO 92
 ' Returns information about a data source. This function is implemented
 ' solely by the Driver Manager.
 '
 +/
SQLRETURN SQLDataSources
(
    /+ IN  +/ SQLHENV      EnvironmentHandle,
    /+ IN  +/ SQLUSMALLINT Direction,
    /+ OUT +/ SQLCHAR      *ServerName,
    /+ IN  +/ SQLSMALLINT  BufferLength1,
    /+ OUT +/ SQLSMALLINT  *NameLength1,
    /+ OUT +/ SQLCHAR      *Description,
    /+ IN  +/ SQLSMALLINT  BufferLength2,
    /+ OUT +/ SQLSMALLINT  *NameLength2
);

/+
 ' ODBC v1.0+ ISO 92
 ' Returns the result descriptor column name, type, column size,
 ' decimal digits, and nullability for one column in the result set.
 ' This information also is available in the fields of the IRD.
 '
 +/
SQLRETURN SQLDescribeCol
(
    /+ IN  +/ SQLHSTMT     StatementHandle,
    /+ IN  +/ SQLUSMALLINT ColumnNumber,
    /+ OUT +/ SQLCHAR      *ColumnName,
    /+ IN  +/ SQLSMALLINT  BufferLength,
    /+ OUT +/ SQLSMALLINT  *NameLength,
    /+ OUT +/ SQLSMALLINT  *DataType,
    /+ OUT +/ SQLUINTEGER  *ColumnSize,
    /+ OUT +/ SQLSMALLINT  *DecimalDigits,
    /+ OUT +/ SQLSMALLINT  *Nullable
);

/+
 ' ODBC v1.0+ ISO 92
 ' Closes the connection associated with a specific connection handle.
 '
 +/
SQLRETURN SQLDisconnect
(
    /+ IN  +/ SQLHDBC ConnectionHandle
);

/+
 ' ODBC v3.0+ ISO 92
 ' Requests a commit or rollback operation for all active operations on all
 ' statements associated with a connection. SQLEndTran can also request that
 ' a commit or rollback operation be performed for all connections associated
 ' with an environment.
 '
 ' -- HandleType --
 ' Contains either SQL_HANDLE_ENV (if Handle is an environment handle)
 ' or SQL_HANDLE_DBC (if Handle is a connection handle).
 '
 ' -- Handle --
 ' The handle, of the type indicated by HandleType, indicating the scope of the transaction.
 '
 ' -- CompletionType --
 ' One of the following two values:
 ' SQL_COMMIT
 ' SQL_ROLLBACK
 '
 +/
SQLRETURN SQLEndTran
(
    /+ IN  +/ SQLSMALLINT HandleType,
    /+ IN  +/ SQLHANDLE   Handle,
    /+ IN  +/ SQLSMALLINT CompletionType
);

/+
 ' ODBC v1.0+ ISO 92
 ' Executes a preparable statement, using the current values of the
 ' parameter marker variables if any parameters exist in the statement.
 ' SQLExecDirect is the fastest way to submit an SQL statement for
 ' one-time execution.
 '
 +/
SQLRETURN SQLExecDirect
(
    /+ IN  +/ SQLHSTMT   StatementHandle,
    /+ IN  +/ SQLCHAR    *StatementText,
    /+ IN  +/ SQLINTEGER TextLength
);

/+
 ' ODBC v1.0+ ISO 92
 ' Executes a prepared statement, using the current values of the parameter
 ' marker variables if any parameter markers exist in the statement.
 '
 +/
SQLRETURN SQLExecute
(
    /+ IN  +/ SQLHSTMT StatementHandle
);

/+
 ' ODBC v1.0+ ISO 92
 ' Fetches the next rowset of data from the result set and returns
 ' data for all bound columns.
 '
 +/
SQLRETURN SQLFetch
(
    /+ IN  +/ SQLHSTMT StatementHandle
);

/+
 ' ODBC v3.0+ ISO 92
 ' Fetches the specified rowset of data from the result set and
 ' returns data for all bound columns. Rowsets can be specified
 ' at an absolute or relative position or by bookmark.
 '
 ' -- FetchOrientation --
 ' Type of fetch:
 ' SQL_FETCH_NEXT
 ' SQL_FETCH_PRIOR
 ' SQL_FETCH_FIRST
 ' SQL_FETCH_LAST
 ' SQL_FETCH_ABSOLUTE
 ' SQL_FETCH_RELATIVE
 ' SQL_FETCH_BOOKMARK
 '
 ' -- FetchOffset --
 ' Number of the row to fetch based on the type above.
 '
 +/
SQLRETURN SQLFetchScroll
(
    /+ IN  +/ SQLHSTMT    StatementHandle,
    /+ IN  +/ SQLSMALLINT FetchOrientation,
    /+ IN  +/ SQLINTEGER  FetchOffset
);

/+
 ' ODBC v3.0+ ISO 92
 ' Frees resources associated with a specific environment, connection,
 ' statement, or descriptor handle.
 '
 ' -- HandleType --
 ' Must be one of the following values:
 ' SQL_HANDLE_ENV
 ' SQL_HANDLE_DBC
 ' SQL_HANDLE_STMT
 ' SQL_HANDLE_DESC
 '
 +/
SQLRETURN SQLFreeHandle
(
    /+ IN  +/ SQLSMALLINT HandleType,
    /+ IN  +/ SQLHANDLE   Handle
);

/+
 ' ODBC v1.0+ ISO 92
 ' Stops processing associated with a specific statement,
 ' closes any open cursors associated with the statement,
 ' discards pending results, or, optionally, frees all
 ' resources associated with the statement handle.
 '
 +/
SQLRETURN SQLFreeStmt
(
    /+ IN  +/ SQLHSTMT     StatementHandle,
    /+ IN  +/ SQLUSMALLINT Option
);

/+
 ' ODBC v3.0+  ISO 92
 ' Returns the current setting of a connection attribute.
 '
 +/
SQLRETURN SQLGetConnectAttr
(
    /+ IN  +/ SQLHDBC    ConnectionHandle,
    /+ IN  +/ SQLINTEGER Attribute,
    /+ OUT +/ SQLPOINTER Value,
    /+ IN  +/ SQLINTEGER BufferLength,
    /+ OUT +/ SQLINTEGER *StringLength
);

/+
 ' ODBC v1.+ ISO 92
 ' Returns the cursor name associated with a specified statement.
 '
 +/
SQLRETURN SQLGetCursorName
(
    /+ IN  +/ SQLHSTMT    StatementHandle,
    /+ OUT +/ SQLCHAR     *CursorName,
    /+ IN  +/ SQLSMALLINT BufferLength,
    /+ OUT +/ SQLSMALLINT *NameLength
);

/+
 ' ODBC v1.0+ ISO 92
 ' Retrieves data for a single column in the result set. It can be called
 ' multiple times to retrieve variable-length data in parts.
 '
 +/
SQLRETURN SQLGetData
(
    /+ IN  +/ SQLHSTMT     StatementHandle,
    /+ IN  +/ SQLUSMALLINT ColumnNumber,
    /+ IN  +/ SQLSMALLINT  TargetType,
    /+ OUT +/ SQLPOINTER   TargetValue,
    /+ IN  +/ SQLINTEGER   BufferLength,
    /+ OUT +/ SQLINTEGER   *StrLen_or_Ind
);

/+
 ' ODBC v3.0+ ISO 92
 ' Returns the current setting or value of a single field of a descriptor record.
 '
 +/
SQLRETURN SQLGetDescField
(
    /+ IN  +/ SQLHDESC    DescriptorHandle,
    /+ IN  +/ SQLSMALLINT RecNumber,
    /+ IN  +/ SQLSMALLINT FieldIdentifier,
    /+ OUT +/ SQLPOINTER  Value,
    /+ IN  +/ SQLINTEGER  BufferLength,
    /+ OUT +/ SQLINTEGER  *StringLength
);

/+
 ' ODBC v3.0+ ISO 92
 ' Returns the current settings or values of multiple fields of a descriptor
 ' record. The fields returned describe the name, data type, and storage of
 ' column or parameter data.
 '
 +/
SQLRETURN SQLGetDescRec
(
    /+ IN  +/ SQLHDESC    DescriptorHandle,
    /+ IN  +/ SQLSMALLINT RecNumber,
    /+ OUT +/ SQLCHAR     *Name,         // SQLGetDescField( DescriptorHandle = SQL_DESC_NAME )
    /+ IN  +/ SQLSMALLINT BufferLength,
    /+ OUT +/ SQLSMALLINT *StringLength,
    /+ OUT +/ SQLSMALLINT *Type,         // SQLGetDescField( DescriptorHandle = SQL_DESC_TYPE )
    /+ OUT +/ SQLSMALLINT *SubType,      // SQLGetDescField( DescriptorHandle = SQL_DESC_DATETIME_INTERVAL_CODE  )
    /+ OUT +/ SQLINTEGER  *Length,       // SQLGetDescField( DescriptorHandle = SQL_DESC_OCTET_LENGTH )
    /+ OUT +/ SQLSMALLINT *Precision,    // SQLGetDescField( DescriptorHandle = SQL_DESC_PRECISION )
    /+ OUT +/ SQLSMALLINT *Scale,        // SQLGetDescField( DescriptorHandle = SQL_DESC_SCALE )
    /+ OUT +/ SQLSMALLINT *Nullable      // SQLGetDescField( DescriptorHandle = SQL_DESC_NULLABLE )
);

/+
 ' ODBC v3.0+ ISO 92
 ' Returns the current value of a field of a record of the diagnostic
 ' data structure (associated with a specified handle) that contains
 ' error, warning, and status information.
 '
 ' -- HandleType --
 ' Must be one of the following:
 ' SQL_HANDLE_ENV
 ' SQL_HANDLE_DBC
 ' SQL_HANDLE_STMT
 ' SQL_HANDLE_DESC
 '
 +/
SQLRETURN SQLGetDiagField
(
    /+ IN  +/ SQLSMALLINT HandleType,
    /+ IN  +/ SQLHANDLE   Handle,
    /+ IN  +/ SQLSMALLINT RecNumber,
    /+ IN  +/ SQLSMALLINT DiagIdentifier,
    /+ OUT +/ SQLPOINTER  DiagInfo,
    /+ IN  +/ SQLSMALLINT BufferLength,
    /+ OUT +/ SQLSMALLINT *StringLength
);

/+
 ' ODBC v3.0+ ISO 92
 ' Returns the current values of multiple fields of a diagnostic record that
 ' contains error, warning, and status information. Unlike SQLGetDiagField,
 ' which returns one diagnostic field per call, SQLGetDiagRec returns several
 ' commonly used fields of a diagnostic record, including the SQLSTATE, the
 ' native error code, and the diagnostic message text.
 '
 ' -- HandleType --
 ' Must be one of the following:
 ' SQL_HANDLE_ENV
 ' SQL_HANDLE_DBC
 ' SQL_HANDLE_STMT
 ' SQL_HANDLE_DESC
 '
 +/
SQLRETURN SQLGetDiagRec
(
    /+ IN  +/ SQLSMALLINT HandleType,
    /+ IN  +/ SQLHANDLE   Handle,
    /+ IN  +/ SQLSMALLINT RecNumber,
    /+ OUT +/ SQLCHAR     *Sqlstate,
    /+ OUT +/ SQLINTEGER  *NativeError,
    /+ OUT +/ SQLCHAR     *MessageText,
    /+ IN  +/ SQLSMALLINT BufferLength,
    /+ OUT +/ SQLSMALLINT *TextLength
);

/+
 ' ODBC v3.0+ ISO 92
 ' Returns the current setting of an environment attribute.
 '
 +/
SQLRETURN SQLGetEnvAttr
(
    /+ IN  +/ SQLHENV EnvironmentHandle,
    /+ IN  +/ SQLINTEGER Attribute,
    /+ OUT +/ SQLPOINTER Value,
    /+ IN  +/ SQLINTEGER BufferLength,
    /+ OUT +/ SQLINTEGER *StringLength
);

/+
 ' ODBC v1.0+ ISO 92
 ' returns information about whether a driver supports a specific ODBC
 ' function. This function is implemented in the Driver Manager; it can
 ' also be implemented in drivers. If a driver implements SQLGetFunctions,
 ' the Driver Manager calls the function in the driver. Otherwise,
 ' it executes the function itself.
 '
 +/
SQLRETURN SQLGetFunctions
(
    /+ IN  +/ SQLHDBC      ConnectionHandle,
    /+ IN  +/ SQLUSMALLINT FunctionId,
    /+ OUT +/ SQLUSMALLINT *Supported
);

/+
 ' ODBC v1.0+ ISO 92
 ' Returns general information about the driver and data
 ' source associated with a connection.
 '
 +/
SQLRETURN SQLGetInfo
(
    /+ IN  +/ SQLHDBC      ConnectionHandle,
    /+ IN  +/ SQLUSMALLINT InfoType,
    /+ OUT +/ SQLPOINTER   InfoValue,
    /+ IN  +/ SQLSMALLINT  BufferLength,
    /+ OUT +/ SQLSMALLINT  *StringLength
);

/+
 ' ODBC v3.0+ ISO 92
 ' Returns the current setting of a statement attribute.
 '
 +/
SQLRETURN SQLGetStmtAttr
(
    /+ IN  +/ SQLHSTMT   StatementHandle,
    /+ IN  +/ SQLINTEGER Attribute,
    /+ OUT +/ SQLPOINTER Value,
    /+ IN  +/ SQLINTEGER BufferLength,
    /+ OUT +/ SQLINTEGER *StringLength
);

/+
 ' ODBC v1.0+ ISO 92
 ' Returns information about data types supported by the data source.
 ' The driver returns the information in the form of an SQL result set.
 ' The data types are intended for use in Data Definition Language (DDL) statements.
 '
 +/
SQLRETURN SQLGetTypeInfo
(
    /+ IN  +/ SQLHSTMT    StatementHandle,
    /+ IN  +/ SQLSMALLINT DataType
);

/+
 ' ODBC v1.0+ ISO 92
 ' Returns the number of columns in a result set.
 '
 +/
SQLRETURN SQLNumResultCols
(
    /+ IN  +/ SQLHSTMT    StatementHandle,
    /+ OUT +/ SQLSMALLINT *ColumnCount
);

/+
 ' ODBC v1.0+ ISO 92
 ' Is used in conjunction with SQLPutData to supply parameter data at statement execution time.
 '
 +/
SQLRETURN SQLParamData
(
    /+ IN  +/ SQLHSTMT   StatementHandle,
    /+ OUT +/ SQLPOINTER *Value
);

/+
 ' ODBC v1.0+ ISO 92
 ' Prepares an SQL string for execution.
 '
 +/
SQLRETURN SQLPrepare
(
    /+ IN  +/ SQLHSTMT   StatementHandle,
    /+ IN  +/ SQLCHAR   *StatementText,
    /+ IN  +/ SQLINTEGER TextLength
);

/+
 ' ODBC v1.0+ ISO 92
 ' Allows an application to send data for a parameter or column to the driver
 ' at statement execution time. This function can be used to send character or
 ' binary data values in parts to a column with a character, binary, or data
 ' source specific data type (for example, parameters of the SQL_LONGVARBINARY
 ' or SQL_LONGVARCHAR types). SQLPutData supports binding to a Unicode C data
 ' type, even if the underlying driver does not support Unicode data.
 '
 +/
SQLRETURN SQLPutData
(
    /+ IN  +/ SQLHSTMT   StatementHandle,
    /+ IN  +/ SQLPOINTER Data,
    /+ IN  +/ SQLINTEGER StrLen_or_Ind
);

/+
 ' ODBC v1.+ ISO 92
 ' Returns the number of rows affected by an UPDATE, INSERT, or DELETE statement;
 ' an SQL_ADD, SQL_UPDATE_BY_BOOKMARK, or SQL_DELETE_BY_BOOKMARK operation in
 ' SQLBulkOperations; or an SQL_UPDATE or SQL_DELETE operation in SQLSetPos.
 '
 +/
SQLRETURN SQLRowCount
(
    /+ IN  +/ SQLHSTMT   StatementHandle,
    /+ OUT +/ SQLINTEGER *RowCount
);

/+
 ' ODBC v3.0+ ISO 92
 ' Sets attributes that govern aspects of connections.
 '
 +/
SQLRETURN SQLSetConnectAttr
(
    /+ IN  +/ SQLHDBC    ConnectionHandle,
    /+ IN  +/ SQLINTEGER Attribute,
    /+ IN  +/ SQLPOINTER Value,
    /+ IN  +/ SQLINTEGER StringLength
);

/+
 ' ODBC v1.0+ ISO 92
 ' Associates a cursor name with an active statement. If an application
 ' does not call SQLSetCursorName, the driver generates cursor names as
 ' needed for SQL statement processing.
 '
 +/
SQLRETURN SQLSetCursorName
(
    /+ IN  +/ SQLHSTMT    StatementHandle,
    /+ IN  +/ SQLCHAR     *CursorName,
    /+ IN  +/ SQLSMALLINT NameLength
);

/+
 ' ODBC v3.0+ ISO 92
 ' Sets the value of a single field of a descriptor record.
 '
 +/
SQLRETURN SQLSetDescField
(
    /+ IN  +/ SQLHDESC    DescriptorHandle,
    /+ IN  +/ SQLSMALLINT RecNumber,
    /+ IN  +/ SQLSMALLINT FieldIdentifier,
    /+ IN  +/ SQLPOINTER  Value,
    /+ IN  +/ SQLINTEGER  BufferLength
);

/+
 ' ODBC v3.0+ ISO 92
 ' Function sets multiple descriptor fields that affect the data
 ' type and buffer bound to a column or parameter data.
 '
 +/
SQLRETURN SQLSetDescRec
(
    /+ IN    +/ SQLHDESC    DescriptorHandle,
    /+ IN    +/ SQLSMALLINT RecNumber,
    /+ IN    +/ SQLSMALLINT Type,
    /+ IN    +/ SQLSMALLINT SubType,
    /+ IN    +/ SQLINTEGER  Length,
    /+ IN    +/ SQLSMALLINT Precision,
    /+ IN    +/ SQLSMALLINT Scale,
    /+ INOUT +/ SQLPOINTER  Data,
    /+ INOUT +/ SQLINTEGER  *StringLength,
    /+ INOUT +/ SQLINTEGER  *Indicator
);

/+
 ' ODBC v3.0+ ISO 92
 ' Sets attributes that govern aspects of environments.
 '
 +/
SQLRETURN SQLSetEnvAttr
(
    /+ IN  +/ SQLHENV    EnvironmentHandle,
    /+ IN  +/ SQLINTEGER Attribute,
    /+ IN  +/ SQLPOINTER Value,
    /+ IN  +/ SQLINTEGER StringLength
);

/+
 ' ODBC v3.0+ ISO 92
 ' Sets attributes related to a statement.
 '
 +/
SQLRETURN SQLSetStmtAttr
(
    /+ IN  +/ SQLHSTMT   StatementHandle,
    /+ IN  +/ SQLINTEGER Attribute,
    /+ IN  +/ SQLPOINTER Value,
    /+ IN  +/ SQLINTEGER StringLength
);

/+
 ' ODBC v1.0+ X/Open
 ' Retrieves the following information about columns within a specified table:
 '
 ' 1) The optimal set of columns that uniquely identifies a row in the table.
 ' 2) Columns that are automatically updated when any value in the row is updated by a transaction.
 '
 '
 +/
SQLRETURN SQLSpecialColumns
(
    /+ IN  +/ SQLHSTMT     StatementHandle,
    /+ IN  +/ SQLUSMALLINT IdentifierType,
    /+ IN  +/ SQLCHAR      *CatalogName,
    /+ IN  +/ SQLSMALLINT  NameLength1,
    /+ IN  +/ SQLCHAR      *SchemaName,
    /+ IN  +/ SQLSMALLINT  NameLength2,
    /+ IN  +/ SQLCHAR      *TableName,
    /+ IN  +/ SQLSMALLINT  NameLength3,
    /+ IN  +/ SQLUSMALLINT Scope,
    /+ IN  +/ SQLUSMALLINT Nullable
);

/+
 ' ODBC v1.0+ ISO 92
 ' Retrieves a list of statistics about a single table and the
 ' indexes associated with the table. The driver returns the
 ' information as a result set.
 '
 ' -- Unique --
 ' Type of index: SQL_INDEX_UNIQUE or SQL_INDEX_ALL.
 '
 +/
SQLRETURN SQLStatistics
(
    /+ IN  +/ SQLHSTMT     StatementHandle,
    /+ IN  +/ SQLCHAR      *CatalogName,
    /+ IN  +/ SQLSMALLINT  NameLength1,
    /+ IN  +/ SQLCHAR      *SchemaName,
    /+ IN  +/ SQLSMALLINT  NameLength2,
    /+ IN  +/ SQLCHAR      *TableName,
    /+ IN  +/ SQLSMALLINT  NameLength3,
    /+ IN  +/ SQLUSMALLINT Unique,
    /+ IN  +/ SQLUSMALLINT Reserved
);

/+
 ' OBDC v1.0+ X/Open
 ' Returns the list of table, catalog, or schema names, and table
 ' types, stored in a specific data source. The driver returns the
 ' information as a result set.
 '
 +/
SQLRETURN SQLTables
(
    /+ IN  +/ SQLHSTMT    StatementHandle,
    /+ IN  +/ SQLCHAR     *CatalogName,
    /+ IN  +/ SQLSMALLINT NameLength1,
    /+ IN  +/ SQLCHAR     *SchemaName,
    /+ IN  +/ SQLSMALLINT NameLength2,
    /+ IN  +/ SQLCHAR     *TableName,
    /+ IN  +/ SQLSMALLINT NameLength3,
    /+ IN  +/ SQLCHAR     *TableType,
    /+ IN  +/ SQLSMALLINT NameLength4
);

/+---------------------------+
 | * Deprecated Functions *  |
 +---------------------------+/
/+
 ' In ODBC 3.x, the ODBC 2.x function SQLAllocConnect has been
 ' replaced by SQLAllocHandle.
 '
 +/
SQLRETURN SQLAllocConnect
(
    SQLHENV EnvironmentHandle,
    SQLHDBC *ConnectionHandle
);

/+
 ' In ODBC 3.x, the ODBC 2.x function SQLAllocEnv has been replaced by SQLAllocHandle.
 '
 +/
SQLRETURN SQLAllocEnv
(
    SQLHENV *EnvironmentHandle
);

/+
 ' In ODBC 3.x, the ODBC 2.x function SQLAllocStmt has been replaced by SQLAllocHandle.
 '
 +/
SQLRETURN SQLAllocStmt
(
    SQLHDBC  ConnectionHandle,
    SQLHSTMT *StatementHandle
);

SQLRETURN SQLError
(
    SQLHENV     EnvironmentHandle,
    SQLHDBC     ConnectionHandle,
    SQLHSTMT    StatementHandle,
    SQLCHAR     *Sqlstate,
    SQLINTEGER  *NativeError,
    SQLCHAR     *MessageText,
    SQLSMALLINT BufferLength,
    SQLSMALLINT *TextLength
);

SQLRETURN SQLFreeConnect
(
    SQLHDBC ConnectionHandle
);

SQLRETURN SQLFreeEnv
(
    SQLHENV EnvironmentHandle
);

SQLRETURN SQLGetConnectOption
(
    SQLHDBC      ConnectionHandle,
    SQLUSMALLINT Option,
    SQLPOINTER   Value
);

SQLRETURN SQLGetStmtOption
(
    SQLHSTMT     StatementHandle,
    SQLUSMALLINT Option,
    SQLPOINTER   Value
);

SQLRETURN SQLSetConnectOption
(
    SQLHDBC      ConnectionHandle,
    SQLUSMALLINT Option,
    SQLUINTEGER  Value
);

SQLRETURN SQLSetParam
(
    SQLHSTMT StatementHandle,
    SQLUSMALLINT ParameterNumber,
    SQLSMALLINT ValueType,
    SQLSMALLINT ParameterType,
    SQLUINTEGER LengthPrecision,
    SQLSMALLINT ParameterScale,
    SQLPOINTER ParameterValue,
    SQLINTEGER *StrLen_or_Ind
);

SQLRETURN SQLSetStmtOption
(
    SQLHSTMT StatementHandle,
    SQLUSMALLINT Option,
    SQLUINTEGER Value
);

SQLRETURN SQLTransact
(
    SQLHENV      EnvironmentHandle,
    SQLHDBC      ConnectionHandle,
    SQLUSMALLINT CompletionType
);

// end Deprecated Functions
