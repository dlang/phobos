/**
Declarations for interfacing with the ODBC library.

Adapted with minimal changes from the work of David L. Davis
(refer to the $(WEB
forum.dlang.org/thread/cfk7ql$(DOLLAR)1p4n$(DOLLAR)1@digitaldaemon.com#post-cfk7ql:241p4n:241:40digitaldaemon.com,
original announcement)).

`etc.c.odbc.sqlucode` corresponds to the `sqlucode.h` C include file.

See_Also: $(LUCKY ODBC API Reference on MSN Online)
*/

/+
sqlucode.d - This is the the unicode include for ODBC v3.0+ Core functions.

+/

module etc.c.odbc.sqlucode;

import etc.c.odbc.sqlext;
import etc.c.odbc.sqltypes;

extern (Windows):

enum
{
    SQL_WCHAR        = (-8),
    SQL_WVARCHAR     = (-9),
    SQL_WLONGVARCHAR = (-10),
    SQL_C_WCHAR      = SQL_WCHAR,
    SQL_C_TCHAR      = SQL_C_WCHAR
}

enum int SQL_SQLSTATE_SIZEW = 10; /* size of SQLSTATE for unicode */

// UNICODE versions

SQLRETURN SQLColAttributeW
(
    SQLHSTMT     hstmt,
    SQLUSMALLINT iCol,
    SQLUSMALLINT iField,
    SQLPOINTER   pCharAttr,
    SQLSMALLINT  cbCharAttrMax,
    SQLSMALLINT  *pcbCharAttr,
    SQLPOINTER   pNumAttr
);

SQLRETURN SQLColAttributesW
(
    SQLHSTMT     hstmt,
    SQLUSMALLINT icol,
    SQLUSMALLINT fDescType,
    SQLPOINTER   rgbDesc,
    SQLSMALLINT  cbDescMax,
    SQLSMALLINT  *pcbDesc,
    SQLINTEGER   *pfDesc
);

SQLRETURN SQLConnectW
(
    SQLHDBC     hdbc,
    SQLWCHAR    *szDSN,
    SQLSMALLINT cbDSN,
    SQLWCHAR    *szUID,
    SQLSMALLINT cbUID,
    SQLWCHAR    *szAuthStr,
    SQLSMALLINT cbAuthStr
);

SQLRETURN SQLDescribeColW
(
    SQLHSTMT     hstmt,
    SQLUSMALLINT icol,
    SQLWCHAR     *szColName,
    SQLSMALLINT  cbColNameMax,
    SQLSMALLINT  *pcbColName,
    SQLSMALLINT  *pfSqlType,
    SQLUINTEGER  *pcbColDef,
    SQLSMALLINT  *pibScale,
    SQLSMALLINT  *pfNullable
);

SQLRETURN SQLErrorW
(
    SQLHENV     henv,
    SQLHDBC     hdbc,
    SQLHSTMT    hstmt,
    SQLWCHAR    *szSqlState,
    SQLINTEGER  *pfNativeError,
    SQLWCHAR    *szErrorMsg,
    SQLSMALLINT cbErrorMsgMax,
    SQLSMALLINT *pcbErrorMsg
);

SQLRETURN SQLExecDirectW
(
    SQLHSTMT   hstmt,
    SQLWCHAR   *szSqlStr,
    SQLINTEGER cbSqlStr
);

SQLRETURN SQLGetConnectAttrW
(
    SQLHDBC    hdbc,
    SQLINTEGER fAttribute,
    SQLPOINTER rgbValue,
    SQLINTEGER cbValueMax,
    SQLINTEGER *pcbValue
);

SQLRETURN SQLGetCursorNameW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCursor,
    SQLSMALLINT cbCursorMax,
    SQLSMALLINT *pcbCursor
);

SQLRETURN SQLSetDescFieldW
(
    SQLHDESC    DescriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER  Value,
    SQLINTEGER  BufferLength
);

SQLRETURN SQLGetDescFieldW
(
    SQLHDESC    hdesc,
    SQLSMALLINT iRecord,
    SQLSMALLINT iField,
    SQLPOINTER  rgbValue,
    SQLINTEGER	cbValueMax,
    SQLINTEGER  *pcbValue
);

SQLRETURN SQLGetDescRecW
(
    SQLHDESC    hdesc,
    SQLSMALLINT iRecord,
    SQLWCHAR    *szName,
    SQLSMALLINT cbNameMax,
    SQLSMALLINT *pcbName,
    SQLSMALLINT *pfType,
    SQLSMALLINT *pfSubType,
    SQLINTEGER  *pLength,
    SQLSMALLINT *pPrecision,
    SQLSMALLINT *pScale,
    SQLSMALLINT *pNullable
);

SQLRETURN SQLGetDiagFieldW
(
    SQLSMALLINT fHandleType,
    SQLHANDLE   handle,
    SQLSMALLINT iRecord,
    SQLSMALLINT fDiagField,
    SQLPOINTER  rgbDiagInfo,
    SQLSMALLINT cbDiagInfoMax,
    SQLSMALLINT *pcbDiagInfo
);

SQLRETURN SQLGetDiagRecW
(
    SQLSMALLINT        fHandleType,
    SQLHANDLE          handle,
    SQLSMALLINT        iRecord,
    SQLWCHAR        *szSqlState,
    SQLINTEGER     *pfNativeError,
    SQLWCHAR        *szErrorMsg,
    SQLSMALLINT        cbErrorMsgMax,
    SQLSMALLINT    *pcbErrorMsg
);

SQLRETURN SQLPrepareW
(
    SQLHSTMT   hstmt,
    SQLWCHAR   *szSqlStr,
    SQLINTEGER cbSqlStr
);

SQLRETURN SQLSetConnectAttrW
(
    SQLHDBC    hdbc,
    SQLINTEGER fAttribute,
    SQLPOINTER rgbValue,
    SQLINTEGER cbValue
);

SQLRETURN SQLSetCursorNameW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCursor,
    SQLSMALLINT cbCursor
);

SQLRETURN SQLColumnsW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCatalogName,
    SQLSMALLINT cbCatalogName,
    SQLWCHAR    *szSchemaName,
    SQLSMALLINT cbSchemaName,
    SQLWCHAR    *szTableName,
    SQLSMALLINT cbTableName,
    SQLWCHAR    *szColumnName,
    SQLSMALLINT cbColumnName
);

SQLRETURN SQLGetConnectOptionW
(
    SQLHDBC      hdbc,
    SQLUSMALLINT fOption,
    SQLPOINTER   pvParam
);

SQLRETURN SQLGetInfoW
(
    SQLHDBC      hdbc,
    SQLUSMALLINT fInfoType,
    SQLPOINTER   rgbInfoValue,
    SQLSMALLINT  cbInfoValueMax,
    SQLSMALLINT  *pcbInfoValue
);

SQLRETURN SQLGetTypeInfoW
(
    SQLHSTMT    StatementHandle,
    SQLSMALLINT DataType
);


SQLRETURN SQLSetConnectOptionW
(
    SQLHDBC      hdbc,
    SQLUSMALLINT fOption,
    SQLUINTEGER  vParam
);

SQLRETURN SQLSpecialColumnsW
(
    SQLHSTMT     hstmt,
    SQLUSMALLINT fColType,
    SQLWCHAR     *szCatalogName,
    SQLSMALLINT  cbCatalogName,
    SQLWCHAR     *szSchemaName,
    SQLSMALLINT  cbSchemaName,
    SQLWCHAR     *szTableName,
    SQLSMALLINT  cbTableName,
    SQLUSMALLINT fScope,
    SQLUSMALLINT fNullable
);

SQLRETURN SQLStatisticsW
(
    SQLHSTMT     hstmt,
    SQLWCHAR     *szCatalogName,
    SQLSMALLINT  cbCatalogName,
    SQLWCHAR     *szSchemaName,
    SQLSMALLINT  cbSchemaName,
    SQLWCHAR     *szTableName,
    SQLSMALLINT  cbTableName,
    SQLUSMALLINT fUnique,
    SQLUSMALLINT fAccuracy
);

SQLRETURN SQLTablesW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCatalogName,
    SQLSMALLINT cbCatalogName,
    SQLWCHAR    *szSchemaName,
    SQLSMALLINT cbSchemaName,
    SQLWCHAR    *szTableName,
    SQLSMALLINT cbTableName,
    SQLWCHAR    *szTableType,
    SQLSMALLINT cbTableType
);

SQLRETURN SQLDataSourcesW
(
    SQLHENV      henv,
    SQLUSMALLINT fDirection,
    SQLWCHAR     *szDSN,
    SQLSMALLINT  cbDSNMax,
    SQLSMALLINT  *pcbDSN,
    SQLWCHAR     *szDescription,
    SQLSMALLINT  cbDescriptionMax,
    SQLSMALLINT  *pcbDescription
);

SQLRETURN SQLDriverConnectW
(
    SQLHDBC      hdbc,
    SQLHWND      hwnd,
    SQLWCHAR     *szConnStrIn,
    SQLSMALLINT  cbConnStrIn,
    SQLWCHAR     *szConnStrOut,
    SQLSMALLINT  cbConnStrOutMax,
    SQLSMALLINT  *pcbConnStrOut,
    SQLUSMALLINT fDriverCompletion
);

SQLRETURN SQLBrowseConnectW
(
    SQLHDBC     hdbc,
    SQLWCHAR    *szConnStrIn,
    SQLSMALLINT cbConnStrIn,
    SQLWCHAR    *szConnStrOut,
    SQLSMALLINT cbConnStrOutMax,
    SQLSMALLINT *pcbConnStrOut
);

SQLRETURN SQLColumnPrivilegesW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCatalogName,
    SQLSMALLINT cbCatalogName,
    SQLWCHAR    *szSchemaName,
    SQLSMALLINT cbSchemaName,
    SQLWCHAR    *szTableName,
    SQLSMALLINT cbTableName,
    SQLWCHAR    *szColumnName,
    SQLSMALLINT cbColumnName
);

SQLRETURN SQLGetStmtAttrW
(
    SQLHSTMT   hstmt,
    SQLINTEGER fAttribute,
    SQLPOINTER rgbValue,
    SQLINTEGER cbValueMax,
    SQLINTEGER *pcbValue
);

SQLRETURN SQLSetStmtAttrW
(
    SQLHSTMT   hstmt,
    SQLINTEGER fAttribute,
    SQLPOINTER rgbValue,
    SQLINTEGER cbValueMax
);

SQLRETURN SQLForeignKeysW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szPkCatalogName,
    SQLSMALLINT cbPkCatalogName,
    SQLWCHAR    *szPkSchemaName,
    SQLSMALLINT cbPkSchemaName,
    SQLWCHAR    *szPkTableName,
    SQLSMALLINT cbPkTableName,
    SQLWCHAR    *szFkCatalogName,
    SQLSMALLINT cbFkCatalogName,
    SQLWCHAR    *szFkSchemaName,
    SQLSMALLINT cbFkSchemaName,
    SQLWCHAR    *szFkTableName,
    SQLSMALLINT cbFkTableName
);

SQLRETURN SQLNativeSqlW
(
    SQLHDBC    hdbc,
    SQLWCHAR   *szSqlStrIn,
    SQLINTEGER cbSqlStrIn,
    SQLWCHAR   *szSqlStr,
    SQLINTEGER cbSqlStrMax,
    SQLINTEGER *pcbSqlStr
);

SQLRETURN SQLPrimaryKeysW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCatalogName,
    SQLSMALLINT cbCatalogName,
    SQLWCHAR    *szSchemaName,
    SQLSMALLINT cbSchemaName,
    SQLWCHAR    *szTableName,
    SQLSMALLINT cbTableName
);

SQLRETURN SQLProcedureColumnsW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCatalogName,
    SQLSMALLINT cbCatalogName,
    SQLWCHAR    *szSchemaName,
    SQLSMALLINT cbSchemaName,
    SQLWCHAR    *szProcName,
    SQLSMALLINT cbProcName,
    SQLWCHAR    *szColumnName,
    SQLSMALLINT cbColumnName
);

SQLRETURN SQLProceduresW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCatalogName,
    SQLSMALLINT cbCatalogName,
    SQLWCHAR    *szSchemaName,
    SQLSMALLINT cbSchemaName,
    SQLWCHAR    *szProcName,
    SQLSMALLINT cbProcName
);

SQLRETURN SQLTablePrivilegesW
(
    SQLHSTMT    hstmt,
    SQLWCHAR    *szCatalogName,
    SQLSMALLINT cbCatalogName,
    SQLWCHAR    *szSchemaName,
    SQLSMALLINT cbSchemaName,
    SQLWCHAR    *szTableName,
    SQLSMALLINT cbTableName
);

SQLRETURN SQLDriversW
(
    SQLHENV      henv,
    SQLUSMALLINT fDirection,
    SQLWCHAR     *szDriverDesc,
    SQLSMALLINT  cbDriverDescMax,
    SQLSMALLINT  *pcbDriverDesc,
    SQLWCHAR     *szDriverAttributes,
    SQLSMALLINT  cbDrvrAttrMax,
    SQLSMALLINT  *pcbDrvrAttr
);

//---------------------------------------------
// Mapping Unicode Functions
//---------------------------------------------
/+
alias SQLColAttributeW     SQLColAttribute;
alias SQLColAttributesW    SQLColAttributes;
alias SQLConnectW          SQLConnect;
alias SQLDescribeColW      SQLDescribeCol;
alias SQLErrorW            SQLError;
alias SQLExecDirectW       SQLExecDirect;
alias SQLGetConnectAttrW   SQLGetConnectAttr;
alias SQLGetCursorNameW    SQLGetCursorName;
alias SQLGetDescFieldW     SQLGetDescField;
alias SQLGetDescRecW       SQLGetDescRec;
alias SQLGetDiagFieldW     SQLGetDiagField;
alias SQLGetDiagRecW       SQLGetDiagRec;
alias SQLPrepareW          SQLPrepare;
alias SQLSetConnectAttrW   SQLSetConnectAttr;
alias SQLSetCursorNameW    SQLSetCursorName;
alias SQLSetDescFieldW     SQLSetDescField;
alias SQLSetStmtAttrW      SQLSetStmtAttr;
alias SQLColumnsW          SQLColumns;
alias SQLGetConnectOptionW SQLGetConnectOption;
alias SQLGetInfoW          SQLGetInfo;
alias SQLGetTypeInfoW      SQLGetTypeInfo;
alias SQLSetConnectOptionW SQLSetConnectOption;
alias SQLSpecialColumnsW   SQLSpecialColumns;
alias SQLStatisticsW       SQLStatistics;
alias SQLTablesW           SQLTables;
alias SQLDataSourcesW      SQLDataSources;
alias SQLDriverConnectW    SQLDriverConnect;
alias SQLBrowseConnectW    SQLBrowseConnect;
alias SQLColumnPrivilegesW SQLColumnPrivileges;
alias SQLForeignKeysW      SQLForeignKeys;
alias SQLNativeSqlW        SQLNativeSql;
alias SQLPrimaryKeysW      SQLPrimaryKeys;
alias SQLProcedureColumnsW SQLProcedureColumns;
alias SQLProceduresW       SQLProcedures;
alias SQLTablePrivilegesW  SQLTablePrivileges;
alias SQLDriversW          SQLDrivers;
+/
