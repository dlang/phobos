// @@@DEPRECATED_2.106@@@

/**
$(RED Warning:
      This module is deprecated. It will be removed in 2.106.
      Use `core.sys.windows.sql` instead.)

Declarations for interfacing with the ODBC library.

See_Also: $(LINK2 https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/odbc-api-reference,
            ODBC API Reference on MSN Online)
 */
deprecated("Import core.sys.windows.sql instead")
module etc.c.odbc.sql;

public import core.sys.windows.sql;
